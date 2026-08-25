-- ============================================================
-- 008_importacion.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- Carga versionada del inventario.
--
-- ⚠️ ARCHIVO ACTUALIZADO 24-08-2026 con la correccion de
-- ADR-002. La version anterior versionada estaba desfasada.
--
-- RN-013: la version anterior permanece activa hasta validar
-- la nueva. Carga fallida = el sistema sigue con la ultima
-- version valida. Nunca se queda operando a medias.
--
-- ADR-010: el archivo se lee y envia desde el navegador del
-- administrador directamente a la base, sin pasar por el
-- repositorio. Ningun dato SAP toca GitHub.
--
-- ADR-002: se conservan como maximo DOS versiones completas
-- (activa y anterior). De las demas solo el registro de
-- auditoria, sin filas.
-- ============================================================


-- ------------------------------------------------------------
-- iniciar_version_datos()
-- Abre una carga en estado 'preparando'. Las filas se van
-- insertando contra este identificador y no son visibles para
-- nadie hasta que la version se active.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.iniciar_version_datos(
  p_archivo         text,
  p_filas_esperadas integer
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede iniciar una carga.';
  end if;

  -- Una carga anterior interrumpida se marca como fallida
  -- y sus filas se descartan.
  update public.versiones_datos
     set estado = 'fallida',
         resultado = 'Interrumpida por una carga posterior',
         finalizado_en = now()
   where estado = 'preparando';

  insert into public.versiones_datos
    (estado, archivo_nombre, filas_esperadas, cargado_por)
  values
    ('preparando', p_archivo, p_filas_esperadas, auth.uid())
  returning id into v_id;

  return v_id;
end;
$function$;


-- ------------------------------------------------------------
-- activar_version_datos()
-- El momento critico: solo aqui la carga nueva reemplaza a la
-- vigente.
--
-- RN-012: si el numero de filas cargadas no coincide con el
-- esperado, NO se activa. Asi es como se detecto RN-033: la
-- carga completa fallo con 46.212 de 65.883 filas y Excel
-- decia "sin duplicados" porque comparaba la fila entera. La
-- validacion hizo su trabajo: rechazo la carga y dejo activa
-- la version anterior.
--
-- ADR-002 (error 20 del historial): cuatro versiones llegaron
-- a coexistir como 'anterior' y el borrado dejaba filas
-- huerfanas — 131.766 en vez de 65.883, el doble de lo debido.
-- Por eso las 'anterior' previas pasan a 'historica' ANTES de
-- promover la nueva, y el delete final limpia todo lo que no
-- sea activa ni anterior.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.activar_version_datos(p_version_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_esperadas integer;
  v_reales    integer;
  v_sin_texto integer;
  v_previa    uuid;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede activar una version.';
  end if;

  select filas_esperadas into v_esperadas
  from public.versiones_datos
  where id = p_version_id and estado = 'preparando';

  if v_esperadas is null then
    raise exception 'No hay una carga en preparacion con ese identificador.';
  end if;

  select count(*),
         count(*) filter (where texto_normalizado is null)
    into v_reales, v_sin_texto
  from public.inventario_materiales
  where version_id = p_version_id;

  -- RN-012: si algo no cuadra, no se activa
  if v_reales <> v_esperadas then
    update public.versiones_datos
       set estado = 'fallida',
           resultado = format('Se esperaban %s filas y se cargaron %s',
                              v_esperadas, v_reales),
           finalizado_en = now()
     where id = p_version_id;

    return jsonb_build_object(
      'ok', false,
      'mensaje', format('Carga incompleta: %s de %s filas. '
                     || 'La version anterior sigue activa.',
                        v_reales, v_esperadas));
  end if;

  if v_reales = 0 then
    update public.versiones_datos
       set estado = 'fallida', resultado = 'Sin filas',
           finalizado_en = now()
     where id = p_version_id;
    return jsonb_build_object('ok', false, 'mensaje', 'No se cargo ninguna fila.');
  end if;

  -- La activa actual pasa a ser la unica 'anterior'
  select id into v_previa
  from public.versiones_datos where estado = 'activa';

  -- Las 'anterior' previas quedan como historicas
  update public.versiones_datos
     set estado = 'historica'
   where estado = 'anterior';

  if v_previa is not null then
    update public.versiones_datos set estado = 'anterior' where id = v_previa;
  end if;

  update public.versiones_datos
     set estado = 'activa',
         resultado = 'Carga correcta',
         finalizado_en = now()
   where id = p_version_id;

  -- ADR-002: se eliminan las filas de todo lo que no sea
  -- activa ni anterior. El registro de auditoria permanece.
  delete from public.inventario_materiales
   where version_id in (
     select id from public.versiones_datos
     where estado not in ('activa','anterior')
   );

  return jsonb_build_object(
    'ok', true,
    'filas', v_reales,
    'sin_texto', v_sin_texto,
    'mensaje', format('Version activada con %s materiales.', v_reales));
end;
$function$;


-- ------------------------------------------------------------
-- revertir_version_datos()
-- Vuelta atras manual. La red de seguridad cuando la carga
-- paso las validaciones pero los datos resultan estar mal.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.revertir_version_datos()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_actual   uuid;
  v_anterior uuid;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede revertir.';
  end if;

  select id into v_actual
  from public.versiones_datos where estado = 'activa';

  select id into v_anterior
  from public.versiones_datos
  where estado = 'anterior'
  order by iniciado_en desc limit 1;

  if v_anterior is null then
    return jsonb_build_object('ok', false,
      'mensaje', 'No existe una version anterior a la que volver.');
  end if;

  update public.versiones_datos
     set estado = 'fallida', resultado = 'Revertida por el administrador'
   where id = v_actual;

  update public.versiones_datos
     set estado = 'activa'
   where id = v_anterior;

  return jsonb_build_object('ok', true,
    'mensaje', 'Se restauro la version anterior del inventario.');
end;
$function$;


-- ------------------------------------------------------------
-- convertir_numero()
-- RN-031: el archivo trae los numeros como TEXTO con formato
-- mixto (3.514.207,24 / 124 / 12.192). Si hay coma, el punto
-- es separador de miles.
--
-- El redondeo por unidad no es cosmetico: resuelve los valores
-- donde el punto era interpretable de dos formas. "12.192"
-- puede ser doce mil ciento noventa y dos, o doce coma ciento
-- noventa y dos. Si la unidad es de conteo, la respuesta es
-- clara: no existen 8,2 guantes.
--
-- Para unidades continuas (KG, MT, LT, M) se conservan los
-- decimales.
--
-- exception when others: una celda ilegible devuelve null y no
-- tumba la carga entera de 65.883 filas.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.convertir_numero(
  p_texto  text,
  p_unidad text DEFAULT NULL::text
)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $function$
declare
  v        text := trim(coalesce(p_texto, ''));
  v_valor  numeric;
  v_unidad text := upper(trim(coalesce(p_unidad, '')));
begin
  if v = '' then
    return null;
  end if;

  -- Formato europeo: punto de miles + coma decimal
  if position(',' in v) > 0 then
    v := replace(v, '.', '');
    v := replace(v, ',', '.');
  end if;

  v_valor := v::numeric;

  -- RN-031: unidades de conteo -> entero.
  -- No existen 8,2 guantes. Esto resuelve tambien los valores
  -- donde el punto era interpretable de dos formas.
  if v_unidad in ('UND','UN','PZA','PZ','EA','ST','C/U','UNI') then
    return round(v_valor);
  end if;

  return v_valor;

exception when others then
  return null;
end;
$function$;


-- ------------------------------------------------------------
-- limpiar_material_antiguo()
-- Seis codigos antiguos llegaron convertidos en fecha por
-- Excel y son irrecuperables.
--
-- Se descartan en lugar de conservarlos: un codigo falso es
-- peor que un campo vacio, porque el ingeniero podria buscarlo
-- en SAP y perder tiempo con un dato inventado.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.limpiar_material_antiguo(p_texto text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $function$
  select case
    when coalesce(p_texto,'') = '' then null
    when p_texto like '%00:00:00%' then null   -- corrupcion de origen
    else trim(p_texto)
  end;
$function$;


-- ------------------------------------------------------------
-- cargar_lote_inventario()
-- Inserta un lote de filas (500 por defecto, ADR-005). No se
-- hacen 65.883 peticiones individuales: seria inviable desde
-- un navegador.
--
-- Solo admite cargas en estado 'preparando': impide inyectar
-- filas en la version activa, que es inmutable (RN-011,
-- ADR-006).
--
-- Las columnas normalizadas se calculan AQUI, en el momento de
-- insertar. El dato SAP original queda intacto al lado.
--
-- RN-033: la clave es (version, material, centro, almacen). Un
-- material aparece en varias filas, una por ubicacion. Con la
-- clave anterior — solo material — la carga completa se
-- quedaba en 46.212 de 65.883 filas.
--
-- Se cargan 21 columnas, no 28 (ADR-005): se excluyen precios,
-- consumos y valores para reducir la sensibilidad de la
-- informacion alojada fuera de la organizacion.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cargar_lote_inventario(
  p_version_id uuid,
  p_filas      jsonb
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_insertadas integer;
  v_estado     text;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede cargar inventario.';
  end if;

  select estado into v_estado
  from public.versiones_datos
  where id = p_version_id;

  if v_estado is null then
    raise exception 'La version indicada no existe.';
  end if;

  if v_estado <> 'preparando' then
    raise exception 'Solo se admiten cargas en versiones en preparacion.';
  end if;

  insert into public.inventario_materiales (
    version_id,
    material, texto_breve_material,
    stock_libre_utilizacion, stock_consignacion, stock_proyectos,
    xcentro, maximo, minimo,
    centro, almacen, ubicacion, unidad_medida_base,
    planif_necesidades, grupo_compra, tipo_material, grupo_articulo,
    clase_valoracion, cat_val_stock_proyecto,
    caract_planif_nec, tam_lote_planif_nec, material_antiguo,
    texto_normalizado, material_antiguo_norm, ambito_ubicacion
  )
  select
    p_version_id,
    trim(f->>'material'),
    trim(f->>'texto_breve_material'),
    public.convertir_numero(f->>'stock_libre_utilizacion', f->>'unidad_medida_base'),
    public.convertir_numero(f->>'stock_consignacion',      f->>'unidad_medida_base'),
    public.convertir_numero(f->>'stock_proyectos',         f->>'unidad_medida_base'),
    public.convertir_numero(f->>'xcentro'),
    public.convertir_numero(f->>'maximo', f->>'unidad_medida_base'),
    public.convertir_numero(f->>'minimo', f->>'unidad_medida_base'),
    trim(f->>'centro'),
    trim(f->>'almacen'),
    nullif(trim(coalesce(f->>'ubicacion','')), ''),
    trim(f->>'unidad_medida_base'),
    nullif(trim(coalesce(f->>'planif_necesidades','')), ''),
    nullif(trim(coalesce(f->>'grupo_compra','')), ''),
    nullif(trim(coalesce(f->>'tipo_material','')), ''),
    nullif(trim(coalesce(f->>'grupo_articulo','')), ''),
    nullif(trim(coalesce(f->>'clase_valoracion','')), ''),
    nullif(trim(coalesce(f->>'cat_val_stock_proyecto','')), ''),
    nullif(trim(coalesce(f->>'caract_planif_nec','')), ''),
    nullif(trim(coalesce(f->>'tam_lote_planif_nec','')), ''),
    public.limpiar_material_antiguo(f->>'material_antiguo'),

    public.normalizar_texto(f->>'texto_breve_material'),
    public.normalizar_texto(public.limpiar_material_antiguo(f->>'material_antiguo')),
    public.clasificar_ubicacion(f->>'centro', f->>'almacen')

  from jsonb_array_elements(p_filas) as f
  -- RN-033: la clave incluye centro y almacen
  on conflict (version_id, material, centro, almacen) do nothing;

  get diagnostics v_insertadas = row_count;

  update public.versiones_datos
     set filas_cargadas = filas_cargadas + v_insertadas
   where id = p_version_id;

  return v_insertadas;
end;
$function$;


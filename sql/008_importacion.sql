-- ============================================================
-- 008_importacion.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- Orden de ejecucion: 7
-- ============================================================
-- Conversion, normalizacion y carga por lotes del inventario.
-- El archivo de origen nunca pasa por el repositorio: va del
-- equipo del administrador directamente a la base de datos.
-- ============================================================


-- ############################################################
-- BLOQUE 1 - CONVERSION DE VALORES
-- ############################################################

-- ============================================================
-- convertir_numero()
-- El archivo de origen trae los numeros como texto con formato
-- mixto:
--   '3.514.207,24'  punto = miles, coma = decimales
--   '124'           entero limpio
--   '12.192'        punto sin coma
--
-- RN-031: si la unidad de medida es de conteo (UND y
-- equivalentes) el resultado se redondea a entero. No existen
-- 8,2 guantes. Esta regla resuelve tambien los valores donde
-- el punto era interpretable de dos formas, porque casi
-- siempre corresponden a articulos contables.
-- Para unidades continuas (KG, MT, LT) los decimales son
-- legitimos y se conservan.
-- ============================================================
create or replace function public.convertir_numero(
  p_texto  text,
  p_unidad text default null
)
returns numeric
language plpgsql
immutable
as $$
declare
  v        text := trim(coalesce(p_texto, ''));
  v_valor  numeric;
  v_unidad text := upper(trim(coalesce(p_unidad, '')));
begin
  if v = '' then
    return null;
  end if;

  if position(',' in v) > 0 then
    v := replace(v, '.', '');
    v := replace(v, ',', '.');
  end if;

  v_valor := v::numeric;

  if v_unidad in ('UND','UN','PZA','PZ','EA','ST','C/U','UNI') then
    return round(v_valor);
  end if;

  return v_valor;

exception when others then
  return null;
end;
$$;

comment on function public.convertir_numero is
  'RN-031: convierte texto numerico de formato mixto. En unidades de conteo redondea a entero.';


-- ============================================================
-- limpiar_material_antiguo()
-- Algunos codigos antiguos fueron convertidos en fecha por la
-- hoja de calculo antes de la exportacion. Son irrecuperables:
-- se descartan en lugar de conservar un dato falso.
--
-- Limitacion conocida: el filtro detecta el formato con hora.
-- Si la hoja exporta la fecha en otro formato, el valor pasa.
-- Afecta unicamente a la busqueda por codigo antiguo.
-- ============================================================
create or replace function public.limpiar_material_antiguo(p_texto text)
returns text
language sql
immutable
as $$
  select case
    when coalesce(p_texto,'') = '' then null
    when p_texto like '%00:00:00%' then null
    else trim(p_texto)
  end;
$$;


-- ############################################################
-- BLOQUE 2 - CLASIFICACION Y CARGA
-- ############################################################

-- ============================================================
-- clasificar_ubicacion()
-- RN-018: prioridad de ubicacion.
--
-- PENDIENTE-005: existen codigos de almacen aun no
-- documentados. Regla de seguridad: lo desconocido se
-- clasifica como 'otra', nunca se oculta. Es preferible
-- mostrar un material sin saber donde esta que no mostrarlo.
-- ============================================================
create or replace function public.clasificar_ubicacion(
  p_centro  text,
  p_almacen text
)
returns text
language sql
immutable
as $$
  select case
    when upper(trim(coalesce(p_centro,''))) = 'P110' then 'molino'
    when upper(trim(coalesce(p_centro,''))) = 'P120' then 'planta'
    when upper(trim(coalesce(p_centro,''))) = 'P999' then 'virtual'
    when upper(trim(coalesce(p_centro,''))) = 'P210' then 'remoto'
    else 'otra'
  end;
$$;


-- ============================================================
-- cargar_lote_inventario()
-- Recibe un arreglo JSON de filas y las inserta en una version
-- en preparacion. Solo el administrador puede ejecutarla.
--
-- RN-013: las filas entran siempre en estado 'preparando'.
-- La version activa sigue sirviendo consultas hasta que la
-- nueva se valide por completo.
-- ============================================================
create or replace function public.cargar_lote_inventario(
  p_version_id uuid,
  p_filas      jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
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
  on conflict (version_id, material) do nothing;

  get diagnostics v_insertadas = row_count;

  update public.versiones_datos
     set filas_cargadas = filas_cargadas + v_insertadas
   where id = p_version_id;

  return v_insertadas;
end;
$$;


-- ############################################################
-- BLOQUE 3 - ACTIVACION Y REVERSION
-- ############################################################

-- ============================================================
-- iniciar_version_datos()
-- Abre una version en preparacion. La activa sigue intacta y
-- respondiendo consultas durante toda la carga.
-- ============================================================
create or replace function public.iniciar_version_datos(
  p_archivo         text,
  p_filas_esperadas integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede iniciar una carga.';
  end if;

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
$$;


-- ============================================================
-- activar_version_datos()
-- RN-012: valida la carga y solo entonces conmuta. Si algo no
-- cuadra, la version queda como fallida y la activa no se toca.
--
-- ADR-002: al activar, se conservan como maximo dos versiones
-- completas. De las anteriores se elimina el inventario, pero
-- el registro de auditoria permanece.
-- ============================================================
create or replace function public.activar_version_datos(p_version_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_esperadas integer;
  v_cargadas  integer;
  v_reales    integer;
  v_sin_texto integer;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede activar una version.';
  end if;

  select filas_esperadas, filas_cargadas
    into v_esperadas, v_cargadas
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

  update public.versiones_datos
     set estado = 'anterior'
   where estado = 'activa';

  update public.versiones_datos
     set estado = 'activa',
         resultado = 'Carga correcta',
         finalizado_en = now()
   where id = p_version_id;

  delete from public.inventario_materiales
   where version_id in (
     select id from public.versiones_datos
     where estado in ('anterior','fallida')
       and id <> p_version_id
       and id not in (
         select id from public.versiones_datos
         where estado = 'anterior'
         order by iniciado_en desc
         limit 1
       )
   );

  return jsonb_build_object(
    'ok', true,
    'filas', v_reales,
    'sin_texto', v_sin_texto,
    'mensaje', format('Version activada con %s materiales.', v_reales));
end;
$$;


-- ============================================================
-- revertir_version_datos()
-- Vuelve a la version anterior si la nueva presenta problemas.
-- ============================================================
create or replace function public.revertir_version_datos()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
$$;


-- ------------------------------------------------------------
-- Verificacion: deben aparecer cuatro funciones
-- ------------------------------------------------------------
select p.proname as funcion
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('iniciar_version_datos',
                    'activar_version_datos',
                    'revertir_version_datos',
                    'cargar_lote_inventario')
order by p.proname;

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

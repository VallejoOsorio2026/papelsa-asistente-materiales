-- ============================================================
-- 017_inactividad.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- RN-009: tras 60 minutos sin actividad la solicitud se cierra
-- como INCOMPLETA, nunca como resuelta. Una solicitud que el
-- ingeniero abandono no es una solicitud atendida, y contarla
-- como tal falsearia las metricas del piloto.
--
-- ADR-017: el arranque de la aplicacion resuelve TRES cosas en
-- una sola llamada: cierra las vencidas, lee el perfil y lee
-- la version de inventario activa. Con la latencia hasta
-- Oregon (80-100 ms), tres viajes se notan al abrir.
-- ============================================================


-- ------------------------------------------------------------
-- cerrar_solicitudes_inactivas()
-- Los minutos salen de la tabla configuracion, no del codigo:
-- ajustar el plazo no deberia exigir redesplegar nada.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cerrar_solicitudes_inactivas()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_minutos integer;
  v_cerradas integer;
begin
  select coalesce(
           (select valor::integer from public.configuracion
            where clave = 'minutos_inactividad'),
           60)
    into v_minutos;

  update public.solicitudes
     set estado        = 'incompleta',
         motivo_cierre = 'inactividad',
         cerrada_en    = now()
   where estado = 'abierta'
     and ultima_actividad_en < now() - (v_minutos || ' minutes')::interval;

  get diagnostics v_cerradas = row_count;
  return v_cerradas;
end;
$function$;


-- ------------------------------------------------------------
-- iniciar_sesion_app()
-- Se llama al abrir la aplicacion (ADR-017).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.iniciar_sesion_app()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_cerradas integer := 0;
  v_perfil   jsonb;
  v_version  jsonb;
begin
  if not public.es_usuario_activo() then
    return jsonb_build_object('ok', false,
      'mensaje', 'Se requiere sesion activa.');
  end if;

  -- RN-009: respaldo del cierre por inactividad
  v_cerradas := public.cerrar_solicitudes_inactivas();

  select to_jsonb(p) into v_perfil
  from (
    select id, correo, nombre, rol, activo
    from public.perfiles where id = auth.uid()
  ) p;

  select to_jsonb(v) into v_version
  from (
    select numero, filas_cargadas, finalizado_en
    from public.versiones_datos where estado = 'activa'
  ) v;

  return jsonb_build_object(
    'ok', true,
    'perfil', v_perfil,
    'inventario', v_version,
    'cerradas_por_inactividad', v_cerradas
  );
end;
$function$;

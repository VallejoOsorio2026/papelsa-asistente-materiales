-- ============================================================
-- 021_feedback_motivo.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- RN-029: la encuesta "¿Te fue util?" es opcional y no bloquea
-- una nueva consulta. Un "no" abre el detalle del motivo.
--
-- Saber que algo fallo no sirve si no se sabe QUE fallo. Los
-- motivos salen de los modos de fallo observados en el piloto,
-- no de categorias genericas.
--
-- ⚠️ ESTA FUNCION TUVO UNA GEMELA (error 7 del historial). La
-- version antigua de tres parametros se elimino el 24-08-2026
-- tras comprobar que ninguna otra funcion dependia de ella:
--   drop function public.registrar_feedback(uuid, boolean, text);
-- Al cambiar el numero de parametros, create or replace NO
-- sustituye: crea otra. Hay que hacer DROP con la firma exacta.
--
-- on conflict (solicitud_id) do update: el ingeniero puede
-- cambiar de opinion. Se guarda la ultima respuesta, no dos.
--
-- Se sella la version de datos y la del sistema para poder
-- comparar la satisfaccion entre versiones del motor.
-- ============================================================

CREATE OR REPLACE FUNCTION public.registrar_feedback(
  p_solicitud_id uuid,
  p_util         boolean,
  p_comentario   text DEFAULT NULL::text,
  p_motivo       text DEFAULT NULL::text,
  p_esperado     text DEFAULT NULL::text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not public.es_usuario_activo() then
    raise exception 'Se requiere sesion activa.';
  end if;

  insert into public.feedback (
    solicitud_id, usuario_id, util, comentario,
    motivo, termino_esperado,
    version_datos_id, version_sistema, revisado
  ) values (
    p_solicitud_id, auth.uid(), p_util, p_comentario,
    p_motivo, nullif(trim(coalesce(p_esperado,'')), ''),
    public.version_datos_activa(),
    coalesce((select valor from public.configuracion
              where clave = 'version_sistema'), 'sin registrar'),
    false
  )
  on conflict (solicitud_id) do update
    set util = excluded.util,
        comentario = excluded.comentario,
        motivo = excluded.motivo,
        termino_esperado = excluded.termino_esperado,
        creado_en = now();

  return true;
end;
$function$;

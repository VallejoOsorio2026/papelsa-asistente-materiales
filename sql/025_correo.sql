-- ============================================================
-- 025_correo.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- El aviso por correo al ingeniero cuando llega una solicitud.
--
-- EL CONTENIDO SE ARMA AQUI, no en la Edge Function: asi se
-- puede corregir el texto del correo sin volver a desplegar
-- nada. La Edge Function solo transporta.
--
-- La tabla HTML no es adorno: conserva las columnas al copiar
-- y pegar en SAP o Excel, cosa que el texto plano no garantiza.
-- Se envian ambas versiones porque no todo cliente de correo
-- muestra HTML.
--
-- El correo es el AVISO; la bandeja de la aplicacion es el
-- REGISTRO. Si el correo falla o cae en spam, la solicitud
-- sigue estando donde tiene que estar.
-- ============================================================


-- ------------------------------------------------------------
-- cuerpo_correo_solicitud()
-- La llama la Edge Function enviar-correo con la clave de
-- servicio.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cuerpo_correo_solicitud(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  s      public.solicitudes_materiales%rowtype;
  v_html text;
  v_txt  text;
  m      jsonb;
begin
  select * into s from public.solicitudes_materiales where id = p_id;
  if s.id is null then
    return jsonb_build_object('ok', false);
  end if;

  -- ---------- Version HTML ----------
  -- La tabla HTML conserva las columnas al copiar y pegar en
  -- SAP o Excel, cosa que el texto plano no garantiza.
  v_html := '<div style="font-family:-apple-system,Segoe UI,Roboto,'
         || 'Helvetica,Arial,sans-serif;color:#333;max-width:760px">';

  v_html := v_html
    || '<p style="font-size:15px;line-height:1.5">'
    || 'El ' || s.rol_solicitante || ' <strong>' || s.solicitante
    || '</strong> solicitó los siguientes materiales para la orden de '
    || 'trabajo <strong style="font-family:monospace">' || s.orden_trabajo
    || '</strong>.</p>';

  v_html := v_html
    || '<table cellspacing="0" cellpadding="8" '
    || 'style="border-collapse:collapse;font-size:13px;width:100%">'
    || '<tr style="background:#006975;color:#fff;text-align:left">'
    || '<th>Componente</th><th>Denominación</th><th>Ctd. Neces.</th>'
    || '<th>UM</th><th>T</th><th>S</th><th>Almacén</th><th>Centro</th></tr>';

  for m in select * from jsonb_array_elements(s.materiales)
  loop
    v_html := v_html
      || '<tr style="border-bottom:1px solid #ddd">'
      || '<td style="font-family:monospace"><strong>'
      || coalesce(m->>'componente','') || '</strong></td>'
      || '<td>' || coalesce(m->>'denominacion','') || '</td>'
      || '<td style="font-family:monospace">'
      || coalesce(m->>'cantidad','') || '</td>'
      || '<td>' || coalesce(m->>'um','') || '</td>'
      || '<td>' || coalesce(m->>'t','') || '</td>'
      || '<td>' || coalesce(m->>'s','') || '</td>'
      || '<td>' || coalesce(m->>'almacen','') || '</td>'
      || '<td>' || coalesce(m->>'centro','') || '</td>'
      || '</tr>';
  end loop;

  v_html := v_html || '</table>';

  v_html := v_html
    || '<p style="font-size:13px;color:#6D6D6D;margin-top:18px">'
    || 'Puedes copiar la tabla directamente y pegarla en SAP. '
    || 'Los datos de existencias corresponden a la última '
    || 'actualización del inventario, no a SAP en tiempo real.</p>'
    || '<p style="font-size:12px;color:#6D6D6D">'
    || 'Asistente de Materiales · PAPELSA Molino</p></div>';

  -- ---------- Version en texto plano ----------
  v_txt := 'El ' || s.rol_solicitante || ' ' || s.solicitante
        || ' solicito los siguientes materiales para la orden de trabajo '
        || s.orden_trabajo || '.' || chr(10) || chr(10);

  for m in select * from jsonb_array_elements(s.materiales)
  loop
    v_txt := v_txt
      || coalesce(m->>'componente','') || '  '
      || coalesce(m->>'denominacion','') || '  '
      || coalesce(m->>'cantidad','') || ' '
      || coalesce(m->>'um','') || '  '
      || coalesce(m->>'centro','') || '/' || coalesce(m->>'almacen','')
      || chr(10);
  end loop;

  return jsonb_build_object(
    'ok', true,
    'asunto', 'Solicitud de materiales · OT ' || s.orden_trabajo
              || ' · ' || s.solicitante,
    'html', v_html,
    'texto', v_txt,
    'destinatarios', s.destinatarios);
end;
$function$;


-- ------------------------------------------------------------
-- correos_pendientes()
-- Cola de reintento. Prevista para una tarea programada con
-- pg_cron (pendiente de montar).
--
-- Tope de 3 intentos: si el servicio de correo esta caido, no
-- tiene sentido reintentar indefinidamente. La solicitud sigue
-- visible en la bandeja igualmente.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.correos_pendientes(
  p_limite integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(c order by c.creada_en), '[]'::jsonb)
  from (
    select
      s.id,
      s.solicitante,
      s.rol_solicitante,
      s.orden_trabajo,
      s.materiales,
      s.total_items,
      s.destinatarios,
      s.creada_en,
      s.intentos
    from public.solicitudes_materiales s
    -- 'sin_servicio' se incluye (PENDIENTE-010): una solicitud
    -- registrada antes de configurar el correo quedaria fuera
    -- de la cola para siempre.
    where s.estado_correo in ('pendiente', 'sin_servicio')
      and s.intentos < 3          -- no se reintenta indefinidamente
    order by s.creada_en
    limit p_limite
  ) c;
$function$;


-- ------------------------------------------------------------
-- marcar_correo()
-- Estados posibles:
--   enviado       el correo salio
--   fallido       el servicio respondio con error
--   sin_servicio  no hay dominio ni clave configurados todavia
--
-- 'sin_servicio' no es un fallo: la solicitud esta registrada
-- y visible en la bandeja. Es el estado normal del piloto
-- mientras no se compre el dominio.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.marcar_correo(
  p_id     uuid,
  p_estado text,
  p_error  text DEFAULT NULL::text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if p_estado not in ('enviado','fallido','sin_servicio') then
    raise exception 'Estado de correo no valido.';
  end if;

  update public.solicitudes_materiales
     set estado_correo = p_estado,
         enviado_en    = case when p_estado = 'enviado' then now() end,
         error_correo  = p_error,
         intentos      = intentos + 1
   where id = p_id;

  return found;
end;
$function$;

-- ============================================================
-- 036_solicitud_materiales_vivo.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- M1-B: el 024 deja la orden de trabajo en 7 digitos. Despues
-- de el, produccion paso a 8 digitos en DOS sitios: la
-- restriccion de la tabla y la validacion de
-- enviar_solicitud_materiales(). Este archivo registra ese
-- cambio sin reescribir el 024, que es historico. Se ejecuta
-- DESPUES del 024; ver README.
--
-- La restriccion viva es NOT VALID: las filas anteriores no
-- se revalidaron. Se reproduce igual.
--
-- El comentario de la columna sigue diciendo "Siete digitos"
-- tambien en produccion. No se corrige aqui: PENDIENTE-020.
--
-- Fuente: introspeccion de solo lectura del 2026-09-22
-- (M1B_EVIDENCIA_VIVA_2026-09-22.txt, SHA-256 BB4C4AB0...E951E3
-- y M1B_EVIDENCIA_COMPLEMENTARIA_2026-09-22.txt, SHA-256
-- 2D422FFA...1930EE). Cuerpo copiado sin tocar.
-- ============================================================

alter table public.solicitudes_materiales
  drop constraint if exists solicitudes_materiales_orden_trabajo_check;

alter table public.solicitudes_materiales
  add constraint solicitudes_materiales_orden_trabajo_check
  check (orden_trabajo is null or orden_trabajo ~ '^[0-9]{8}$'::text) not valid;


-- ------------------------------------------------------------
-- enviar_solicitud_materiales()
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enviar_solicitud_materiales(p_solicitante text, p_orden text, p_materiales jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_perfil      public.perfiles%rowtype;
  v_destinos    jsonb;
  v_id          uuid;
  v_orden       text := nullif(trim(coalesce(p_orden, '')), '');
  v_solicitante text := trim(coalesce(p_solicitante, ''));
begin
  if not public.es_usuario_activo() then
    raise exception 'Se requiere sesion activa.';
  end if;

  select * into v_perfil from public.perfiles where id = auth.uid();

  if v_perfil.rol not in ('mecanico','contratista','admin') then
    raise exception 'Este usuario no envia solicitudes de materiales.';
  end if;

  if length(v_solicitante) < 3 then
    return jsonb_build_object('ok', false,
      'mensaje', 'Escribe tu nombre completo.');
  end if;

  if v_orden is not null and v_orden !~ '^[0-9]{8}$' then
    return jsonb_build_object('ok', false,
      'mensaje', 'La orden de trabajo debe tener exactamente 8 digitos, '
              || 'sin letras ni simbolos. Si no la tienes, dejala vacia.');
  end if;

  if p_materiales is null or jsonb_array_length(p_materiales) = 0 then
    return jsonb_build_object('ok', false,
      'mensaje', 'No hay materiales seleccionados.');
  end if;

  v_destinos := public.destinatarios_area(v_perfil.area);

  if jsonb_array_length(v_destinos) = 0 then
    return jsonb_build_object('ok', false,
      'mensaje', 'No hay destinatarios configurados para tu area. '
              || 'Avisa al administrador.');
  end if;

  insert into public.solicitudes_materiales (
    usuario_id, solicitante, rol_solicitante, area,
    orden_trabajo, materiales, total_items,
    destinatarios, version_datos_id
  ) values (
    auth.uid(), v_solicitante, v_perfil.rol, v_perfil.area,
    v_orden, p_materiales, jsonb_array_length(p_materiales),
    v_destinos, public.version_datos_activa()
  )
  returning id into v_id;

  return jsonb_build_object(
    'ok', true,
    'id', v_id,
    'destinatarios', v_destinos,
    'mensaje', format('Solicitud registrada%s. Se avisara a %s ingeniero%s.',
                      case when v_orden is null then ' sin orden de trabajo'
                           else ' para la orden ' || v_orden end,
                      jsonb_array_length(v_destinos),
                      case when jsonb_array_length(v_destinos) = 1
                           then '' else 's' end));
end;
$function$;

grant execute on function public.enviar_solicitud_materiales(text, text, jsonb) to public;
grant execute on function public.enviar_solicitud_materiales(text, text, jsonb) to anon;
grant execute on function public.enviar_solicitud_materiales(text, text, jsonb) to authenticated;
grant execute on function public.enviar_solicitud_materiales(text, text, jsonb) to service_role;

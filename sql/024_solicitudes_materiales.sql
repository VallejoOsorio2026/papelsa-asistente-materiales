-- ============================================================
-- 024_solicitudes_materiales.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- Mecanicos y contratistas buscan aqui, eligen material y lo
-- envian al ingeniero. El ingeniero sigue siendo quien decide
-- y quien lleva la informacion a SAP (RN-024, RN-028).
--
-- El nombre se pide en cada solicitud aunque haya sesion: la
-- cuenta puede compartirse entre varias personas. Sin ese
-- campo, el registro diria "mecanico" en todas y se perderia
-- la trazabilidad.
--
-- La orden de trabajo se valida DOS veces, aqui y en el
-- navegador. Una comprobacion que solo vive en el navegador no
-- protege nada.
--
-- Los destinatarios se congelan en la fila al enviar: si
-- manana cambian los ingenieros de guardia, hay que poder
-- saber a quien se aviso entonces.
-- ============================================================


-- ------------------------------------------------------------
-- enviar_solicitud_materiales()
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enviar_solicitud_materiales(
  p_solicitante text,
  p_orden       text,
  p_materiales  jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_perfil      public.perfiles%rowtype;
  v_destinos    jsonb;
  v_id          uuid;
  v_orden       text := trim(coalesce(p_orden, ''));
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

  if v_orden !~ '^[0-9]{7}$' then
    return jsonb_build_object('ok', false,
      'mensaje', 'La orden de trabajo debe tener exactamente 7 digitos, '
              || 'sin letras ni simbolos.');
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
    'mensaje', format('Solicitud registrada para la orden %s. '
                   || 'Se avisara a %s ingeniero%s.',
                      v_orden,
                      jsonb_array_length(v_destinos),
                      case when jsonb_array_length(v_destinos) = 1
                           then '' else 's' end));
end;
$function$;


-- ------------------------------------------------------------
-- solicitudes_pendientes()
-- La bandeja. Se ve aunque el correo falle o caiga en spam: el
-- correo es el aviso, esta bandeja es el registro.
--
-- El filtrado por area lo aplican las politicas RLS de la
-- tabla, no esta consulta.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.solicitudes_pendientes(
  p_limite integer DEFAULT 20
)
RETURNS jsonb
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(s order by s.creada_en desc), '[]'::jsonb)
  from (
    select id, solicitante, rol_solicitante, orden_trabajo,
           total_items, materiales, estado, estado_correo, creada_en
    from public.solicitudes_materiales
    where estado in ('nueva','vista')
    order by creada_en desc
    limit p_limite
  ) s;
$function$;


-- ------------------------------------------------------------
-- marcar_solicitud()
-- Al marcarla atendida desaparece de la bandeja de TODOS los
-- destinatarios del area, no solo de quien pulso. Es
-- deliberado: si ya la atendio un ingeniero, el otro no debe
-- volver a atenderla. Verificado en produccion el 24-08-2026.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.marcar_solicitud(
  p_id     uuid,
  p_estado text,
  p_nota   text DEFAULT NULL::text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if p_estado not in ('vista','atendida','descartada') then
    raise exception 'Estado no valido.';
  end if;

  update public.solicitudes_materiales
     set estado = p_estado,
         atendida_por = auth.uid(),
         atendida_en = now(),
         nota_ingeniero = coalesce(p_nota, nota_ingeniero)
   where id = p_id;

  return found;
end;
$function$;

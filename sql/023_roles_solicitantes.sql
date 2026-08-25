-- ============================================================
-- 023_roles_solicitantes.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- El proyecto escalo mas rapido de lo previsto: del piloto con
-- ingenieros se paso a mecanicos, contratistas y almacen.
--
-- Roles: admin, ingeniero, mecanico, contratista, jefe_almacen,
--        almacenista
-- Areas: mantenimiento, almacen
--
-- CADA AREA TIENE SUS DESTINATARIOS. Una solicitud de
-- mantenimiento no llega al almacen aunque el jefe de almacen
-- tenga recibe_solicitudes = true. No es un descuido: es el
-- diseno. Anadir un departamento nuevo es un INSERT, no un
-- rediseno.
--
-- Sin area indicada, se usa la del usuario que llama. Si
-- tampoco la tuviera, 'mantenimiento' como respaldo: mejor que
-- una solicitud llegue al area equivocada a que no llegue a
-- nadie.
-- ============================================================

CREATE OR REPLACE FUNCTION public.destinatarios_area(
  p_area text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object(
           'nombre', p.nombre,
           'correo', p.correo)), '[]'::jsonb)
  from public.perfiles p
  where p.recibe_solicitudes
    and p.activo
    and p.area = coalesce(
          p_area,
          (select area from public.perfiles where id = auth.uid()),
          'mantenimiento');
$function$;

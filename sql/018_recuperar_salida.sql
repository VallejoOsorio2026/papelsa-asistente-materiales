-- ============================================================
-- 018_recuperar_salida.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- Reconstruye la salida SAP de una solicitud ya registrada: el
-- ingeniero copio el bloque y perdio la ventana, o se equivoco
-- al pegar. Los datos ya estan guardados; repetir la busqueda
-- seria absurdo.
--
-- ADR-018: la ubicacion se toma del inventario VIGENTE, no de
-- la que se guardo. Si el material se movio de bodega, la
-- salida antigua enviaria al ingeniero a un almacen donde ya
-- no esta.
--
-- El control de acceso se delega en puede_ver_solicitud(): un
-- ingeniero no recupera la salida de otro.
--
-- NOTA (RN-033): entre varias ubicaciones se elige la de mayor
-- stock libre. Es una decision del sistema, tolerable aqui
-- porque se trata de reconstruir algo ya decidido, no de una
-- busqueda nueva.
-- ============================================================

CREATE OR REPLACE FUNCTION public.salida_de_solicitud(p_solicitud_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_filas jsonb;
begin
  if not public.puede_ver_solicitud(p_solicitud_id) then
    raise exception 'No tienes acceso a esa solicitud.';
  end if;

  select jsonb_agg(f order by f.orden) into v_filas
  from (
    select
      i.orden,
      d.material_elegido            as material,
      c.descripcion                 as descripcion,
      d.cantidad_final              as cantidad,
      i.cantidad_asumida,
      -- Ubicacion y unidad segun el inventario vigente
      (select im.unidad_medida_base
         from public.inventario_materiales im
        where im.version_id = public.version_datos_activa()
          and im.material = d.material_elegido
        limit 1)                    as unidad,
      (select im.almacen
         from public.inventario_materiales im
        where im.version_id = public.version_datos_activa()
          and im.material = d.material_elegido
        order by coalesce(im.stock_libre_utilizacion,0) desc
        limit 1)                    as almacen,
      (select im.centro
         from public.inventario_materiales im
        where im.version_id = public.version_datos_activa()
          and im.material = d.material_elegido
        order by coalesce(im.stock_libre_utilizacion,0) desc
        limit 1)                    as centro
    from public.solicitud_items i
    join public.decisiones d on d.item_id = i.id
    join public.candidatos  c on c.id = d.candidato_id
    where i.solicitud_id = p_solicitud_id
  ) f;

  return jsonb_build_object(
    'ok', v_filas is not null,
    'items', coalesce(v_filas, '[]'::jsonb)
  );
end;
$function$;

-- ============================================================
-- 013_agrupacion.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- RN-033 MULTIUBICACION: un material aparece en varias filas,
-- una por cada combinacion de centro y almacen donde tiene
-- registro en SAP. 46.212 materiales ocupan 65.883 filas.
--
-- Esta funcion devuelve UNA tarjeta por material, con sus
-- ubicaciones dentro. El ingeniero elige material Y ubicacion:
-- la salida SAP necesita saber de que almacen se retira.
--
-- Se piden p_limite * 8 filas a buscar_materiales porque un
-- material puede ocupar hasta 7 filas. Sin ese margen, pedir 5
-- materiales podria devolver 2 tras agrupar.
--
-- RN-034: los marcados para baja (BORRAR, BLOQUEADO, ANULADO)
-- van al FINAL, nunca se ocultan: 37 conservan stock real y
-- ocultarlos seria decidir por el ingeniero.
--
-- Las ubicaciones se ordenan por cercania al Molino (RN-018),
-- no por cantidad: primero donde el ingeniero puede ir
-- caminando.
-- ============================================================

CREATE OR REPLACE FUNCTION public.buscar_agrupado(
  p_consulta text,
  p_limite   integer DEFAULT 5
)
RETURNS TABLE(
  material            text,
  descripcion         text,
  puntaje             numeric,
  origen              text,
  unidad              text,
  material_antiguo    text,
  total_disponible    numeric,
  total_comprometido  numeric,
  dado_de_baja        boolean,
  ubicaciones         jsonb
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
  with encontrados as (
    select * from public.buscar_materiales(p_consulta, p_limite * 8)
  ),
  agrupado as (
    select
      e.material,
      max(e.descripcion)                    as descripcion,
      max(e.puntaje)                        as puntaje,
      (array_agg(e.origen order by e.puntaje desc))[1] as origen,
      max(e.unidad)                         as unidad,
      max(e.material_antiguo)               as material_antiguo,
      sum(e.disponible)                     as total_disponible,
      sum(e.comprometido)                   as total_comprometido,
      bool_or(public.es_material_baja(
        public.normalizar_texto(e.descripcion)))       as dado_de_baja,
      jsonb_agg(
        jsonb_build_object(
          'centro',       e.centro,
          'almacen',      e.almacen,
          'ubicacion',    e.ubicacion,
          'ambito',       e.ambito,
          'disponible',   e.disponible,
          'comprometido', e.comprometido
        )
        order by
          case e.ambito
            when 'molino'  then 1
            when 'planta'  then 2
            when 'virtual' then 3
            when 'remoto'  then 4
            else 5
          end,
          e.disponible desc
      ) as ubicaciones
    from encontrados e
    group by e.material
  )
  select
    a.material,
    a.descripcion,
    a.puntaje,
    a.origen,
    a.unidad,
    a.material_antiguo,
    a.total_disponible,
    a.total_comprometido,
    a.dado_de_baja,
    a.ubicaciones
  from agrupado a
  -- RN-034: los dados de baja van al final, nunca se ocultan
  order by a.dado_de_baja asc, a.puntaje desc, a.total_disponible desc
  limit p_limite;
$function$;

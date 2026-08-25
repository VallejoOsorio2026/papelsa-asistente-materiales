-- ============================================================
-- 011_clave_ubicacion.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- Clasifica cada fila del inventario segun donde esta el
-- material, para poder priorizar la disponibilidad cercana
-- al Molino (RN-018).
--
-- Los codigos concretos de centro viven aqui porque la funcion
-- los necesita para trabajar. NO se documentan en el resto del
-- repositorio publico.
--
-- Un centro desconocido devuelve 'otra', nunca oculta el
-- material (RN-032): en una parada de madrugada, saber que
-- algo existe en un sitio sin clasificar sigue siendo util.
--
-- IMMUTABLE: el resultado depende solo de los parametros, asi
-- que PostgreSQL puede reutilizarlo y usarlo en indices.
-- ============================================================

CREATE OR REPLACE FUNCTION public.clasificar_ubicacion(
  p_centro  text,
  p_almacen text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $function$
  select case
    when upper(trim(coalesce(p_centro,''))) = 'P110' then 'molino'
    when upper(trim(coalesce(p_centro,''))) = 'P120' then 'planta'
    when upper(trim(coalesce(p_centro,''))) = 'P999' then 'virtual'
    when upper(trim(coalesce(p_centro,''))) = 'P210' then 'remoto'
    else 'otra'
  end;
$function$;

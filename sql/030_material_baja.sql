-- ============================================================
-- 030_material_baja.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- M1-B: copia fiel de la base viva. Existia en Supabase pero
-- no en esta carpeta, y 013_agrupacion.sql la necesita al
-- crearse (funcion LANGUAGE sql: el cuerpo se valida en el
-- CREATE). Por eso se ejecuta ANTES del 013; ver README.
--
-- Fuente: pg_get_functiondef, introspeccion de solo lectura
-- del 2026-09-22 (M1B_EVIDENCIA_VIVA_2026-09-22.txt, SHA-256
-- BB4C4AB0...E951E3). No se reescribio el cuerpo.
--
-- Los GRANT reproducen el ACL vivo tal cual. Son amplios a
-- proposito de equivalencia, no de diseno: PENDIENTE-021.
-- ============================================================

CREATE OR REPLACE FUNCTION public.es_material_baja(p_texto text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select coalesce(p_texto,'') ~ '(borrar|bloquead|anulad)';
$function$;

grant execute on function public.es_material_baja(text) to public;
grant execute on function public.es_material_baja(text) to anon;
grant execute on function public.es_material_baja(text) to authenticated;
grant execute on function public.es_material_baja(text) to service_role;

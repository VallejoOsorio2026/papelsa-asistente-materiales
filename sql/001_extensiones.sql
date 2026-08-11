-- ============================================================
-- 001_extensiones.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- Orden de ejecucion: 1 de 5
-- ============================================================
-- pg_trgm  : similitud entre textos (busqueda difusa)
-- unaccent : elimina tildes para comparar sin acentos
-- ============================================================

create extension if not exists pg_trgm  with schema extensions;
create extension if not exists unaccent with schema extensions;

-- ------------------------------------------------------------
-- Verificacion: deben aparecer dos filas
-- ------------------------------------------------------------
select extname as extension, extversion as version
from pg_extension
where extname in ('pg_trgm', 'unaccent')
order by extname;

-- ------------------------------------------------------------
-- Prueba funcional: debe devolver un valor cercano a 0.33
-- ------------------------------------------------------------
select similarity('LLAVE MIXTA', 'llabe mista') as parecido;

-- ============================================================
-- 004_indexes.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- Orden de ejecucion: 4 de 5
-- Resultado esperado: 16 indices
-- ============================================================
-- Un indice permite a la base de datos saltar directo a las
-- filas relevantes en lugar de recorrer los 65.884 registros.
--
-- Nota de espacio (ADR-002): el indice trigram es el que mas
-- pesa. Por eso se indexa unicamente texto_normalizado y no la
-- columna original. Decision deliberada por el limite de 500 MB
-- del plan gratuito.
-- ============================================================


-- ============================================================
-- INVENTARIO - busqueda exacta (Etapas A y B del motor)
-- ============================================================
create index idx_inv_material
  on public.inventario_materiales (material);

create index idx_inv_material_antiguo
  on public.inventario_materiales (material_antiguo_norm)
  where material_antiguo_norm is not null;

create index idx_inv_version
  on public.inventario_materiales (version_id);

-- ============================================================
-- INVENTARIO - busqueda difusa (Etapa D del motor)
-- Permite encontrar "LLAVE MIXTA" escribiendo "llabe mista".
-- ============================================================
create index idx_inv_texto_trgm
  on public.inventario_materiales
  using gin (texto_normalizado extensions.gin_trgm_ops);

-- ============================================================
-- INVENTARIO - filtros de ubicacion (RN-018)
-- ============================================================
create index idx_inv_ubicacion
  on public.inventario_materiales (centro, almacen);

create index idx_inv_ambito
  on public.inventario_materiales (ambito_ubicacion)
  where ambito_ubicacion is not null;

-- ============================================================
-- VERSIONES - localizar la version activa al instante (RN-013)
-- ============================================================
create index idx_ver_activa
  on public.versiones_datos (estado)
  where estado = 'activa';

-- ============================================================
-- OPERACION - historial del usuario y cierre por inactividad
-- ============================================================
create index idx_sol_usuario
  on public.solicitudes (usuario_id, creada_en desc);

create index idx_sol_abiertas
  on public.solicitudes (ultima_actividad_en)
  where estado = 'abierta';

create index idx_items_solicitud
  on public.solicitud_items (solicitud_id);

create index idx_cand_item
  on public.candidatos (item_id);

create index idx_dec_item
  on public.decisiones (item_id);

-- ============================================================
-- REVISION - feedback negativo pendiente y errores abiertos
-- ============================================================
create index idx_feedback_negativo
  on public.feedback (creado_en desc)
  where util = false and revisado = false;

create index idx_errores_abiertos
  on public.errores (severidad, creado_en desc)
  where estado in ('abierto','en_revision');

-- ============================================================
-- APRENDIZAJE
-- ============================================================
create index idx_sinonimos_termino
  on public.sinonimos (termino);

create index idx_aprendizaje_usuario
  on public.aprendizaje_usuario (usuario_id, patron);


-- ------------------------------------------------------------
-- Verificacion: debe devolver 16
-- ------------------------------------------------------------
select count(*) as indices_creados
from pg_indexes
where schemaname = 'public'
  and indexname like 'idx_%';

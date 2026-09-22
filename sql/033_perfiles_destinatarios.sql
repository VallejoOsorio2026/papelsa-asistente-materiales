-- ============================================================
-- 033_perfiles_destinatarios.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- M1-B: dos columnas de perfiles que produccion tiene y que
-- ningun archivo de esta carpeta anadia. Las necesitan
-- destinatarios_area() del 023 (LANGUAGE sql, las exige al
-- crearse) y las politicas de solicitudes_materiales (034).
-- Se ejecuta ANTES del 023; ver README.
--
-- Solo se anade lo recuperado: sin restricciones nuevas,
-- porque la base viva no tiene ninguna sobre estas columnas.
--
-- Fuente: introspeccion de solo lectura del 2026-09-22
-- (M1B_EVIDENCIA_COMPLEMENTARIA_2026-09-22.txt, SHA-256
-- 2D422FFA...1930EE).
-- ============================================================

alter table public.perfiles
  add column area text default 'mantenimiento'::text;

alter table public.perfiles
  add column recibe_solicitudes boolean not null default false;

comment on column public.perfiles.area is
  'Departamento. Permite escalar a otras areas sin rediseno.';

comment on column public.perfiles.recibe_solicitudes is
  'Verdadero para quienes deben recibir las solicitudes de su area.';

create index idx_perfiles_destinatarios on public.perfiles
  using btree (area) where (recibe_solicitudes = true);

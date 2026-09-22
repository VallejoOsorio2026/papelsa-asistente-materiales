-- ============================================================
-- 031_jerga_planta.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- M1-B: la tabla existia en Supabase, pero ningun archivo de
-- esta carpeta la creaba. 014_sinonimos.sql y 020_jerga.sql la
-- usan desde funciones LANGUAGE sql, que la exigen al crearse:
-- se ejecuta ANTES de ambos; ver README.
--
-- Fuente: introspeccion de solo lectura del 2026-09-22
-- (M1B_EVIDENCIA_VIVA_2026-09-22.txt, SHA-256 BB4C4AB0...E951E3).
-- Columnas, restricciones, indices, politicas y comentarios
-- son los de produccion. Sin triggers ni secuencias: no los
-- hay en la base viva.
--
-- Los GRANT reproducen el ACL vivo. La proteccion real es RLS;
-- la revision de esos permisos queda en PENDIENTE-021.
-- ============================================================

create table public.jerga_planta (
  id             uuid        not null default gen_random_uuid(),
  termino        text        not null,
  equivale_a     text        not null,
  ambito         text        not null,
  nota           text,
  estado         text        not null default 'propuesto'::text,
  propuesto_por  uuid,
  validado_por   uuid,
  validado_en    timestamptz,
  veces_usado    integer     not null default 0,
  creado_en      timestamptz not null default now(),
  constraint jerga_planta_pkey primary key (id),
  constraint uq_jerga unique (termino, equivale_a, ambito),
  constraint jerga_planta_estado_check
    check (estado = any (array['propuesto'::text, 'validado'::text, 'rechazado'::text])),
  constraint jerga_planta_propuesto_por_fkey
    foreign key (propuesto_por) references public.perfiles(id),
  constraint jerga_planta_validado_por_fkey
    foreign key (validado_por) references public.perfiles(id)
);

comment on table public.jerga_planta is
  'Traduce vocabulario de planta a especificacion tecnica. Atada a un ambito: pequeno significa cosas distintas segun la familia.';

create index idx_jerga_pendiente on public.jerga_planta
  using btree (creado_en desc) where (estado = 'propuesto'::text);

create index idx_jerga_validada on public.jerga_planta
  using btree (termino) where (estado = 'validado'::text);

alter table public.jerga_planta enable row level security;

create policy jerga_admin_actualiza on public.jerga_planta
  as permissive for update to public
  using (es_admin())
  with check (es_admin());

create policy jerga_lectura on public.jerga_planta
  as permissive for select to public
  using (es_usuario_activo());

create policy jerga_propuesta on public.jerga_planta
  as permissive for insert to public
  with check (es_usuario_activo() and (estado = 'propuesto'::text) and (propuesto_por = auth.uid()));

grant all on table public.jerga_planta to anon;
grant all on table public.jerga_planta to authenticated;
grant all on table public.jerga_planta to service_role;

-- ============================================================
-- 032_busquedas_sin_resultado.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- M1-B: la tabla existia en Supabase, pero ningun archivo de
-- esta carpeta la creaba. La usan 015, 019 (desde una funcion
-- LANGUAGE sql, que la exige al crearse) y 022: se ejecuta
-- ANTES de todos ellos; ver README.
--
-- Fuente: introspeccion de solo lectura del 2026-09-22
-- (M1B_EVIDENCIA_VIVA_2026-09-22.txt, SHA-256 BB4C4AB0...E951E3).
-- Columnas en el orden vivo, incluidas ampliaciones y
-- resuelta, que produccion tiene al final. Sin triggers ni
-- secuencias: no los hay en la base viva.
--
-- Los GRANT reproducen el ACL vivo. La proteccion real es RLS;
-- la revision de esos permisos queda en PENDIENTE-021.
-- ============================================================

create table public.busquedas_sin_resultado (
  id                uuid        not null default gen_random_uuid(),
  usuario_id        uuid,
  consulta          text        not null,
  consulta_norm     text,
  nivel             smallint,
  total             integer     not null default 0,
  reportada         boolean     not null default false,
  comentario        text,
  esperaba          text,
  revisada          boolean     not null default false,
  version_datos_id  uuid,
  version_sistema   text,
  creado_en         timestamptz not null default now(),
  ampliaciones      integer     not null default 0,
  resuelta          boolean,
  constraint busquedas_sin_resultado_pkey primary key (id),
  constraint busquedas_sin_resultado_usuario_id_fkey
    foreign key (usuario_id) references public.perfiles(id),
  constraint busquedas_sin_resultado_version_datos_id_fkey
    foreign key (version_datos_id) references public.versiones_datos(id)
);

comment on table public.busquedas_sin_resultado is
  'Consultas que no dieron resultado util. Base para medir y mejorar el motor.';

comment on column public.busquedas_sin_resultado.ampliaciones is
  'Veces que el ingeniero pidio ver mas resultados. Cada una indica que el ranking no acerto.';

comment on column public.busquedas_sin_resultado.resuelta is
  'Verdadero si acabo eligiendo un material. Nulo mientras no se sepa.';

create index idx_busq_sin_revisar on public.busquedas_sin_resultado
  using btree (creado_en desc) where (revisada = false);

alter table public.busquedas_sin_resultado enable row level security;

create policy busquedas_insercion on public.busquedas_sin_resultado
  as permissive for insert to public
  with check (es_usuario_activo());

create policy busquedas_propia_actualizacion on public.busquedas_sin_resultado
  as permissive for update to public
  using (((usuario_id = auth.uid()) or es_admin()))
  with check (((usuario_id = auth.uid()) or es_admin()));

create policy busquedas_propias_lectura on public.busquedas_sin_resultado
  as permissive for select to public
  using (((usuario_id = auth.uid()) or es_admin()));

grant all on table public.busquedas_sin_resultado to anon;
grant all on table public.busquedas_sin_resultado to authenticated;
grant all on table public.busquedas_sin_resultado to service_role;

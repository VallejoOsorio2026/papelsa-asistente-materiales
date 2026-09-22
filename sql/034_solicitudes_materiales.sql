-- ============================================================
-- 034_solicitudes_materiales.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- M1-B: la tabla existia en Supabase, pero ningun archivo de
-- esta carpeta la creaba; el 024 ya la daba por hecha. Se
-- ejecuta DESPUES del 033 (sus politicas leen perfiles.area y
-- perfiles.recibe_solicitudes) y ANTES del 024; ver README.
--
-- La restriccion de orden_trabajo se crea aqui como esta en
-- produccion (8 digitos, NOT VALID). El 024 historico la
-- reemplaza por 7 digitos y el 036 la devuelve al estado vivo.
-- El resultado de la cadena completa es el de produccion.
--
-- CONTRADICCION CONSERVADA (PENDIENTE-020): el comentario de
-- orden_trabajo dice siete digitos y la restriccion exige
-- ocho. Asi esta en produccion y asi se versiona.
--
-- solicitudes_mat_actualizacion tiene WITH CHECK true en
-- produccion. Se reproduce sin cambios.
--
-- Fuente: introspeccion de solo lectura del 2026-09-22
-- (M1B_EVIDENCIA_VIVA_2026-09-22.txt, SHA-256 BB4C4AB0...E951E3).
-- Sin triggers ni secuencias: no los hay en la base viva.
--
-- Los GRANT reproducen el ACL vivo. La proteccion real es RLS;
-- la revision de esos permisos queda en PENDIENTE-021.
-- ============================================================

create table public.solicitudes_materiales (
  id                uuid        not null default gen_random_uuid(),
  usuario_id        uuid        not null,
  solicitante       text        not null,
  rol_solicitante   text        not null,
  area              text        not null default 'mantenimiento'::text,
  orden_trabajo     text,
  materiales        jsonb       not null,
  total_items       integer     not null default 0,
  destinatarios     jsonb       not null default '[]'::jsonb,
  estado_correo     text        not null default 'pendiente'::text,
  enviado_en        timestamptz,
  error_correo      text,
  intentos          integer     not null default 0,
  estado            text        not null default 'nueva'::text,
  atendida_por      uuid,
  atendida_en       timestamptz,
  nota_ingeniero    text,
  version_datos_id  uuid,
  creada_en         timestamptz not null default now(),
  constraint solicitudes_materiales_pkey primary key (id),
  constraint solicitudes_materiales_estado_check
    check (estado = any (array['nueva'::text, 'vista'::text, 'atendida'::text, 'descartada'::text])),
  constraint solicitudes_materiales_estado_correo_check
    check (estado_correo = any (array['pendiente'::text, 'enviado'::text, 'fallido'::text, 'sin_servicio'::text])),
  constraint solicitudes_materiales_usuario_id_fkey
    foreign key (usuario_id) references public.perfiles(id),
  constraint solicitudes_materiales_atendida_por_fkey
    foreign key (atendida_por) references public.perfiles(id),
  constraint solicitudes_materiales_version_datos_id_fkey
    foreign key (version_datos_id) references public.versiones_datos(id)
);

alter table public.solicitudes_materiales
  add constraint solicitudes_materiales_orden_trabajo_check
  check (orden_trabajo is null or orden_trabajo ~ '^[0-9]{8}$'::text) not valid;

comment on table public.solicitudes_materiales is
  'Solicitudes de mecanicos y contratistas. El registro no depende del correo.';

comment on column public.solicitudes_materiales.orden_trabajo is
  'Siete digitos exactos, sin letras ni simbolos.';

create index idx_sol_mat_cola on public.solicitudes_materiales
  using btree (creada_en) where (estado_correo = 'pendiente'::text);

create index idx_sol_mat_orden on public.solicitudes_materiales
  using btree (orden_trabajo);

create index idx_sol_mat_pendientes on public.solicitudes_materiales
  using btree (creada_en desc) where (estado = 'nueva'::text);

alter table public.solicitudes_materiales enable row level security;

create policy solicitudes_mat_actualizacion on public.solicitudes_materiales
  as permissive for update to public
  using ((es_admin() or (exists ( select 1
     from perfiles p
    where ((p.id = auth.uid()) and p.recibe_solicitudes and (p.area = solicitudes_materiales.area))))))
  with check (true);

create policy solicitudes_mat_insercion on public.solicitudes_materiales
  as permissive for insert to public
  with check ((es_usuario_activo() and (usuario_id = auth.uid())));

create policy solicitudes_mat_lectura on public.solicitudes_materiales
  as permissive for select to public
  using (((usuario_id = auth.uid()) or es_admin() or (exists ( select 1
     from perfiles p
    where ((p.id = auth.uid()) and p.recibe_solicitudes and (p.area = solicitudes_materiales.area))))));

grant all on table public.solicitudes_materiales to anon;
grant all on table public.solicitudes_materiales to authenticated;
grant all on table public.solicitudes_materiales to service_role;

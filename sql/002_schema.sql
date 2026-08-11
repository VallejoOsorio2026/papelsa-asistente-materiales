-- ============================================================
-- 002_schema.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- Orden de ejecucion: 2 de 5
-- Resultado esperado: 15 tablas en el esquema public
-- ============================================================
-- IMPORTANTE: al ejecutar en el SQL Editor de Supabase, elegir
-- la opcion "Run and enable RLS" para que las tablas nazcan
-- protegidas. Las politicas se definen en 005_rls.sql.
-- ============================================================


-- ############################################################
-- BLOQUE 1 - NUCLEO
-- ############################################################

-- ============================================================
-- PERFILES
-- Enlace uno a uno con el usuario de Supabase Auth.
-- ============================================================
create table public.perfiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  correo      text not null,
  nombre      text not null,
  rol         text not null default 'ingeniero'
              check (rol in ('admin', 'ingeniero')),
  activo      boolean not null default true,
  creado_en   timestamptz not null default now()
);

comment on table public.perfiles is
  'Usuarios autorizados. El rol y el campo activo controlan todo el acceso.';

-- ============================================================
-- VERSIONES_DATOS
-- Una fila por carga. Solo una puede estar activa (RN-013).
-- ============================================================
create table public.versiones_datos (
  id                uuid primary key default gen_random_uuid(),
  numero            integer generated always as identity,
  estado            text not null default 'preparando'
                    check (estado in ('preparando','activa','anterior','fallida')),
  archivo_nombre    text,
  filas_esperadas   integer,
  filas_cargadas    integer not null default 0,
  cargado_por       uuid references public.perfiles(id),
  iniciado_en       timestamptz not null default now(),
  finalizado_en     timestamptz,
  resultado         text,
  observaciones     text
);

comment on table public.versiones_datos is
  'Control de versiones del inventario. La version anterior sigue activa hasta validar la nueva.';

-- ============================================================
-- INVENTARIO_MATERIALES
-- 21 columnas originales de SAP (ADR-005) + auxiliares.
-- Las originales NUNCA se modifican (RN-011).
-- ============================================================
create table public.inventario_materiales (
  id                        bigint generated always as identity primary key,
  version_id                uuid not null references public.versiones_datos(id) on delete cascade,

  -- ---------- 21 columnas originales de SAP ----------
  material                  text not null,
  texto_breve_material      text,
  stock_libre_utilizacion   numeric,
  stock_consignacion        numeric,
  stock_proyectos           numeric,
  xcentro                   text,
  maximo                    numeric,
  minimo                    numeric,
  centro                    text,
  almacen                   text,
  ubicacion                 text,
  unidad_medida_base        text,
  planif_necesidades        text,
  grupo_compra              text,
  tipo_material             text,
  grupo_articulo            text,
  clase_valoracion          text,
  cat_val_stock_proyecto    text,
  caract_planif_nec         text,
  tam_lote_planif_nec       text,
  material_antiguo          text,

  -- ---------- auxiliares generadas por el sistema ----------
  texto_normalizado         text,
  material_antiguo_norm     text,
  ambito_ubicacion          text,

  cargado_en                timestamptz not null default now(),

  constraint uq_material_version unique (version_id, material)
);

comment on table public.inventario_materiales is
  'Inventario SAP. Columnas originales inmutables; las auxiliares se derivan al cargar.';
comment on column public.inventario_materiales.xcentro is
  'PENDIENTE-001: semantica por confirmar con datos reales.';


-- ############################################################
-- BLOQUE 2 - OPERACION
-- ############################################################

-- ============================================================
-- SOLICITUDES
-- ============================================================
create table public.solicitudes (
  id                  uuid primary key default gen_random_uuid(),
  usuario_id          uuid not null references public.perfiles(id),
  mensaje_original    text not null,
  estado              text not null default 'abierta'
                      check (estado in ('abierta','cerrada','incompleta')),
  motivo_cierre       text
                      check (motivo_cierre in ('resuelta','inactividad','cancelada')),
  solicitud_origen_id uuid references public.solicitudes(id),
  version_datos_id    uuid references public.versiones_datos(id),
  version_sistema     text,
  creada_en           timestamptz not null default now(),
  ultima_actividad_en timestamptz not null default now(),
  cerrada_en          timestamptz,
  tiempo_respuesta_ms integer
);

comment on table public.solicitudes is
  'RN-006 a RN-010. Permanece abierta mientras falte resolver algun item.';
comment on column public.solicitudes.solicitud_origen_id is
  'RN-010. Una solicitud cerrada no se modifica: se crea una nueva vinculada.';

-- ============================================================
-- SOLICITUD_ITEMS
-- ============================================================
create table public.solicitud_items (
  id                 uuid primary key default gen_random_uuid(),
  solicitud_id       uuid not null references public.solicitudes(id) on delete cascade,
  orden              integer not null,
  texto_item         text not null,
  cantidad           numeric,
  cantidad_asumida   boolean not null default false,
  tipo_material      text,
  marca              text,
  referencia         text,
  medida             text,
  atributos          jsonb,
  nivel_confianza    smallint check (nivel_confianza between 1 and 5),
  estado             text not null default 'pendiente'
                     check (estado in ('pendiente','requiere_aclaracion','resuelto','sin_resultado')),
  creado_en          timestamptz not null default now(),

  constraint uq_item_orden unique (solicitud_id, orden)
);

comment on table public.solicitud_items is
  'RN-005: un registro por material solicitado, procesado de forma independiente.';
comment on column public.solicitud_items.cantidad_asumida is
  'RN-004: verdadero cuando el usuario no indico cantidad y se asumio 1.';

-- ============================================================
-- CANDIDATOS
-- ============================================================
create table public.candidatos (
  id                 uuid primary key default gen_random_uuid(),
  item_id            uuid not null references public.solicitud_items(id) on delete cascade,
  material           text not null,
  descripcion        text,
  puntaje            numeric,
  nivel_confianza    smallint check (nivel_confianza between 1 and 5),
  posicion           integer,
  origen_coincidencia text,
  mostrado           boolean not null default false,
  creado_en          timestamptz not null default now()
);

comment on table public.candidatos is
  'Trazabilidad del motor: permite auditar un error critico meses despues.';

-- ============================================================
-- DECISIONES
-- ============================================================
create table public.decisiones (
  id                 uuid primary key default gen_random_uuid(),
  item_id            uuid not null references public.solicitud_items(id) on delete cascade,
  candidato_id       uuid references public.candidatos(id),
  material_elegido   text,
  cantidad_final     numeric,
  descartados        jsonb,
  correccion_usuario text,
  decidido_en        timestamptz not null default now()
);

comment on table public.decisiones is
  'RN-024: la aplicacion sugiere, el ingeniero decide. Aqui queda su decision.';

-- ============================================================
-- FEEDBACK
-- ============================================================
create table public.feedback (
  id                 uuid primary key default gen_random_uuid(),
  solicitud_id       uuid not null references public.solicitudes(id) on delete cascade,
  usuario_id         uuid not null references public.perfiles(id),
  util               boolean not null,
  comentario         text,
  version_sistema    text,
  version_datos_id   uuid references public.versiones_datos(id),
  revisado           boolean not null default false,
  creado_en          timestamptz not null default now(),

  constraint uq_feedback_solicitud unique (solicitud_id)
);

comment on table public.feedback is
  'RN-029: encuesta opcional. Un "no" marca el caso para revision.';


-- ############################################################
-- BLOQUE 3 - APRENDIZAJE Y GOBIERNO
-- ############################################################

-- ============================================================
-- SINONIMOS
-- ============================================================
create table public.sinonimos (
  id            uuid primary key default gen_random_uuid(),
  termino       text not null,
  equivalente   text not null,
  ambito        text not null default 'sugerido'
                check (ambito in ('global_validado','sugerido')),
  usuario_id    uuid references public.perfiles(id),
  veces_visto   integer not null default 1,
  validado_por  uuid references public.perfiles(id),
  validado_en   timestamptz,
  creado_en     timestamptz not null default now(),

  constraint uq_sinonimo unique (termino, equivalente, ambito)
);

comment on table public.sinonimos is
  'RN-025: lo sugerido no es regla. Solo pasa a global_validado por decision del admin.';

-- ============================================================
-- APRENDIZAJE_USUARIO
-- ============================================================
create table public.aprendizaje_usuario (
  id              uuid primary key default gen_random_uuid(),
  usuario_id      uuid not null references public.perfiles(id) on delete cascade,
  patron          text not null,
  material        text not null,
  veces_elegido   integer not null default 1,
  ultima_vez      timestamptz not null default now(),

  constraint uq_patron_usuario unique (usuario_id, patron, material)
);

comment on table public.aprendizaje_usuario is
  'RN-026: modifica el ranking, nunca oculta alternativas validas.';

-- ============================================================
-- REGLAS_NEGOCIO
-- Aqui viven los codigos internos de centros y almacenes,
-- deliberadamente fuera del repositorio publico.
-- ============================================================
create table public.reglas_negocio (
  id             uuid primary key default gen_random_uuid(),
  codigo         text not null,
  categoria      text not null,
  clave          text,
  valor          text,
  descripcion    text,
  estado         text not null default 'vigente'
                 check (estado in ('vigente','provisional','derogada')),
  prioridad      integer,
  version        integer not null default 1,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),

  constraint uq_regla unique (codigo, version)
);

comment on table public.reglas_negocio is
  'Reglas oficiales versionadas. Incluye centros y almacenes (no publicados en GitHub).';

-- ============================================================
-- VERSIONES_SISTEMA
-- ============================================================
create table public.versiones_sistema (
  id          uuid primary key default gen_random_uuid(),
  version     text not null unique,
  descripcion text,
  activa      boolean not null default false,
  liberada_en timestamptz not null default now()
);

-- ============================================================
-- ERRORES
-- ============================================================
create table public.errores (
  id              uuid primary key default gen_random_uuid(),
  severidad       text not null
                  check (severidad in ('menor','medio','alto','critico')),
  titulo          text not null,
  descripcion     text,
  solicitud_id    uuid references public.solicitudes(id),
  item_id         uuid references public.solicitud_items(id),
  reportado_por   uuid references public.perfiles(id),
  estado          text not null default 'abierto'
                  check (estado in ('abierto','en_revision','resuelto','descartado')),
  version_sistema text,
  creado_en       timestamptz not null default now(),
  resuelto_en     timestamptz
);

comment on table public.errores is
  'Ningun error critico abierto puede quedar sin revisar antes de liberar version.';

-- ============================================================
-- CONFIGURACION
-- ============================================================
create table public.configuracion (
  clave          text primary key,
  valor          text not null,
  descripcion    text,
  actualizado_en timestamptz not null default now()
);

-- ============================================================
-- BANCO_PRUEBAS
-- ============================================================
create table public.banco_pruebas (
  id                uuid primary key default gen_random_uuid(),
  categoria         text not null,
  consulta          text not null,
  material_esperado text,
  nivel_esperado    smallint check (nivel_esperado between 1 and 5),
  notas             text,
  activo            boolean not null default true,
  creado_en         timestamptz not null default now()
);

comment on table public.banco_pruebas is
  'Casos repetibles tras cada version para medir si mejoramos o empeoramos.';


-- ============================================================
-- VERIFICACION FINAL: debe devolver 15
-- ============================================================
select count(*) as total_tablas
from information_schema.tables
where table_schema = 'public';

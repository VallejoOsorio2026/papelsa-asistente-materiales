-- ============================================================
-- 005_rls.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- Orden de ejecucion: 5 de 5
-- ============================================================
-- Row Level Security: la seguridad real del sistema.
--
-- No depende de ocultar botones, ni de que la direccion web sea
-- desconocida, ni de la visibilidad del repositorio. Si ninguna
-- politica autoriza una operacion, se deniega. El silencio es no.
--
-- Prueba de aceptacion: cualquier persona con la direccion de la
-- aplicacion y todo el codigo a la vista debe obtener cero filas
-- sin una sesion valida.
-- ============================================================


-- ############################################################
-- BLOQUE 1 - FUNCIONES AUXILIARES
-- ############################################################
-- security definer permite consultar la tabla perfiles aunque
-- quien pregunta aun no tenga permiso de leerla. Sin esto se
-- produciria un bucle: para saber si puedes leer perfiles,
-- habria que leer perfiles.
-- ############################################################

create or replace function public.es_usuario_activo()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfiles
    where id = auth.uid() and activo = true
  );
$$;

comment on function public.es_usuario_activo is
  'Base de todo acceso. Sin sesion o con perfil inactivo devuelve falso.';


create or replace function public.es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfiles
    where id = auth.uid() and activo = true and rol = 'admin'
  );
$$;

comment on function public.es_admin is
  'Verdadero solo para el administrador del piloto, activo y autenticado.';


create or replace function public.puede_ver_solicitud(p_solicitud_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.solicitudes s
    where s.id = p_solicitud_id
      and (s.usuario_id = auth.uid() or public.es_admin())
  );
$$;


-- ############################################################
-- BLOQUE 2 - POLITICAS DEL NUCLEO
-- ############################################################

-- ============================================================
-- PERFILES
-- Nadie borra perfiles: se desactivan con activo = false, para
-- que el historial de solicitudes nunca quede huerfano.
-- Al no existir politica de delete, queda prohibido para todos.
-- ============================================================
create policy "perfil_propio_lectura"
  on public.perfiles for select
  using (id = auth.uid() or public.es_admin());

create policy "perfiles_admin_insercion"
  on public.perfiles for insert
  with check (public.es_admin());

create policy "perfiles_admin_actualizacion"
  on public.perfiles for update
  using (public.es_admin())
  with check (public.es_admin());

-- ============================================================
-- INVENTARIO_MATERIALES
-- Sin politica de update: RN-011, los datos SAP no se modifican
-- ni siquiera por el administrador. Corregir un dato exige una
-- nueva carga completa. Es una garantia estructural.
-- ============================================================
create policy "inventario_lectura_autenticados"
  on public.inventario_materiales for select
  using (public.es_usuario_activo());

create policy "inventario_admin_insercion"
  on public.inventario_materiales for insert
  with check (public.es_admin());

create policy "inventario_admin_borrado"
  on public.inventario_materiales for delete
  using (public.es_admin());

-- ============================================================
-- VERSIONES_DATOS
-- ============================================================
create policy "versiones_lectura_autenticados"
  on public.versiones_datos for select
  using (public.es_usuario_activo());

create policy "versiones_admin_insercion"
  on public.versiones_datos for insert
  with check (public.es_admin());

create policy "versiones_admin_actualizacion"
  on public.versiones_datos for update
  using (public.es_admin())
  with check (public.es_admin());

create policy "versiones_admin_borrado"
  on public.versiones_datos for delete
  using (public.es_admin());


-- ############################################################
-- BLOQUE 3 - OPERACION Y GOBIERNO
-- ############################################################
-- Cada ingeniero ve solo sus propias solicitudes. El admin ve
-- todo. Las tablas hijas heredan el permiso de la solicitud
-- padre a traves de puede_ver_solicitud().
-- ############################################################

-- ============================================================
-- SOLICITUDES
-- ============================================================
create policy "solicitudes_propias_lectura"
  on public.solicitudes for select
  using (usuario_id = auth.uid() or public.es_admin());

create policy "solicitudes_propias_insercion"
  on public.solicitudes for insert
  with check (usuario_id = auth.uid() and public.es_usuario_activo());

create policy "solicitudes_propias_actualizacion"
  on public.solicitudes for update
  using (usuario_id = auth.uid() or public.es_admin())
  with check (usuario_id = auth.uid() or public.es_admin());

-- ============================================================
-- SOLICITUD_ITEMS
-- ============================================================
create policy "items_lectura"
  on public.solicitud_items for select
  using (public.puede_ver_solicitud(solicitud_id));

create policy "items_escritura"
  on public.solicitud_items for insert
  with check (public.puede_ver_solicitud(solicitud_id));

create policy "items_actualizacion"
  on public.solicitud_items for update
  using (public.puede_ver_solicitud(solicitud_id))
  with check (public.puede_ver_solicitud(solicitud_id));

-- ============================================================
-- CANDIDATOS
-- ============================================================
create policy "candidatos_lectura"
  on public.candidatos for select
  using (exists (
    select 1 from public.solicitud_items i
    where i.id = candidatos.item_id
      and public.puede_ver_solicitud(i.solicitud_id)));

create policy "candidatos_escritura"
  on public.candidatos for insert
  with check (exists (
    select 1 from public.solicitud_items i
    where i.id = candidatos.item_id
      and public.puede_ver_solicitud(i.solicitud_id)));

-- ============================================================
-- DECISIONES
-- ============================================================
create policy "decisiones_lectura"
  on public.decisiones for select
  using (exists (
    select 1 from public.solicitud_items i
    where i.id = decisiones.item_id
      and public.puede_ver_solicitud(i.solicitud_id)));

create policy "decisiones_escritura"
  on public.decisiones for insert
  with check (exists (
    select 1 from public.solicitud_items i
    where i.id = decisiones.item_id
      and public.puede_ver_solicitud(i.solicitud_id)));

-- ============================================================
-- FEEDBACK
-- El usuario responde; solo el admin marca como revisado.
-- ============================================================
create policy "feedback_lectura"
  on public.feedback for select
  using (usuario_id = auth.uid() or public.es_admin());

create policy "feedback_insercion"
  on public.feedback for insert
  with check (usuario_id = auth.uid() and public.es_usuario_activo());

create policy "feedback_admin_actualizacion"
  on public.feedback for update
  using (public.es_admin())
  with check (public.es_admin());

-- ============================================================
-- ERRORES
-- Cualquier usuario activo reporta; solo el admin gestiona.
-- ============================================================
create policy "errores_lectura"
  on public.errores for select
  using (reportado_por = auth.uid() or public.es_admin());

create policy "errores_insercion"
  on public.errores for insert
  with check (public.es_usuario_activo());

create policy "errores_admin_actualizacion"
  on public.errores for update
  using (public.es_admin())
  with check (public.es_admin());

-- ============================================================
-- APRENDIZAJE_USUARIO
-- Cada uno solo accede a su propio aprendizaje.
-- ============================================================
create policy "aprendizaje_propio"
  on public.aprendizaje_usuario for select
  using (usuario_id = auth.uid() or public.es_admin());

create policy "aprendizaje_propio_escritura"
  on public.aprendizaje_usuario for insert
  with check (usuario_id = auth.uid());

create policy "aprendizaje_propio_actualizacion"
  on public.aprendizaje_usuario for update
  using (usuario_id = auth.uid())
  with check (usuario_id = auth.uid());

-- ============================================================
-- SINONIMOS - RN-025: lo sugerido no es regla.
-- Todos leen; solo el admin valida y escribe.
-- ============================================================
create policy "sinonimos_lectura"
  on public.sinonimos for select
  using (public.es_usuario_activo());

create policy "sinonimos_admin_escritura"
  on public.sinonimos for all
  using (public.es_admin())
  with check (public.es_admin());

-- ============================================================
-- REGLAS_NEGOCIO
-- ============================================================
create policy "reglas_lectura"
  on public.reglas_negocio for select
  using (public.es_usuario_activo());

create policy "reglas_admin_escritura"
  on public.reglas_negocio for all
  using (public.es_admin())
  with check (public.es_admin());

-- ============================================================
-- CONFIGURACION
-- ============================================================
create policy "configuracion_lectura"
  on public.configuracion for select
  using (public.es_usuario_activo());

create policy "configuracion_admin_escritura"
  on public.configuracion for all
  using (public.es_admin())
  with check (public.es_admin());

-- ============================================================
-- VERSIONES_SISTEMA
-- ============================================================
create policy "versiones_sistema_lectura"
  on public.versiones_sistema for select
  using (public.es_usuario_activo());

create policy "versiones_sistema_admin_escritura"
  on public.versiones_sistema for all
  using (public.es_admin())
  with check (public.es_admin());

-- ============================================================
-- BANCO_PRUEBAS - solo administracion
-- ============================================================
create policy "banco_pruebas_admin"
  on public.banco_pruebas for all
  using (public.es_admin())
  with check (public.es_admin());


-- ------------------------------------------------------------
-- Verificacion
-- Deben aparecer 15 filas, todas con rls_activo = true y
-- ninguna con politicas = 0.
-- ------------------------------------------------------------
select t.tablename as tabla,
       t.rowsecurity as rls_activo,
       count(p.policyname) as politicas
from pg_tables t
left join pg_policies p
  on p.tablename = t.tablename and p.schemaname = 'public'
where t.schemaname = 'public'
group by t.tablename, t.rowsecurity
order by politicas asc, t.tablename;

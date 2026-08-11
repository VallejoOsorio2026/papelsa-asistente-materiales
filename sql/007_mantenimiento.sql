-- ============================================================
-- 007_mantenimiento.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- Orden de ejecucion: 6 de 6
-- ============================================================
-- El numero 006 queda reservado para 006_search.sql, el motor
-- de busqueda, que se construira en la Fase 7 cuando ya se
-- conozca el texto real del inventario.
-- ============================================================


-- ============================================================
-- ping()
-- Unica funcion accesible sin sesion iniciada.
-- Los proyectos del plan gratuito se pausan tras 7 dias sin
-- actividad en la base de datos. Una tarea programada en GitHub
-- Actions invocara esta funcion periodicamente para evitarlo.
--
-- No expone informacion alguna: devuelve siempre el mismo texto.
-- ============================================================
create or replace function public.ping()
returns text
language sql
stable
as $$
  select 'ok';
$$;

grant execute on function public.ping() to anon, authenticated;

comment on function public.ping is
  'Keep-alive. No revela informacion: devuelve siempre el texto ok.';


-- ============================================================
-- cerrar_solicitudes_inactivas()
-- RN-009: tras 60 minutos sin actividad la solicitud se cierra
-- y se marca como INCOMPLETA, nunca como resuelta.
--
-- El umbral se lee de la tabla configuracion, de modo que pueda
-- ajustarse sin modificar codigo. Si el parametro no existe,
-- se usa 60 por defecto.
-- ============================================================
create or replace function public.cerrar_solicitudes_inactivas()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_minutos  integer;
  v_cerradas integer;
begin
  select coalesce(
           (select valor::integer from public.configuracion
            where clave = 'minutos_inactividad'),
           60)
    into v_minutos;

  update public.solicitudes
     set estado        = 'incompleta',
         motivo_cierre = 'inactividad',
         cerrada_en    = now()
   where estado = 'abierta'
     and ultima_actividad_en < now() - (v_minutos || ' minutes')::interval;

  get diagnostics v_cerradas = row_count;
  return v_cerradas;
end;
$$;

comment on function public.cerrar_solicitudes_inactivas is
  'RN-009: cierre por inactividad. Marca incompleta, nunca resuelta.';


-- ============================================================
-- version_datos_activa()
-- RN-013: devuelve la version de inventario vigente. Toda
-- consulta debe filtrar por este valor, de modo que una carga
-- en curso nunca contamine los resultados.
-- ============================================================
create or replace function public.version_datos_activa()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.versiones_datos
  where estado = 'activa'
  order by iniciado_en desc
  limit 1;
$$;


-- ============================================================
-- CONFIGURACION INICIAL
-- Parametros ajustables sin tocar codigo.
-- ============================================================
insert into public.configuracion (clave, valor, descripcion) values
  ('minutos_inactividad', '60',
   'RN-009: minutos sin actividad tras los cuales la solicitud se cierra como incompleta'),
  ('umbral_confianza_alta', '0.75',
   'Similitud minima para considerar coincidencia de alta confianza'),
  ('umbral_confianza_minima', '0.25',
   'Similitud por debajo de la cual un candidato se descarta'),
  ('max_candidatos_mostrados', '5',
   'Cantidad maxima de alternativas presentadas al ingeniero'),
  ('tamano_lote_carga', '500',
   'Filas por lote al cargar inventario desde el navegador')
on conflict (clave) do nothing;


-- ------------------------------------------------------------
-- Verificacion
-- Esperado: ok | 0 | 5
-- El 0 es correcto mientras no existan solicitudes que cerrar.
-- ------------------------------------------------------------
select public.ping()                               as ping,
       public.cerrar_solicitudes_inactivas()       as solicitudes_cerradas,
       (select count(*) from public.configuracion) as parametros;

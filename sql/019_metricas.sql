-- ============================================================
-- 019_metricas.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- Metricas del piloto, restringidas al administrador.
--
-- SEGURIDAD (error 22 del historial, GRAVE): la primera version
-- era consultable por CUALQUIER usuario autenticado. Ocultar el
-- panel en pantalla no protegia nada.
--
-- Y el primer REVOKE no basto: en PostgreSQL toda funcion nueva
-- concede EXECUTE a PUBLIC por defecto, asi que basta con
-- volver a crearla para reabrir el agujero. La proteccion real
-- es la verificacion de rol DENTRO de la funcion.
--
-- De ahi la separacion en dos: metricas_calculo hace el
-- trabajo, metricas_piloto es la unica puerta y comprueba quien
-- llama antes de abrir.
--
-- ⚠️ Los GRANT/REVOKE del final son OBLIGATORIOS cada vez que
-- se vuelva a ejecutar este archivo.
--
-- KPI: la metrica mas contundente para direccion son las
-- consultas FUERA del horario de ingenieria. Cada una es una
-- interrupcion evitada, con dato objetivo. El tiempo ahorrado
-- NO se estima: se cuenta el volumen.
--
-- Horario (America/Bogota): L-J 7:30-15:30, V 7:30-14:45.
-- Madrugada 22:00-06:00 se separa por su valor demostrativo.
-- Los registros se guardan en UTC y se convierten aqui.
-- ============================================================


-- ------------------------------------------------------------
-- metricas_calculo()
-- Hace el calculo. NO comprueba permisos: no debe llamarse
-- directamente desde la aplicacion.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.metricas_calculo(p_dias integer DEFAULT 30)
RETURNS jsonb
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  with base as (
    select
      s.*,
      extract(dow  from s.creada_en at time zone 'America/Bogota') as dia_semana,
      extract(hour from s.creada_en at time zone 'America/Bogota')
        + extract(minute from s.creada_en at time zone 'America/Bogota')/60.0
                                                        as hora_decimal
    from public.solicitudes s
    where s.creada_en >= now() - (p_dias || ' days')::interval
  ),
  clasificado as (
    select b.*,
      case
        when b.dia_semana in (0,6) then 'fin_semana'
        when b.hora_decimal >= 22 or b.hora_decimal < 6 then 'madrugada'
        when b.dia_semana between 1 and 4
             and b.hora_decimal >= 7.5 and b.hora_decimal < 15.5 then 'laboral'
        when b.dia_semana = 5
             and b.hora_decimal >= 7.5 and b.hora_decimal < 14.75 then 'laboral'
        else 'fuera_horario'
      end as franja
    from base b
  )
  select jsonb_build_object(
    'periodo_dias', p_dias,
    'solicitudes_total',    (select count(*) from clasificado),
    'solicitudes_resueltas',(select count(*) from clasificado where estado='cerrada'),
    'materiales_total',     (select count(*) from public.solicitud_items i
                             join clasificado c on c.id = i.solicitud_id),
    'usuarios_activos',     (select count(distinct usuario_id) from clasificado),
    'por_franja', (
      select coalesce(jsonb_object_agg(franja, n), '{}'::jsonb)
      from (select franja, count(*) as n from clasificado group by franja) f
    ),
    'fuera_horario_ingenieria',
      (select count(*) from clasificado where franja <> 'laboral'),
    'por_nivel_confianza', (
      select coalesce(jsonb_object_agg(nivel::text, n), '{}'::jsonb)
      from (
        select i.nivel_confianza as nivel, count(*) as n
        from public.solicitud_items i
        join clasificado c on c.id = i.solicitud_id
        where i.nivel_confianza is not null
        group by i.nivel_confianza
      ) x
    ),
    'items_resueltos', (
      select count(*) from public.solicitud_items i
      join clasificado c on c.id = i.solicitud_id
      where i.estado = 'resuelto'
    ),
    'tiempo_respuesta_ms_medio', (
      select round(avg(tiempo_respuesta_ms))
      from clasificado where tiempo_respuesta_ms is not null
    ),
    'feedback_positivo', (
      select count(*) from public.feedback f
      join clasificado c on c.id = f.solicitud_id where f.util
    ),
    'feedback_negativo', (
      select count(*) from public.feedback f
      join clasificado c on c.id = f.solicitud_id where not f.util
    ),
    'busquedas_sin_resultado', (
      select count(*) from public.busquedas_sin_resultado
      where creado_en >= now() - (p_dias || ' days')::interval
    ),
    'busquedas_reportadas', (
      select count(*) from public.busquedas_sin_resultado
      where creado_en >= now() - (p_dias || ' days')::interval and reportada
    )
  );
$function$;


-- ------------------------------------------------------------
-- metricas_piloto()
-- Unica puerta de entrada. Comprueba el rol antes de calcular.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.metricas_piloto(p_dias integer DEFAULT 30)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede consultar las metricas.';
  end if;
  return public.metricas_calculo(p_dias);
end;
$function$;


-- ============================================================
-- PERMISOS  (obligatorio ejecutarlos tras cada CREATE)
-- ============================================================
-- metricas_calculo no debe ser invocable desde la aplicacion:
-- saltaria la comprobacion de rol.
revoke all on function public.metricas_calculo(integer) from public;
revoke all on function public.metricas_calculo(integer) from anon;
revoke all on function public.metricas_calculo(integer) from authenticated;

-- metricas_piloto si es invocable: se protege por dentro.
revoke all on function public.metricas_piloto(integer) from public;
revoke all on function public.metricas_piloto(integer) from anon;
grant execute on function public.metricas_piloto(integer) to authenticated;

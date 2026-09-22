-- ============================================================
-- 035_funciones_consulta.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- M1-B: las cuatro RPC que llama el navegador y que existian
-- en Supabase sin copia en esta carpeta.
--
--   consultar_materiales       js/search.js
--   consultar_sin_existencias  js/search.js
--   registrar_solicitud        js/feedback.js
--   mi_historial               js/feedback.js
--
-- Fuente: pg_get_functiondef, introspeccion de solo lectura
-- del 2026-09-22 (M1B_EVIDENCIA_VIVA_2026-09-22.txt, SHA-256
-- BB4C4AB0...E951E3). Cuerpos copiados sin tocar: mensajes,
-- umbrales y nombres JSON son los de produccion.
--
-- mi_historial es LANGUAGE sql: solicitudes, solicitud_items
-- y feedback (002) deben existir al crearla. Las otras tres
-- son plpgsql y resuelven sus dependencias al ejecutarse,
-- pero el README las coloca igualmente detras de todo lo que
-- usan (005, 007, 012, 013, 030).
--
-- Los GRANT reproducen el ACL vivo tal cual, incluido EXECUTE
-- para PUBLIC y anon. No es una decision de diseno: la
-- revision queda en PENDIENTE-021.
-- ============================================================


-- ------------------------------------------------------------
-- consultar_materiales()
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.consultar_materiales(p_consulta text, p_limite integer DEFAULT 5, p_desde integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_todas   jsonb;
  v_total   integer;
  v_mejor   numeric;
  v_segundo numeric;
  v_origen  text;
  v_nivel   smallint;
  v_mensaje text;
  v_max     integer;
begin
  if not public.es_usuario_activo() then
    raise exception 'Se requiere sesion activa.';
  end if;

  if public.version_datos_activa() is null then
    return jsonb_build_object(
      'nivel', 0, 'total', 0, 'sin_inventario', true,
      'mensaje', 'No hay inventario cargado. '
              || 'El administrador debe actualizar los datos.',
      'resultados', '[]'::jsonb);
  end if;

  -- Tope absoluto: mas alla de 15 no se pagina, se pregunta
  v_max := least(p_desde + p_limite, 15);

  select jsonb_agg(to_jsonb(r)), count(*)
    into v_todas, v_total
  from (
    select * from public.buscar_agrupado(p_consulta, v_max)
  ) r;

  if v_total is null or v_total = 0 then
    return jsonb_build_object(
      'nivel', 1, 'total', 0, 'hay_mas', false,
      'mensaje', 'No se encontro ningun material que coincida. '
              || 'Prueba con otras palabras, una referencia o un codigo.',
      'resultados', '[]'::jsonb);
  end if;

  v_mejor   := (v_todas->0->>'puntaje')::numeric;
  v_origen  :=  v_todas->0->>'origen';
  v_segundo := case when v_total > 1
                    then (v_todas->1->>'puntaje')::numeric else 0 end;

  -- RN-021 y ADR-003
  if v_origen = 'codigo' and v_total = 1 then
    v_nivel := 5;
    v_mensaje := 'Coincidencia exacta por codigo.';
  elsif v_origen in ('codigo','codigo antiguo') then
    v_nivel := 4;
    v_mensaje := 'Coincidencia por codigo. Se muestran alternativas '
              || 'porque hay mas de un material compatible.';
  elsif v_mejor >= 60 and v_mejor >= v_segundo * 1.8 then
    v_nivel := 4;
    v_mensaje := 'Coincidencia muy probable. Revisa las alternativas '
              || 'antes de decidir.';
  elsif v_mejor >= 35 then
    v_nivel := 3;
    v_mensaje := 'Varios materiales de la misma familia coinciden '
              || 'parcialmente. Revisa cual corresponde.';
  elsif v_mejor >= 18 then
    v_nivel := 2;
    v_mensaje := 'Coincidencias dudosas. Anade la marca, la referencia '
              || 'o la medida para acotar la busqueda.';
  else
    v_nivel := 1;
    v_mensaje := 'La solicitud es demasiado general. Indica el tipo de '
              || 'material, la medida o la referencia.';
  end if;

  -- Nivel 5: solo esa coincidencia, sin ampliar (RN-021)
  if v_nivel = 5 then
    return jsonb_build_object(
      'nivel', 5, 'total', 1, 'hay_mas', false,
      'mensaje', v_mensaje,
      'resultados', jsonb_build_array(v_todas->0));
  end if;

  return jsonb_build_object(
    'nivel',      v_nivel,
    'total',      v_total,
    'hay_mas',    (v_total >= v_max and v_max < 15),
    'mostrados',  v_total,
    'mensaje',    v_mensaje,
    'resultados', coalesce(v_todas, '[]'::jsonb));
end;
$function$;

grant execute on function public.consultar_materiales(text, integer, integer) to public;
grant execute on function public.consultar_materiales(text, integer, integer) to anon;
grant execute on function public.consultar_materiales(text, integer, integer) to authenticated;
grant execute on function public.consultar_materiales(text, integer, integer) to service_role;

-- ------------------------------------------------------------
-- consultar_sin_existencias()
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.consultar_sin_existencias(p_consulta text, p_limite integer DEFAULT 5)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_filas jsonb;
  v_total integer;
  v_max   numeric;
  v_nivel smallint;
begin
  if not public.es_usuario_activo() then
    raise exception 'Se requiere sesion activa.';
  end if;

  if public.version_datos_activa() is null then
    return jsonb_build_object(
      'nivel', 1, 'total', 0, 'hay_mas', false,
      'sin_inventario', true,
      'mensaje', 'No hay inventario cargado.',
      'resultados', '[]'::jsonb);
  end if;

  with encontrados as (
    select * from public.buscar_materiales(p_consulta, 400)
  ),
  agrupado as (
    select
      e.material,
      max(e.descripcion)                               as descripcion,
      max(e.puntaje)                                   as puntaje,
      (array_agg(e.origen order by e.puntaje desc))[1] as origen,
      max(e.unidad)                                    as unidad,
      max(e.material_antiguo)                          as material_antiguo,
      sum(e.disponible)                                as total_disponible,
      sum(e.comprometido)                              as total_comprometido,
      bool_or(public.es_material_baja(
        public.normalizar_texto(e.descripcion)))       as dado_de_baja,
      jsonb_agg(
        jsonb_build_object(
          'centro',       e.centro,
          'almacen',      e.almacen,
          'ubicacion',    e.ubicacion,
          'ambito',       e.ambito,
          'disponible',   e.disponible,
          'comprometido', e.comprometido
        )
        order by
          case e.ambito
            when 'molino'  then 1
            when 'planta'  then 2
            when 'virtual' then 3
            when 'remoto'  then 4
            else 5
          end,
          e.comprometido desc
      ) as ubicaciones
    from encontrados e
    group by e.material
  ),
  sin_stock as (
    select * from agrupado
    where coalesce(total_disponible, 0) = 0
  ),
  ordenado as (
    select s.*,
           row_number() over (
             order by s.dado_de_baja asc, s.puntaje desc
           ) as pos
    from sin_stock s
  ),
  recorte as (
    select * from ordenado where pos <= p_limite
  )
  select
    coalesce(jsonb_agg(to_jsonb(r) - 'pos' order by r.pos), '[]'::jsonb),
    (select count(*)::int from sin_stock),
    (select max(puntaje) from recorte)
  into v_filas, v_total, v_max
  from recorte r;

  if v_total = 0 then
    v_nivel := 1;
  elsif coalesce(v_max, 0) >= 90 then
    v_nivel := 4;
  else
    v_nivel := 3;
  end if;

  return jsonb_build_object(
    'nivel',          v_nivel,
    'total',          v_total,
    'hay_mas',        (v_total > p_limite and p_limite < 15),
    'sin_inventario', false,
    'mensaje',
      case when v_total = 0
        then 'Ningun codigo sin existencias coincide con lo que buscas.'
        else 'Codigos que existen en SAP pero no tienen unidades '
          || 'disponibles. Sirven para dejarlos pedidos.'
      end,
    'resultados',     v_filas);
end;
$function$;

grant execute on function public.consultar_sin_existencias(text, integer) to public;
grant execute on function public.consultar_sin_existencias(text, integer) to anon;
grant execute on function public.consultar_sin_existencias(text, integer) to authenticated;
grant execute on function public.consultar_sin_existencias(text, integer) to service_role;

-- ------------------------------------------------------------
-- mi_historial()
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mi_historial(p_limite integer DEFAULT 20)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(s order by s.creada_en desc), '[]'::jsonb)
  from (
    select
      so.id,
      so.mensaje_original,
      so.estado,
      so.motivo_cierre,
      so.creada_en,
      (select count(*) from public.solicitud_items i
        where i.solicitud_id = so.id) as total_items,
      (select count(*) from public.solicitud_items i
        where i.solicitud_id = so.id and i.estado = 'resuelto') as resueltos,
      (select f.util from public.feedback f
        where f.solicitud_id = so.id) as util
    from public.solicitudes so
    where so.usuario_id = auth.uid()
    order by so.creada_en desc
    limit p_limite
  ) s;
$function$;

grant execute on function public.mi_historial(integer) to public;
grant execute on function public.mi_historial(integer) to anon;
grant execute on function public.mi_historial(integer) to authenticated;
grant execute on function public.mi_historial(integer) to service_role;

-- ------------------------------------------------------------
-- registrar_solicitud()
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.registrar_solicitud(p_mensaje text, p_items jsonb, p_ms integer DEFAULT NULL::integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_solicitud uuid;
  v_item      uuid;
  v_cand      uuid;
  it          jsonb;
  ca          jsonb;
  v_pendientes integer := 0;
begin
  if not public.es_usuario_activo() then
    raise exception 'Se requiere sesion activa.';
  end if;

  insert into public.solicitudes (
    usuario_id, mensaje_original, estado,
    version_datos_id, version_sistema, tiempo_respuesta_ms
  ) values (
    auth.uid(), p_mensaje, 'abierta',
    public.version_datos_activa(),
    coalesce((select valor from public.configuracion
              where clave = 'version_sistema'), 'sin registrar'),
    p_ms
  )
  returning id into v_solicitud;

  for it in select * from jsonb_array_elements(p_items)
  loop
    insert into public.solicitud_items (
      solicitud_id, orden, texto_item,
      cantidad, cantidad_asumida,
      nivel_confianza, estado
    ) values (
      v_solicitud,
      (it->>'orden')::integer,
      it->>'textoOriginal',
      (it->>'cantidad')::numeric,
      coalesce((it->>'cantidadAsumida')::boolean, false),
      (it->>'nivel')::smallint,
      case when it->'elegido' is null or it->>'elegido' = 'null'
           then 'pendiente' else 'resuelto' end
    )
    returning id into v_item;

    if it->'elegido' is null or it->>'elegido' = 'null' then
      v_pendientes := v_pendientes + 1;
    end if;

    -- Todos los candidatos mostrados
    for ca in select * from jsonb_array_elements(coalesce(it->'candidatos','[]'::jsonb))
    loop
      insert into public.candidatos (
        item_id, material, descripcion,
        puntaje, nivel_confianza, origen_coincidencia, mostrado
      ) values (
        v_item,
        ca->>'material',
        ca->>'descripcion',
        (ca->>'puntaje')::numeric,
        (it->>'nivel')::smallint,
        ca->>'origen',
        true
      )
      returning id into v_cand;

      -- La decision del ingeniero
      if it->'elegido' is not null
         and it->'elegido'->>'material' = ca->>'material' then
        insert into public.decisiones (
          item_id, candidato_id, material_elegido, cantidad_final
        ) values (
          v_item, v_cand,
          ca->>'material',
          (it->>'cantidad')::numeric
        );
      end if;
    end loop;
  end loop;

  -- RN-006: solo se cierra si todos los items quedaron resueltos
  if v_pendientes = 0 then
    update public.solicitudes
       set estado = 'cerrada',
           motivo_cierre = 'resuelta',
           cerrada_en = now()
     where id = v_solicitud;
  end if;

  return v_solicitud;
end;
$function$;

grant execute on function public.registrar_solicitud(text, jsonb, integer) to public;
grant execute on function public.registrar_solicitud(text, jsonb, integer) to anon;
grant execute on function public.registrar_solicitud(text, jsonb, integer) to authenticated;
grant execute on function public.registrar_solicitud(text, jsonb, integer) to service_role;

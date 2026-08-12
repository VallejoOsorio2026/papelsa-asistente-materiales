select material,
       texto_breve_material,
       texto_normalizado,
       stock_libre_utilizacion as stock,
       unidad_medida_base as um,
       centro, almacen, ambito_ubicacion
from public.inventario_materiales
where texto_breve_material ilike '%valvula%'
   or texto_breve_material ilike '%válvula%'
   or texto_breve_material ilike '%cinta%'
limit 8;

-- 006_search.sql  (parte 1: extraccion de atributos)

-- ============================================================
-- extraer_referencias()
-- Devuelve los tokens que parecen codigo o referencia:
-- secuencias con digitos, con o sin letras.
--   'rodamiento 6205 2rs skf'  ->  {6205, 2rs}
-- ============================================================
create or replace function public.extraer_referencias(p_texto text)
returns text[]
language sql
immutable
set search_path = public, extensions
as $$
  select coalesce(array_agg(t), '{}')
  from (
    select distinct t
    from unnest(
      string_to_array(public.normalizar_texto(p_texto), ' ')
    ) as t
    where t ~ '[0-9]'          -- contiene algun digito
      and t !~ '^[0-9]+/[0-9]+$'  -- excluye medidas tipo 1/2
      and length(t) >= 3
  ) s;
$$;

comment on function public.extraer_referencias is
  'Etapa B: aisla referencias y codigos para exigir coincidencia exacta.';


-- ============================================================
-- extraer_medidas()
-- Detecta fracciones y dimensiones.
--   'llave mixta 3/4'          ->  {3/4}
--   'manguera 12mm x 50mt'     ->  {12mm, 50mt}
-- ============================================================
create or replace function public.extraer_medidas(p_texto text)
returns text[]
language sql
immutable
set search_path = public, extensions
as $$
  select coalesce(array_agg(t), '{}')
  from (
    select distinct t
    from unnest(
      string_to_array(public.normalizar_texto(p_texto), ' ')
    ) as t
    where t ~ '^[0-9]+/[0-9]+$'                        -- fracciones
       or t ~ '^[0-9]+(\.[0-9]+)?(mm|cm|mt|m|pulg|in|kg|gr|lt|ml)$'
  ) s;
$$;

comment on function public.extraer_medidas is
  'Las medidas son decisivas: una llave de 1/2 no sustituye a una de 3/4.';


-- ============================================================
-- extraer_palabras()
-- Palabras descriptivas: sin digitos y con longitud suficiente.
-- Se descartan conectores que no aportan a la busqueda.
-- ============================================================
create or replace function public.extraer_palabras(p_texto text)
returns text[]
language sql
immutable
set search_path = public, extensions
as $$
  select coalesce(array_agg(t), '{}')
  from (
    select distinct t
    from unnest(
      string_to_array(public.normalizar_texto(p_texto), ' ')
    ) as t
    where t !~ '[0-9]'
      and length(t) >= 3
      and t not in ('para','con','del','las','los','una','uno',
                    'por','sin','que','the','and','tipo','marca')
  ) s;
$$;


-- ============================================================
-- VERIFICACION
-- ============================================================
select
  public.extraer_referencias('rodamiento rigido 6205-2RS SKF') as ref_1,
  public.extraer_medidas('llave mixta 3/4 pulg')               as med_1,
  public.extraer_medidas('manguera 12mm x 50mt')               as med_2,
  public.extraer_palabras('valvula de bola en bronce para agua') as pal_1;
-- ============================================================
-- 006_search.sql  (parte 3: nivel de confianza)

-- ============================================================
-- consultar_materiales()
-- Envoltura de buscar_materiales() que añade el nivel de
-- confianza (RN-021) y devuelve un objeto listo para mostrar.
--
-- ADR-003: el nivel 5 exige coincidencia exacta Y candidato
-- unico. Si varios materiales empatan tecnicamente, el nivel
-- baja a 4 y se muestran las alternativas. Presentar un
-- material incorrecto como nivel 5 es un error critico.
-- ============================================================
create or replace function public.consultar_materiales(
  p_consulta text,
  p_limite   integer default 5
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_filas      jsonb;
  v_total      integer;
  v_mejor      numeric;
  v_segundo    numeric;
  v_origen     text;
  v_nivel      smallint;
  v_mensaje    text;
  v_max_mostrar integer;
begin
  if not public.es_usuario_activo() then
    raise exception 'Se requiere sesion activa.';
  end if;

  select coalesce((select valor::integer from public.configuracion
                   where clave = 'max_candidatos_mostrados'), 5)
    into v_max_mostrar;

  -- Se pide uno mas del limite para detectar empates
  select jsonb_agg(to_jsonb(r)), count(*)
    into v_filas, v_total
  from (
    select * from public.buscar_materiales(p_consulta, v_max_mostrar + 1)
  ) r;

  if v_total is null or v_total = 0 then
    return jsonb_build_object(
      'nivel', 1,
      'total', 0,
      'mensaje', 'No se encontro ningun material que coincida. '
              || 'Prueba con otras palabras, una referencia o un codigo.',
      'resultados', '[]'::jsonb);
  end if;

  v_mejor   := (v_filas->0->>'puntaje')::numeric;
  v_origen  :=  v_filas->0->>'origen';
  v_segundo := case when v_total > 1
                    then (v_filas->1->>'puntaje')::numeric
                    else 0 end;

  -- ------------------------------------------------------
  -- RN-021 y ADR-003
  -- ------------------------------------------------------
  if v_origen = 'codigo' and v_total = 1 then
    v_nivel := 5;
    v_mensaje := 'Coincidencia exacta por codigo.';

  elsif v_origen in ('codigo','codigo antiguo') then
    -- Coincidencia exacta pero con mas candidatos: no puede ser 5
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

  -- Nivel 5: se muestra solo esa coincidencia (RN-021)
  if v_nivel = 5 then
    v_filas := jsonb_build_array(v_filas->0);
  else
    v_filas := (
      select jsonb_agg(e)
      from (
        select e from jsonb_array_elements(v_filas) e
        limit v_max_mostrar
      ) s
    );
  end if;

  return jsonb_build_object(
    'nivel',       v_nivel,
    'total',       v_total,
    'mensaje',     v_mensaje,
    'resultados',  coalesce(v_filas, '[]'::jsonb));
end;
$$;

comment on function public.consultar_materiales is
  'RN-021 y ADR-003: nivel 5 solo con coincidencia exacta y candidato unico.';

-- 006_search.sql  (parte 4: similitud por palabra)

-- ============================================================
-- similitud_palabras()
-- pg_trgm compara la consulta contra el texto COMPLETO. Cuando
-- se busca una palabra suelta dentro de descripciones largas,
-- la similitud se diluye:
--
--   similarity('kra', 'kraft liner l 2.2 m6')  -> muy baja
--   similarity('kra', 'kraft')                 -> alta
--
-- Esta funcion compara cada palabra de la consulta contra cada
-- palabra del material y devuelve la mejor coincidencia media.
-- Asi 'kra', 'craf' o 'carft' encuentran KRAFT.
-- ============================================================
create or replace function public.similitud_palabras(
  p_consulta text,
  p_texto    text
)
returns real
language sql
immutable
set search_path = public, extensions
as $$
  select coalesce(avg(mejor), 0)::real
  from (
    select (
      select max(similarity(c, m))
      from unnest(string_to_array(p_texto, ' ')) as m
      where length(m) >= 2
    ) as mejor
    from unnest(string_to_array(p_consulta, ' ')) as c
    where length(c) >= 3
  ) s;
$$;

comment on function public.similitud_palabras is
  'Compara palabra contra palabra. Evita que una palabra corta se diluya en una descripcion larga.';

-- ============================================================
-- VERIFICACION
-- ============================================================
select
  round(similarity('kra', 'kraft liner l 2.2 m6')::numeric, 3)              as global_kra,
  round(public.similitud_palabras('kra', 'kraft liner l 2.2 m6')::numeric, 3) as palabra_kra,
  round(public.similitud_palabras('craf', 'kraft liner l 2.2 m6')::numeric, 3) as palabra_craf,
  round(public.similitud_palabras('carft', 'kraft liner l 2.2 m6')::numeric, 3) as palabra_carft;
-- ============================================================
-- 006_search.sql  (parte 2, revisada: motor con similitud por palabra)

create or replace function public.buscar_materiales(
  p_consulta text,
  p_limite   integer default 5
)
returns table (
  material            text,
  descripcion         text,
  puntaje             numeric,
  origen              text,
  disponible          numeric,
  comprometido        numeric,
  unidad              text,
  centro              text,
  almacen             text,
  ubicacion           text,
  ambito              text,
  material_antiguo    text
)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_norm      text;
  v_refs      text[];
  v_medidas   text[];
  v_palabras  text[];
  v_version   uuid;
  v_umbral    numeric;
begin
  if not public.es_usuario_activo() then
    raise exception 'Se requiere sesion activa.';
  end if;

  v_version := public.version_datos_activa();
  if v_version is null then
    return;
  end if;

  v_norm     := public.normalizar_texto(p_consulta);
  v_refs     := public.extraer_referencias(p_consulta);
  v_medidas  := public.extraer_medidas(p_consulta);
  v_palabras := public.extraer_palabras(p_consulta);

  select coalesce((select valor::numeric from public.configuracion
                   where clave = 'umbral_confianza_minima'), 0.12)
    into v_umbral;

  return query
  with base as (
    select
      i.material,
      i.texto_breve_material,
      i.texto_normalizado,
      i.material_antiguo,
      i.material_antiguo_norm,
      i.unidad_medida_base,
      i.centro, i.almacen, i.ubicacion, i.ambito_ubicacion,

      -- RN-030
      coalesce(i.stock_libre_utilizacion,0)
        + coalesce(i.stock_consignacion,0)          as disponible,
      coalesce(i.stock_proyectos,0)                 as comprometido,

      similarity(i.texto_normalizado, v_norm)       as sim,

      -- Similitud palabra a palabra: trigrama + fonetica +
      -- distancia. Resuelve craf/carft/kra frente a kraft.
      public.similitud_palabras(v_norm, i.texto_normalizado) as sim_pal,

      (lower(i.material) = v_norm)                  as cod_exacto,
      (i.material_antiguo_norm is not null
       and i.material_antiguo_norm = v_norm)        as cod_antiguo,

      (select count(*) from unnest(v_refs) r
        where i.texto_normalizado like '%' || r || '%')    as n_refs,
      (select count(*) from unnest(v_medidas) m
        where i.texto_normalizado like '%' || m || '%')    as n_medidas,
      (select count(*) from unnest(v_palabras) w
        where i.texto_normalizado like '%' || w || '%')    as n_palabras

    from public.inventario_materiales i
    where i.version_id = v_version
      and (
            lower(i.material) = v_norm
         or i.material_antiguo_norm = v_norm
         or similarity(i.texto_normalizado, v_norm) > v_umbral
         or public.similitud_palabras(v_norm, i.texto_normalizado) > 0.60
         or exists (select 1 from unnest(v_refs) r
                    where i.texto_normalizado like '%' || r || '%')
          )
  ),
  puntuado as (
    select b.*,
      (
        case when b.cod_exacto  then 100 else 0 end
      + case when b.cod_antiguo then  90 else 0 end
      + b.n_refs     * 25
      + b.n_medidas  * 20
      + b.n_palabras *  8
      + b.sim        * 30
      + b.sim_pal    * 40   -- peso alto: ha demostrado ser fiable

      -- RN-016: la disponibilidad solo reordena
      + case when b.disponible > 0 then 4 else 0 end
      + case b.ambito_ubicacion
          when 'molino'  then 2
          when 'planta'  then 1
          else 0
        end
      )::numeric as total,

      case
        when b.cod_exacto      then 'codigo'
        when b.cod_antiguo     then 'codigo antiguo'
        when b.n_refs > 0      then 'referencia'
        when b.n_medidas > 0   then 'medida'
        when b.sim_pal > 0.75  then 'descripcion aproximada'
        else 'descripcion'
      end as origen
    from base b
  )
  select
    p.material,
    p.texto_breve_material,
    round(p.total, 2),
    p.origen,
    p.disponible,
    p.comprometido,
    p.unidad_medida_base,
    p.centro,
    p.almacen,
    p.ubicacion,
    p.ambito_ubicacion,
    p.material_antiguo
  from puntuado p
  order by p.total desc, p.disponible desc
  limit p_limite;
end;
$$;

comment on function public.buscar_materiales is
  'RN-015 a RN-022. Combina codigo, referencia, medida, trigrama y similitud fonetica por palabra.';

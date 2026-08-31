-- ============================================================
-- 006_search.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- Extraccion de los tres tipos de dato que identifican un
-- material: referencias, medidas y palabras descriptivas.
--
-- RN-017: la prioridad es codigo y referencia -> descripcion ->
-- marca -> similitud. Estas funciones alimentan el ranking de
-- buscar_materiales.
--
-- ⚠️ ARCHIVO ACTUALIZADO 24-08-2026: incluye la correccion de
-- fracciones mixtas. La version anterior versionada estaba
-- incompleta.
--
-- El motor de busqueda se construyo tras observar datos reales
-- (ADR-008), no antes.
-- ============================================================


-- ------------------------------------------------------------
-- extraer_referencias()
-- Todo lo que lleva cifras y no es una fraccion: 6205, SKF6205,
-- 90.3858.00. Es el dato mas decisivo para identificar un
-- material concreto.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.extraer_referencias(p_texto text)
RETURNS text[]
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public', 'extensions'
AS $function$
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
$function$;


-- ------------------------------------------------------------
-- extraer_medidas()
--
-- FRACCIONES MIXTAS (error 17 del historial): de "4 1/2" solo
-- sobrevivia "1/2", porque el "4" se descartaba por corto. Un
-- disco de 4 1/2" y uno de 1/2" no tienen nada que ver.
--
-- La solucion es detectarlas sobre el TEXTO COMPLETO, antes de
-- partirlo en palabras: una vez separado, la relacion entre el
-- entero y la fraccion ya se perdio.
--
-- Se admite "4 1/2" y "4-1/2"; ambas se normalizan con espacio.
--
-- RN-015: identificar QUE material es va antes que donde esta.
-- Sin la medida correcta, lo demas sobra.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.extraer_medidas(p_texto text)
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'extensions'
AS $function$
  with norm as (
    select public.normalizar_texto(p_texto) as texto
  ),
  mixtas as (
    select distinct
      regexp_replace(m[1], '\s*-\s*', ' ', 'g') as medida
    from norm,
      regexp_matches(norm.texto, '([0-9]+[\s-]+[0-9]+/[0-9]+)', 'g') as m
  ),
  simples as (
    select distinct palabra as medida
    from norm, unnest(string_to_array(norm.texto, ' ')) as palabra
    where palabra ~ '^[0-9]+/[0-9]+$'
       or palabra ~ '^[0-9]+(\.[0-9]+)?(mm|cm|mt|m|pulg|in|kg|gr|lt|ml)$'
  ),
  -- Medidas compuestas NxNxN: 23% del catalogo (14.879/65.883 filas).
  -- Se devuelven las cifras separadas: el inventario las escribe de
  -- cinco formas distintas.
  compuestas as (
    select distinct c as medida
    from norm,
      regexp_matches(norm.texto,
        '([0-9]+(?:\.[0-9]+)?)\s*x\s*([0-9]+(?:\.[0-9]+)?)(?:\s*x\s*([0-9]+(?:\.[0-9]+)?))?',
        'g') as m,
      unnest(m) as c
    where c is not null
      and length(c) >= 2
  )
  select coalesce(array_agg(medida), '{}')
  from (
    select medida from mixtas
    union
    select medida from simples
    union
    select medida from compuestas
  ) s;
$function$;
-- ------------------------------------------------------------
-- extraer_palabras()
-- Las palabras descriptivas, sin cifras. Se descartan las de
-- menos de 3 letras y las vacias de contenido tecnico: en un
-- catalogo de 46.212 materiales, "para" coincide con casi todo
-- y solo aporta ruido al ranking.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.extraer_palabras(p_texto text)
RETURNS text[]
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public', 'extensions'
AS $function$
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
$function$;

-- ============================================================
-- 012_rendimiento.sql  (parte 1: comparacion de palabras)
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- ADR-011: busqueda en capas. Cada capa cubre un tipo de error
-- que las anteriores no resuelven. Ninguna sustituye a otra.
--
-- Se toma el MAYOR de los cuatro metodos, no el promedio: si
-- alguno reconoce la palabra, es una coincidencia valida.
--
-- Suelo de 0.55 (error 14 del historial): la distancia de
-- edicion normalizada daba falsos positivos entre palabras de
-- longitud muy distinta ("rodamiento" vs "liner" = 0.78). Por
-- debajo del suelo se devuelve solo el trigrama.
--
-- search_path incluye 'extensions' porque similarity,
-- metaphone y levenshtein viven en ese esquema.
-- ============================================================


-- ------------------------------------------------------------
-- parecido_palabra()
-- Compara DOS palabras sueltas.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.parecido_palabra(p_a text, p_b text)
RETURNS real
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public', 'extensions'
AS $function$
declare
  a text := lower(trim(coalesce(p_a,'')));
  b text := lower(trim(coalesce(p_b,'')));
  v_trigrama  real;
  v_fonetica  real := 0;
  v_distancia real := 0;
  v_prefijo   real := 0;
  v_dist      integer;
  v_max       integer;
  v_min       integer;
  v_resultado real;
begin
  if a = '' or b = '' then return 0; end if;
  if a = b then return 1; end if;

  v_max := greatest(length(a), length(b));
  v_min := least(length(a), length(b));

  -- 1. Trigrama: letras omitidas o sobrantes
  v_trigrama := similarity(a, b);

  -- 2. Abreviatura por truncamiento: una es prefijo de la otra.
  --    Cuanto mas larga la parte comun, mayor la confianza.
  if v_min >= 4 and (b like a || '%' or a like b || '%') then
    v_prefijo := case
      when v_min >= 6 then 0.95
      when v_min = 5  then 0.90
      else                 0.85
    end;

  -- 2b. Prefijo corto (3 letras): solo si la palabra larga
  --     tampoco es muy larga, para no confundir 'tor' con
  --     'tornado' cuando se buscaba 'tornillo'.
  elsif v_min = 3 and v_max <= 6
        and (b like a || '%' or a like b || '%') then
    v_prefijo := 0.70;
  end if;

  -- 3. Fonetica: letras sustituidas que suenan igual (C/K, B/V)
  if length(a) >= 4 and length(b) >= 4
     and abs(length(a) - length(b)) <= 2 then
    if metaphone(a, 8) = metaphone(b, 8) then
      v_fonetica := 0.92;
    elsif metaphone(a, 8) like metaphone(b, 8) || '%'
       or metaphone(b, 8) like metaphone(a, 8) || '%' then
      v_fonetica := 0.78;
    end if;
  end if;

  -- 4. Distancia de edicion: letras en otro orden
  v_dist := levenshtein(a, b);
  if abs(length(a) - length(b)) <= 2 and v_dist <= 3 then
    v_distancia := 1.0 - (v_dist::real / v_max);
  end if;

  v_resultado := greatest(v_trigrama, v_fonetica, v_distancia, v_prefijo);

  if v_resultado < 0.55 then
    return v_trigrama;
  end if;

  return v_resultado;
end;
$function$;


-- ------------------------------------------------------------
-- similitud_palabras()
-- Compara una CONSULTA COMPLETA contra una descripcion.
-- Para cada palabra de la consulta busca su mejor pareja en la
-- descripcion y promedia. Palabras de menos de 3 letras se
-- descartan: aportan ruido.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.similitud_palabras(
  p_consulta text,
  p_texto    text
)
RETURNS real
LANGUAGE sql
STABLE
SET search_path TO 'public', 'extensions'
AS $function$
  select coalesce(avg(mejor), 0)::real
  from (
    select (
      select max(public.parecido_palabra(c, m))
      from unnest(string_to_array(p_texto, ' ')) as m
      where length(m) >= 2
    ) as mejor
    from unnest(string_to_array(p_consulta, ' ')) as c
    where length(c) >= 3
  ) s;
$function$;

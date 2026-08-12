-- 009_fonetica.sql  (parte 1)

-- ============================================================
-- fuzzystrmatch aporta:
--   levenshtein()  distancia de edicion: cuenta cuantos cambios
--                  hacen falta para pasar de una palabra a otra.
--                  Penaliza bien las letras cambiadas de orden,
--                  que es justo donde falla el trigrama.
--   metaphone()    codigo fonetico: reduce la palabra a como
--                  suena, no a como se escribe.
-- ============================================================
create extension if not exists fuzzystrmatch with schema extensions;

-- ============================================================
-- VERIFICACION
-- ============================================================
select
  extensions.metaphone('kraft', 6) as f_kraft,
  extensions.metaphone('craf',  6) as f_craf,
  extensions.metaphone('carft', 6) as f_carft,
  extensions.levenshtein('kraft','craf')  as d_craf,
  extensions.levenshtein('kraft','carft') as d_carft,
  extensions.levenshtein('kraft','tornillo') as d_lejano;
-- ============================================================
-- 009_fonetica.sql  (parte 2)

-- ============================================================
-- parecido_palabra()
-- Compara dos palabras por tres vias y devuelve la mejor:
--
--   1. Trigrama   -> letras omitidas o sobrantes
--   2. Fonetica   -> letras sustituidas que suenan igual (C/K)
--   3. Distancia  -> letras en orden alterado
--
-- Ninguna sustituye a las otras: cada una cubre un tipo de
-- error distinto.
-- ============================================================
create or replace function public.parecido_palabra(
  p_a text,
  p_b text
)
returns real
language plpgsql
immutable
set search_path = public, extensions
as $$
declare
  a text := lower(trim(coalesce(p_a,'')));
  b text := lower(trim(coalesce(p_b,'')));
  v_trigrama real;
  v_fonetica real;
  v_distancia real;
  v_max integer;
begin
  if a = '' or b = '' then return 0; end if;
  if a = b then return 1; end if;

  -- 1. Trigrama
  v_trigrama := similarity(a, b);

  -- 2. Fonetica: solo si ambas superan tres letras, porque en
  --    palabras muy cortas el codigo fonetico es poco fiable.
  v_fonetica := 0;
  if length(a) >= 3 and length(b) >= 3 then
    if metaphone(a, 8) = metaphone(b, 8) then
      v_fonetica := 0.92;
    elsif metaphone(a, 8) like metaphone(b, 8) || '%'
       or metaphone(b, 8) like metaphone(a, 8) || '%' then
      v_fonetica := 0.78;
    end if;
  end if;

  -- 3. Distancia de edicion, normalizada por la palabra mas larga
  v_max := greatest(length(a), length(b));
  v_distancia := 1.0 - (levenshtein(a, b)::real / v_max);
  if v_distancia < 0 then v_distancia := 0; end if;

  -- Se toma la mejor de las tres
  return greatest(v_trigrama, v_fonetica, v_distancia);
end;
$$;

comment on function public.parecido_palabra is
  'Combina trigrama, fonetica y distancia de edicion. Cada tecnica cubre un tipo distinto de error.';


-- ============================================================
-- VERIFICACION
-- ============================================================
select
  round(public.parecido_palabra('craf','kraft')::numeric, 2)      as craf,
  round(public.parecido_palabra('carft','kraft')::numeric, 2)     as carft,
  round(public.parecido_palabra('kra','kraft')::numeric, 2)       as kra,
  round(public.parecido_palabra('balbula','valvula')::numeric, 2) as balbula,
  round(public.parecido_palabra('sinta','cinta')::numeric, 2)     as sinta,
  round(public.parecido_palabra('rodamiento','tornillo')::numeric, 2) as lejano;
-- ============================================================
-- 009_fonetica.sql  (parte 3)

-- ============================================================
-- similitud_palabras()
-- Version mejorada: compara cada palabra de la consulta contra
-- cada palabra del material usando parecido_palabra(), que
-- combina trigrama, fonetica y distancia de edicion.
--
-- Se devuelve la media de las mejores coincidencias, de modo
-- que una consulta acierte solo si TODAS sus palabras
-- encuentran algo parecido, no solo una.
-- ============================================================
create or replace function public.similitud_palabras(
  p_consulta text,
  p_texto    text
)
returns real
language sql
stable
set search_path = public, extensions
as $$
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
$$;

comment on function public.similitud_palabras is
  'Media de las mejores coincidencias palabra a palabra, con trigrama, fonetica y distancia.';


-- ============================================================
-- VERIFICACION contra descripciones reales del inventario
-- ============================================================
select
  round(public.similitud_palabras('craf',  'kraft liner l 2.2 m6')::numeric, 2)
    as craf_kraft,
  round(public.similitud_palabras('carft', 'kraft liner l 2.2 m6')::numeric, 2)
    as carft_kraft,
  round(public.similitud_palabras('sinta doble das',
        'cinta shurtape doble faz 48 mm x 50 mt')::numeric, 2)
    as sinta_doble,
  round(public.similitud_palabras('rodamiento',
        'kraft liner l 2.2 m6')::numeric, 2)
    as sin_relacion;
-- ============================================================
-- 009_fonetica.sql  (parte 2, corregida)

-- ============================================================
-- parecido_palabra()
-- Correccion: la distancia de edicion normalizada produce
-- falsos positivos cuando las palabras tienen longitudes muy
-- distintas ('rodamiento' contra 'liner' daba 0.78). Ahora
-- solo se aplica entre palabras de longitud comparable y con
-- pocos cambios reales.
-- ============================================================
create or replace function public.parecido_palabra(
  p_a text,
  p_b text
)
returns real
language plpgsql
immutable
set search_path = public, extensions
as $$
declare
  a text := lower(trim(coalesce(p_a,'')));
  b text := lower(trim(coalesce(p_b,'')));
  v_trigrama  real;
  v_fonetica  real := 0;
  v_distancia real := 0;
  v_dist      integer;
  v_max       integer;
  v_resultado real;
begin
  if a = '' or b = '' then return 0; end if;
  if a = b then return 1; end if;

  -- 1. Trigrama: letras omitidas o sobrantes
  v_trigrama := similarity(a, b);

  -- 2. Fonetica: letras sustituidas que suenan igual (C/K, B/V).
  --    Solo entre palabras de longitud comparable, para que
  --    'kraft' no se confunda con una palabra mucho mas larga.
  if length(a) >= 4 and length(b) >= 4
     and abs(length(a) - length(b)) <= 2 then
    if metaphone(a, 8) = metaphone(b, 8) then
      v_fonetica := 0.92;
    elsif metaphone(a, 8) like metaphone(b, 8) || '%'
       or metaphone(b, 8) like metaphone(a, 8) || '%' then
      v_fonetica := 0.78;
    end if;
  end if;

  -- 2b. Palabra corta que es prefijo de otra: 'kra' -> 'kraft'
  if length(a) >= 3 and b like a || '%' then
    v_fonetica := greatest(v_fonetica, 0.75);
  end if;

  -- 3. Distancia de edicion: letras en orden alterado.
  --    Solo con longitudes parecidas y pocos cambios reales.
  v_max  := greatest(length(a), length(b));
  v_dist := levenshtein(a, b);

  if abs(length(a) - length(b)) <= 2 and v_dist <= 3 then
    v_distancia := 1.0 - (v_dist::real / v_max);
  end if;

  v_resultado := greatest(v_trigrama, v_fonetica, v_distancia);

  -- Suelo: por debajo de este valor no es un error de
  -- escritura, es otra palabra.
  if v_resultado < 0.55 then
    return v_trigrama;
  end if;

  return v_resultado;
end;
$$;


-- ============================================================
-- VERIFICACION
-- ============================================================
select
  round(public.parecido_palabra('craf','kraft')::numeric, 2)          as craf,
  round(public.parecido_palabra('carft','kraft')::numeric, 2)         as carft,
  round(public.parecido_palabra('kra','kraft')::numeric, 2)           as kra,
  round(public.parecido_palabra('balbula','valvula')::numeric, 2)     as balbula,
  round(public.parecido_palabra('sinta','cinta')::numeric, 2)         as sinta,
  round(public.parecido_palabra('rodamiento','liner')::numeric, 2)    as falso_1,
  round(public.parecido_palabra('rodamiento','kraft')::numeric, 2)    as falso_2,
  round(public.similitud_palabras('rodamiento',
        'kraft liner l 2.2 m6')::numeric, 2)                          as falso_frase;
-- ============================================================

-- ============================================================
-- 014_sinonimos.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- Capa 4 de ADR-011: abreviaturas reales del inventario.
-- No se inventaron; se descubrieron recorriendo el vocabulario
-- con descubrir_variantes() (ver 020_jerga.sql).
--
-- ⚠️ ARCHIVO ACTUALIZADO 24-08-2026. La version anterior
-- versionada estaba incompleta.
--
-- Diccionario actual: 49+ equivalencias confirmadas
-- (torn=tornillo, rod=rodamiento, vva=valvula, mang=manguera,
-- bba=bomba, bcc=bristol con cabeza...). Solo entran las de
-- ambito 'global_validado': lo observado no se convierte solo
-- en regla (RN-025).
-- ============================================================


-- ------------------------------------------------------------
-- expandir_sinonimos()
--
-- EXPANSION BIDIRECCIONAL: quien escribe "vva" debe encontrar
-- "valvula", y quien escribe "valvula" debe encontrar las
-- filas que dicen "vva". De ahi los dos union: uno busca por
-- termino y otro por equivalente.
--
-- Las palabras originales se conservan siempre: expandir anade
-- posibilidades, nunca sustituye lo que el ingeniero escribio
-- (RN-002).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.expandir_sinonimos(p_consulta text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path TO 'public', 'extensions'
AS $function$
  with palabras as (
    select unnest(string_to_array(public.normalizar_texto(p_consulta), ' ')) as p
  ),
  expandido as (
    select p as termino from palabras
    union
    select s.equivalente
      from palabras pa
      join public.sinonimos s
        on public.normalizar_texto(s.termino) = pa.p
     where s.ambito = 'global_validado'
    union
    select public.normalizar_texto(s.termino)
      from palabras pa
      join public.sinonimos s
        on public.normalizar_texto(s.equivalente) = pa.p
     where s.ambito = 'global_validado'
  )
  select string_agg(termino, ' ')
  from expandido
  where termino is not null and termino <> '';
$function$;


-- ------------------------------------------------------------
-- expandir_consulta()
-- Encadena las dos capas y es lo que llama buscar_materiales.
--
-- EL ORDEN IMPORTA (error 18 del historial): primero los
-- sinonimos, la jerga AL FINAL.
--
-- Aplicar la jerga antes partia las medidas: expandir_sinonimos
-- trocea el texto en palabras, y de "4 1/2" quedaban "4" y
-- "1/2" sueltos, con lo que la equivalencia dejaba de servir
-- justo para el caso que la motivo (disco pulidora pequeno).
--
-- Aqui la jerga se anade entera al final, sin pasar por el
-- troceado.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.expandir_consulta(p_consulta text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path TO 'public', 'extensions'
AS $function$
  with base as (
    select coalesce(
      public.expandir_sinonimos(p_consulta),
      public.normalizar_texto(p_consulta)
    ) as texto
  ),
  jerga as (
    select string_agg(distinct j.equivale_a, ' ') as equivalencias
    from public.jerga_planta j
    where j.estado = 'validado'
      and public.normalizar_texto(p_consulta)
          ~ ('(^|\s)' || j.termino || '($|\s)')
      and exists (
        select 1
        from unnest(string_to_array(j.ambito, ' ')) as palabra
        where public.normalizar_texto(p_consulta) like '%' || palabra || '%'
      )
  )
  select trim(
    (select texto from base) || ' ' ||
    coalesce((select equivalencias from jerga), '')
  );
$function$;

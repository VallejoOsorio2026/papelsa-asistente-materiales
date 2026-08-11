-- ============================================================
-- 003_normalizacion.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- Orden de ejecucion: 3 de 5
-- ============================================================
-- Genera la representacion de busqueda sin alterar el texto
-- original de SAP (RN-011).
--
-- La misma funcion se aplica a los dos lados de la comparacion:
-- al texto del inventario cuando se carga, y a la consulta que
-- escribe el ingeniero. Si se limpiaran de forma distinta,
-- nunca coincidirian.
--
-- Ejemplo:
--   Original SAP : "RODAMIENTO RIGIDO/BOLAS  6205-2RS   SKF"
--   Normalizado  : "rodamiento rigido/bolas 6205 2rs skf"
-- ============================================================

create or replace function public.normalizar_texto(p_texto text)
returns text
language sql
immutable
set search_path = public, extensions
as $$
  select nullif(
    trim(
      regexp_replace(
        regexp_replace(
          lower(extensions.unaccent(coalesce(p_texto, ''))),
          '[^a-z0-9/.]', ' ', 'g'      -- conserva digitos, barra y punto
        ),
        '\s+', ' ', 'g'                -- colapsa espacios repetidos
      )
    ),
  '');
$$;

comment on function public.normalizar_texto is
  'RN-011: genera representacion de busqueda sin alterar el texto SAP original.';

-- ------------------------------------------------------------
-- Decisiones de diseno
-- ------------------------------------------------------------
-- La barra "/" se conserva: en planta 1/2 y 3/4 son medidas,
-- no ruido. Eliminarla convertiria "media pulgada" en "12".
--
-- El guion se convierte en espacio: 6205-2RS pasa a "6205 2rs",
-- de modo que quien escriba "6205 2rs" tambien pueda coincidir.
--
-- El punto se conserva por abreviaciones tipo "pulg.".
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- Verificacion
-- Esperado:
--   caso_1 -> rodamiento rigido/bolas 6205 2rs skf
--   caso_2 -> valvula 1/2 bronce
--   caso_3 -> llave mixta 3/4 pulg.
-- ------------------------------------------------------------
select
  public.normalizar_texto('RODAMIENTO RÍGIDO/BOLAS  6205-2RS   SKF') as caso_1,
  public.normalizar_texto('VÁLVULA 1/2" BRONCE')                     as caso_2,
  public.normalizar_texto('LLAVE MIXTA 3/4 PULG.')                   as caso_3;

-- ============================================================
-- 003_normalizacion.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- RN-011: los datos SAP son INMUTABLES. La normalizacion vive
-- en columnas auxiliares; el texto original nunca se toca.
-- Garantia estructural: no existe politica de UPDATE sobre
-- inventario_materiales, ni siquiera el admin puede editarlos.
--
-- ⚠️ ARCHIVO ACTUALIZADO 24-08-2026 con la correccion del
-- punto final. La version anterior versionada estaba desfasada
-- respecto a lo que corre en produccion.
--
-- EL PUNTO FINAL (error 16 del historial): en el inventario
-- real "rod" y "rod." eran palabras distintas — 1.247 filas
-- frente a 1.171 — y lo mismo "mang" (277) contra "mang."
-- (922). Buscar una nunca encontraba las otras.
--
-- La solucion NO es borrar todos los puntos: el punto
-- intermedio es significativo en decimales (0.015) y en
-- referencias (90.3858.00). Solo se elimina el punto al FINAL
-- de palabra, que es abreviatura.
-- ============================================================

CREATE OR REPLACE FUNCTION public.normalizar_texto(p_texto text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public', 'extensions'
AS $function$
  select nullif(
    trim(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            regexp_replace(
              lower(extensions.unaccent(coalesce(p_texto, ''))),
              '[^a-z0-9/.]', ' ', 'g'    -- conserva digitos, barra y punto
            ),
            '\.+(\s|$)', '\1', 'g'       -- punto al final de palabra
          ),
          '\s+', ' ', 'g'                -- colapsa espacios repetidos
        ),
        '^\.|\.$', '', 'g'               -- punto suelto al inicio o final
      )
    ),
  '');
$function$;

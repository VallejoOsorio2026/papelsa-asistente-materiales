# Guiones de base de datos

Copia versionada de lo que corre en Supabase. Estos archivos
**no** son ejecutados por la aplicación: existen para poder
reconstruir la base si el proyecto de Supabase se perdiera.

Editar un archivo de esta carpeta no cambia nada en Supabase.
El sentido del flujo es siempre Supabase → GitHub.

## Orden de ejecución

La numeración **no** es el orden correcto. Hay dependencias
que la contradicen:

| Nº | Archivo | Depende de |
|----|---------|------------|
| 001 | extensiones | pg_trgm, unaccent, fuzzystrmatch, pg_cron |
| 002 | schema | tablas |
| 003 | normalizacion | — |
| 011 | clave_ubicacion | **antes del 008** |
| 016 | materiales_baja | — |
| 008 | importacion | 003, 011 |
| 004 | indexes | 002 |
| 005 | rls | 002 |
| 006 | search | 003 |
| 020 | jerga | 002 |
| 014 | sinonimos | 020 |
| 012 | rendimiento | 006, 014, 020 |
| 013 | agrupacion | 012, 016 |
| 007 | mantenimiento | — |
| 009 | fonetica | — |
| 015 | busquedas_fallidas | — |
| 017 | inactividad | — |
| 018 | recuperar_salida | — |
| 019 | metricas | ⚠️ ejecutar también sus GRANT/REVOKE |
| 021 | feedback_motivo | — |
| 022 | ver_mas | 015 |
| 023 | roles_solicitantes | — |
| 024 | solicitudes_materiales | 023 |
| 025 | correo | 024 |
| 026 | area_almacen | 023 |

## Advertencias

**019_metricas.sql** — los REVOKE del final son obligatorios.
En PostgreSQL toda función nueva concede EXECUTE a PUBLIC por
defecto: volver a crearla sin revocar reabre el fallo de
seguridad que tuvo esa función.

**Cambiar la firma de una función** — al modificar parámetros o
tipo de retorno, `create or replace` no sustituye: crea otra
distinta con el mismo nombre. Hay que hacer `drop function` con
la firma exacta antes.

**004_indexes.sql** está en la raíz del repositorio, no aquí.

## Qué no versionamos

La Edge Function `enviar-correo` vive en Supabase. Su código
está en el histórico del proyecto, no en esta carpeta.

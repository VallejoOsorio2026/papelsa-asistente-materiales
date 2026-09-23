# Guiones de base de datos

Copia versionada de lo que corre en Supabase. Estos archivos
**no** son ejecutados por la aplicación: existen para poder
reconstruir la base si el proyecto de Supabase se perdiera.

Editar un archivo de esta carpeta no cambia nada en Supabase.
El sentido del flujo es siempre Supabase → GitHub.

## Orden de ejecución

La numeración **no** es el orden correcto. Hay dependencias
que la contradicen. **El orden autoritativo es esta tabla**, de
arriba abajo; `tests/m1b_equivalencia.sh` la lee tal cual para
reconstruir la base en local.

Una función `LANGUAGE sql` valida su cuerpo al crearse: todo lo
que nombra tiene que existir antes. Las `plpgsql` no: resuelven
al ejecutarse. Casi todas las filas de «Depende de» salen de esa
diferencia.

| Nº | Archivo | Depende de |
|----|---------|------------|
| 001 | extensiones | pg_trgm, unaccent, fuzzystrmatch, pg_cron |
| 002 | schema | tablas |
| 033 | perfiles_destinatarios | 002 · **antes del 023 y del 034** |
| 003 | normalizacion | — |
| 011 | clave_ubicacion | **antes del 008** |
| 016 | materiales_baja | ⚠️ ver nota |
| 008 | importacion | 003, 011 |
| 004 | indexes | 002 |
| 005 | rls | 002 |
| 006 | search | 003 |
| 007 | mantenimiento | 002 · **antes del 020** |
| 009 | fonetica | **antes del 020** |
| 030 | material_baja | **antes del 013** |
| 031 | jerga_planta | 002, 005 · **antes del 014 y del 020** |
| 020 | jerga | 002, 007, 009, 031 |
| 014 | sinonimos | 020, 031 |
| 012 | rendimiento | 006, 014, 020 |
| 013 | agrupacion | 012, 030 |
| 032 | busquedas_sin_resultado | 002, 005 · **antes del 015, 019 y 022** |
| 015 | busquedas_fallidas | 032 |
| 017 | inactividad | ⚠️ el archivo no existe; ver nota |
| 018 | recuperar_salida | — |
| 019 | metricas | 032 · ⚠️ ejecutar también sus GRANT/REVOKE |
| 021 | feedback_motivo | — |
| 022 | ver_mas | 015, 032 |
| 023 | roles_solicitantes | 033 |
| 034 | solicitudes_materiales | 002, 005, 033 · **antes del 024** |
| 024 | solicitudes_materiales | 023, 034 |
| 036 | solicitud_materiales_vivo | **después del 024** |
| 025 | correo | 024 |
| 026 | area_almacen | 023 · ⚠️ el archivo no existe |
| 035 | funciones_consulta | 002, 005, 007, 012, 013, 021, 030 |
| 037 | contrato_elsa_v1 | 002, 005, 007, 030 · **el último** |

Los archivos 030 a 036 son del bloque M1-B: objetos que ya
existían en Supabase sin copia aquí, recuperados por
introspección de solo lectura el 2026-09-22. Se numeraron
después del último archivo existente, sin renumerar nada; su
posición real es la de esta tabla.

**037 es de M1-C y no pertenece a esa recuperación.** No
reproduce nada que ya existiera: crea la fachada contractual
Materiales–ELSA V1, que es superficie nueva. Va al final porque
depende de objetos de M1-B —`es_material_baja` del 030— y de la
identidad del 005.

**024 y 036.** El 024 deja la orden de trabajo en 7 dígitos.
Producción pasó después a 8 (restricción y función). El 036
registra ese cambio sin reescribir el 024. El comentario de la
columna dice 7 también en producción: PENDIENTE-020.

**016 y 017.** El 016 se llama `materiales_baja`, pero contiene
las funciones de inactividad (`cerrar_solicitudes_inactivas`,
`iniciar_sesion_app`), que por nombre corresponderían al 017,
ausente. `es_material_baja()` está ahora en el 030. No se
renombró nada: no hay forma segura de saber qué contenía cada
archivo originalmente.

**Reconstrucción completa todavía imposible.** Al reproducir la
tabla en local aparecen defectos anteriores a M1-B (PENDIENTE-022):
el 002 tiene una cadena sin cerrar que impide crear las tablas
de operación, el 025 tiene un fragmento suelto detrás de
`$function$;`, y 027, 028 y 029 no figuran en la tabla (el
027 necesita además pg_cron).

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

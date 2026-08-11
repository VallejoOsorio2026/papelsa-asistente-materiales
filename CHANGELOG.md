# Historial de versiones

Todas las modificaciones relevantes del proyecto quedan registradas aquí.

Formato de versión: `vMAYOR.MENOR.PARCHE`

- **MAYOR** — cambio que rompe compatibilidad o redefine el alcance
- **MENOR** — funcionalidad nueva compatible con lo anterior
- **PARCHE** — corrección de errores o ajustes menores

---

## [No publicado]

### En construcción
- Fase 4 — Usuarios y control de registro

---

## [v0.2.0] — 2026-08-11

### Añadido
- Estructura documental del repositorio: reglas de negocio, pendientes,
  seguridad y plantilla de reporte de errores
- Proyecto de base de datos creado y operativo
- Extensiones `pg_trgm` (similitud de texto) y `unaccent` (sin tildes)
- Esquema completo: **15 tablas** en cuatro zonas — datos SAP, operación,
  aprendizaje y gobierno
- **16 índices**, incluido el índice difuso sobre texto normalizado
- Row Level Security activo en las 15 tablas, con políticas por rol
- Función `normalizar_texto()` para la representación de búsqueda
- Funciones de mantenimiento: `ping()`, `cerrar_solicitudes_inactivas()`
  y `version_datos_activa()`
- Cinco parámetros iniciales en la tabla de configuración
- Guiones SQL versionados en `sql/`, reproducibles desde cero

### Decisiones adoptadas
- **ADR-006** — El inventario no admite modificación. Al no existir política
  de actualización sobre `inventario_materiales`, ni el administrador puede
  editar una fila de SAP. Corregir un dato exige una nueva carga completa.
  Convierte RN-011 en una garantía estructural, no en una norma de conducta
- **ADR-007** — Los perfiles no se eliminan, se desactivan. Así el historial
  de solicitudes nunca queda huérfano
- **ADR-008** — El motor de búsqueda se pospone a la Fase 7, después de
  observar datos reales. Construirlo antes obligaría a reescribirlo. El
  archivo `006_search.sql` queda reservado

### Pendientes
- **PENDIENTE-003 — CERRADO.** Autorización institucional obtenida para
  alojar el catálogo de materiales en el servicio en la nube
- **PENDIENTE-001** — Abierto. Semántica de `XCentro`. Se resuelve en Fase 5
- **PENDIENTE-002** — Abierto. Almacén físico del Corrugador, sin validar

### Notas de infraestructura
- Región del proyecto: `us-west-2` (Oregón). Añade latencia frente a la costa
  este, sin impacto perceptible en consultas puntuales. No se rehace
- No se ha generado clave secreta de servidor y no está prevista
- Fase 1 — Estructura del repositorio y documentación base

---

## [v0.1.0] — 2026-08-11

### Añadido
- Creación del repositorio del proyecto
- README con alcance, problema que resuelve, roles y aviso de repositorio público
- `.gitignore` con bloqueo de archivos de datos SAP y credenciales
- Este historial de versiones

### Decisiones adoptadas
- **ADR-001** — Arquitectura GitHub Pages + Supabase para el piloto
- **ADR-002** — Se conservan como máximo dos versiones completas del inventario
  (activa y anterior), por el límite de 500 MB del plan gratuito. De cargas más
  antiguas se conserva solo el registro de auditoría
- **ADR-003** — Nivel de confianza 5 exige coincidencia exacta **y** candidato único.
  Si hay empate técnico entre varios materiales, el nivel baja a 4 y se muestran
  las alternativas
- **ADR-004** — El piloto usa datos reales desde la Fase 5, con una muestra
  controlada de 300 a 500 filas. Ninguna fila real entra a la base de datos antes
  de verificar el aislamiento por políticas de seguridad. La carga completa se
  mantiene en la Fase 12

### Restricciones confirmadas
- Repositorio público: GitHub Pages solo está disponible en repositorios públicos
  con el plan gratuito
- La página publicada será pública en cualquier caso; la seguridad de los datos
  recae íntegramente en autenticación y políticas de seguridad a nivel de fila
- El proyecto gratuito de la base de datos se pausa tras 7 días de inactividad;
  se mitigará con una tarea programada de mantenimiento
- No se generará clave secreta de servidor: las operaciones administrativas se
  resuelven con el usuario administrador autenticado

### Pendientes abiertos
- **PENDIENTE-001** — Semántica exacta de la columna `XCentro` y de la disponibilidad
  en centros distintos al de la fila. Se resuelve al revisar datos reales (Fase 5)
- **PENDIENTE-002** — El almacén físico del Corrugador se asume provisionalmente;
  dato **no validado**
- **PENDIENTE-003** — Autorización institucional para alojar el inventario de
  materiales en un servicio en la nube externo

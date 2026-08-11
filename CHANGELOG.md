# Historial de versiones

Todas las modificaciones relevantes del proyecto quedan registradas aquí.

Formato de versión: `vMAYOR.MENOR.PARCHE`

- **MAYOR** — cambio que rompe compatibilidad o redefine el alcance
- **MENOR** — funcionalidad nueva compatible con lo anterior
- **PARCHE** — corrección de errores o ajustes menores

---

## [No publicado]

### En construcción
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

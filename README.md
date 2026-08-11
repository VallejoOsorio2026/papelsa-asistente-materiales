# Asistente Inteligente de Materiales SAP — PAPELSA

Asistente de consulta de materiales, herramientas y repuestos registrados en SAP,
construido para el área de **Molino** de PAPELSA.

**Estado:** piloto en construcción · **Versión:** v0.1.0

---

## ⚠️ AVISO SOBRE ESTE REPOSITORIO

Este repositorio es **público**. Contiene únicamente código fuente y documentación.

**Nunca debe contener:**

- Archivos Excel o CSV exportados de SAP
- Inventario de materiales, precios, consumos o valores
- Contraseñas, claves secretas, tokens o credenciales de cualquier tipo
- Datos de usuarios

Los datos operativos residen exclusivamente en la base de datos del proyecto,
protegidos por autenticación y políticas de seguridad a nivel de fila.
La visibilidad de este repositorio **no** es un mecanismo de seguridad
y nunca debe usarse como tal.

© PAPELSA. Todos los derechos reservados. Uso interno.

---

## Problema que resuelve

Cuando un mecánico, operario o contratista necesita un material, lo solicita a un
ingeniero de planta, que es quien tiene acceso completo a SAP. El ingeniero debe
entrar a SAP, buscar el material, identificar código y disponibilidad, y responder.
Cada búsqueda toma entre 4 y 5 minutos.

La planta opera 24/7, pero los ingenieros trabajan aproximadamente de 7:30 a 15:30.
Fuera de ese horario, atender una solicitud obliga a interrumpir el descanso,
encender el equipo, conectarse y abrir SAP.

Este asistente busca reducir esa dependencia.

## Qué hace y qué no hace

El asistente **interpreta → busca → organiza → sugiere → presenta**.

El ingeniero **decide**.

El asistente no reemplaza el criterio del ingeniero, no crea órdenes en SAP y no
sustituye a SAP como fuente de verdad.

## Usuario del piloto

El usuario directo es exclusivamente el **ingeniero de planta**, no el solicitante final.

| Rol | Puede |
|---|---|
| `admin` | Actualizar inventario, gestionar usuarios y reglas, revisar errores, feedback y métricas |
| `ingeniero` | Consultar, resolver aclaraciones, elegir alternativas, obtener la salida para SAP, ver su historial, responder la encuesta |

## Arquitectura

    GitHub  →  GitHub Pages (interfaz web)
                     ↓
              Supabase Auth (correo + contraseña, sin registro público)
                     ↓
              Row Level Security  ← aquí vive la seguridad
                     ↓
              PostgreSQL (inventario, solicitudes, trazabilidad, aprendizaje)
                     ↓
              Motor de búsqueda: exacta → referencia → normalizada → difusa → sinónimos

Detalle completo en [`docs/arquitectura.md`](docs/arquitectura.md).

## Estructura del repositorio

| Carpeta | Contenido |
|---|---|
| `css/` | Hojas de estilo |
| `js/` | Código de la aplicación (interfaz, búsqueda, importador) |
| `sql/` | Guiones de base de datos, numerados por orden de ejecución |
| `docs/` | Arquitectura, modelo de datos, reglas de negocio, decisiones y pendientes |
| `data/` | Únicamente documentación. **Prohibido cualquier dato real de SAP** |
| `.github/` | Tareas automáticas y plantillas de reporte de errores |

## Fuente de los datos

El inventario proviene de una exportación de SAP obtenida mediante un guion externo
(aproximadamente 48 minutos de ejecución). No existe conexión directa con SAP.
Esta es una restricción conocida del piloto y está registrada como oportunidad de mejora.

Cada carga genera una versión de datos. La versión anterior permanece activa hasta
que la nueva se valida por completo. Si una carga falla, el sistema sigue operando
con la última versión válida.

## Severidad de errores

| Nivel | Definición |
|---|---|
| Menor | Problema visual o de redacción, sin impacto material |
| Medio | Ranking o presentación mejorable |
| Alto | No encontrar un material que sí existe |
| **Crítico** | Presentar un material incorrecto como coincidencia exacta (Nivel 5) |

Ningún error crítico abierto puede quedar sin revisar antes de liberar una versión.

## Documentación

- [`CHANGELOG.md`](CHANGELOG.md) — historial de versiones
- [`docs/arquitectura.md`](docs/arquitectura.md)
- [`docs/modelo-datos.md`](docs/modelo-datos.md)
- [`docs/reglas-negocio.md`](docs/reglas-negocio.md)
- [`docs/seguridad.md`](docs/seguridad.md)
- [`docs/pendientes.md`](docs/pendientes.md)
- [`docs/decisiones/`](docs/decisiones/) — decisiones de arquitectura (ADR)

## Responsable

**Juan Pablo Vallejo** — Administrador del piloto, responsable funcional y técnico.

# Pendientes abiertos

Ninguno se cierra sin confirmación explícita del responsable del proyecto.

| ID | Descripción | Estado | Se resuelve en |
|---|---|---|---|
| PENDIENTE-001 | Semántica exacta de la columna `XCentro` y cómo se representa la disponibilidad en centros distintos al de la fila. No se infiere: se resuelve observando datos reales. | Abierto | Fase 5 |
| PENDIENTE-002 | Almacén físico del Corrugador. La muestra de 500 filas respalda el valor asumido: 124 filas cruzan ese centro con ese almacén, sin excepciones. Falta confirmación formal antes de darlo por validado. | Abierto · con evidencia | Confirmación del responsable |
| PENDIENTE-003 | Autorización institucional para alojar el catálogo de materiales en un servicio en la nube externo. | ✅ Cerrado | Cerrado el 2026-08-11 |
| PENDIENTE-004 | Formato numérico mixto en el archivo de origen. Los valores llegan como texto: unos con punto de miles y coma decimal (`3.514.207,24`), otros como entero limpio. Ocho casos son ambiguos porque el punto puede ser separador de miles o decimal (`12.192`, `8.2`). No se interpretan por conjetura: se cargan marcados para revisión y la aplicación advierte al mostrarlos. | Abierto | Consulta con el responsable de SAP |
| PENDIENTE-005 | Códigos de almacén no documentados en la definición inicial: `P992`, `P122`, `P123`, `P212`, `P213`, `PST`, `PBT`, `PPT`, `PCC`. Poco frecuentes (entre 1 y 11 filas cada uno). Sin impacto en la búsqueda; afectan solo a la clasificación por ubicación. | Abierto | Consulta con el responsable de SAP |

## Cerrados

| ID | Descripción | Cerrado el | Resolución |
|---|---|---|---|
| PENDIENTE-003 | Autorización para alojar el catálogo en la nube | 2026-08-11 | Autorización obtenida. El alcance quedó reducido a catálogo técnico con existencias y ubicación, sin costos ni consumos (ADR-005) |

## Mejoras futuras identificadas

No implementar si ponen en riesgo el piloto.

1. Integración directa con SAP
2. Eliminación del proceso de extracción de ~48 minutos
3. Información de materiales reservados o comprometidos, y su liberación
4. Autenticación corporativa Microsoft
5. Integración conversacional con Teams
6. Mayor automatización del proceso en SAP
7. Búsqueda semántica
8. Modelo de lenguaje optimizado
9. Nuevos canales de consulta
10. Administración corporativa de usuarios y roles
11. Reincorporación de columnas de costo y consumo (excluidas por ADR-005)
12. Recuperación de la columna de fecha de creación como criterio de desempate

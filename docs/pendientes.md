# Pendientes abiertos

Ninguno se cierra sin confirmación explícita del responsable del proyecto.

| ID | Descripción | Estado | Se resuelve en |
|---|---|---|---|
| PENDIENTE-002 | Almacén físico del Corrugador. La muestra de 500 filas respalda el valor asumido: 124 filas cruzan ese centro con ese almacén, sin excepciones. Falta confirmación formal antes de darlo por validado. | Abierto · con evidencia | Confirmación del responsable |
| PENDIENTE-005 | Códigos de almacén no documentados: `P992`, `P122`, `P123`, `P212`, `P213`, `PST`, `PBT`, `PPT`, `PCC`. Poco frecuentes. Sin impacto en la búsqueda: RN-032 garantiza que ningún material se oculte por esta causa. | Abierto | Información pendiente del responsable de SAP |
| PENDIENTE-006 | Variantes fonéticas de palabras extranjeras. Las consultas `craf` y `carft` devuelven ruido en las primeras posiciones (curva, cuchilla, carriage). El material correcto aparece, pero no encabeza. Causa probable: el algoritmo fonético colapsa consonantes distintas. La consulta `kra` sí funciona correctamente. | Abierto | Fase 14, capa de sinónimos |
| PENDIENTE-007 | Rendimiento de la comparación palabra a palabra. Recorre todas las filas del inventario. Con 500 filas responde bien; con 65.884 debe medirse y probablemente requiera un filtro previo por índice trigram. | Abierto | Fase 12, carga completa |

## Cerrados

| ID | Descripción | Cerrado el | Resolución |
|---|---|---|---|
| PENDIENTE-001 | Semántica de la columna `XCentro` | 2026-08-12 | **No aplica.** Se confirmó que no es relevante para el propósito del asistente. La columna se carga por fidelidad al origen, pero el motor la ignora (ADR-009) |
| PENDIENTE-003 | Autorización para alojar el catálogo en la nube | 2026-08-11 | Autorización obtenida. El alcance quedó reducido a catálogo técnico con existencias y ubicación, sin costos ni consumos (ADR-005) |
| PENDIENTE-004 | Formato numérico mixto en el archivo de origen | 2026-08-12 | Resuelto mediante la unidad de medida. Si es de conteo, el valor se redondea a entero; si es continua, se conservan los decimales (RN-031). Los valores ambiguos desaparecen porque corresponden a artículos contables |

## Incidencias conocidas

Registradas, sin acción prevista por ahora.

| Descripción | Severidad |
|---|---|
| Algunos códigos antiguos fueron convertidos en fecha por la hoja de cálculo antes de la exportación. Son irrecuperables. El filtro detecta el formato con hora; si la hoja exporta la fecha de otro modo, el valor pasa. Afecta solo a la búsqueda por código antiguo | Menor |
| Al recargar, la pantalla de acceso aparece un instante antes de restaurarse la sesión | Menor |
| La conexión de botones en el arranque no comprueba la existencia del elemento de forma uniforme | Menor |

## Mejoras futuras identificadas

No implementar si ponen en riesgo el piloto.

1. Integración directa con SAP
2. Eliminación del proceso de extracción de ~48 minutos
3. Información de materiales reservados y su liberación
4. Autenticación corporativa Microsoft
5. Integración conversacional con Teams
6. Mayor automatización del proceso en SAP
7. Búsqueda semántica
8. Modelo de lenguaje optimizado
9. Nuevos canales de consulta
10. Administración corporativa de usuarios y roles
11. Reincorporación de columnas de costo y consumo (excluidas por ADR-005)
12. Recuperación de la columna de fecha de creación como criterio de desempate
13. Agente evaluador automático: un agente que use la aplicación publicada,
    ejecute el banco de pruebas y califique los resultados (nivel de confianza
    esperado frente al obtenido, posición del material correcto). Permitiría
    medir cada versión sin pruebas manuales y detectar regresiones antes de
    liberar
14. Capa de sinónimos validados y aprendizaje sugerido a partir del uso, para
    cubrir jerga local y variantes que ningún algoritmo puede deducir solo

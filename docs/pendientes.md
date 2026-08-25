# Pendientes abiertos

Ninguno se cierra sin confirmación explícita del responsable del proyecto.

| ID | Descripción | Estado | Se resuelve en |
|---|---|---|---|
| PENDIENTE-002 | Almacén físico del Corrugador. La muestra de 500 filas respalda el valor asumido: 124 filas cruzan ese centro con ese almacén, sin excepciones. Falta confirmación formal antes de darlo por validado. | Abierto · con evidencia | Confirmación del responsable |
| PENDIENTE-006 | Variantes fonéticas de palabras extranjeras. Las consultas `craf` y `carft` devuelven ruido en las primeras posiciones (curva, cuchilla, carriage). El material correcto aparece, pero no encabeza. Causa probable: el algoritmo fonético colapsa consonantes distintas. La consulta `kra` sí funciona correctamente. | Abierto | Fase 14, capa de sinónimos |
| PENDIENTE-008 | Validación del pegado en SAP real. El bloque de ocho columnas separadas por tabulador (sin la columna TE, corregido el 2026-08-24) se verificó en Excel y las columnas caen correctamente. Falta comprobarlo en la pantalla de SAP. | Abierto | Cuando haya acceso a SAP |
| PENDIENTE-009 | El sustantivo principal no pesa más que los calificativos. En «disco pulidora pequeño», una guarda para pulidora de 4-1/2" encabeza sobre los discos de 4-1/2", porque contiene las mismas palabras. Idea a evaluar: dar más peso cuando la palabra coincide al inicio de la descripción del material (`DISCO PULIR...` frente a `GUARDA PARA PULIDORA...`), en lugar de intentar identificar cuál es el sustantivo. **No se implementa sin medición**: el ajuste podría mejorar este caso y empeorar otros. | Abierto | Banco de pruebas |
| PENDIENTE-010 | `correos_pendientes()` solo recoge los avisos en estado `pendiente`, pero cuando el servicio de correo no está configurado el estado queda en `sin_servicio`. Consecuencia: todas las solicitudes registradas durante el piloto quedarían fuera de la cola de reintento y no se enviarían al configurar el dominio. Solo afectaría a las ya existentes; las nuevas irían bien. | Abierto | Al configurar el correo real |
| PENDIENTE-011 | `marcar_solicitud()` es la única función `SECURITY DEFINER` del proyecto sin `es_usuario_activo()` al inicio. Se ejecuta con permisos elevados y depende por completo de las políticas de seguridad de la tabla. Severidad media. | Abierto | Próxima revisión de seguridad |
| PENDIENTE-012 | Confirmar con el autorizante el alcance ampliado. PENDIENTE-003 se autorizó para un piloto con ingenieros. Contratistas externos con acceso al catálogo de repuestos y existencias es un alcance distinto y conviene ratificarlo antes de dar acceso a personal externo. | Abierto | Confirmación del responsable |
| PENDIENTE-013 | Verificar la equivalencia «aisi = varilla roscada» antes de integrarla al diccionario. AISI es un instituto de normas de acero (AISI 304, AISI 1045), no un tipo de pieza. Integrarla sin comprobar contaminaría la búsqueda de aceros. | Abierto | Confirmación del responsable |
## Cerrados

| ID | Descripción | Cerrado el | Resolución |
|---|---|---|---|
| PENDIENTE-001 | Semántica de la columna `XCentro` | 2026-08-12 | **No aplica.** Se confirmó que no es relevante para el propósito del asistente. La columna se carga por fidelidad al origen, pero el motor la ignora (ADR-009) |
| PENDIENTE-003 | Autorización para alojar el catálogo en la nube | 2026-08-11 | Autorización obtenida. El alcance quedó reducido a catálogo técnico con existencias y ubicación, sin costos ni consumos (ADR-005) |
| PENDIENTE-004 | Formato numérico mixto en el archivo de origen | 2026-08-12 | Resuelto mediante la unidad de medida. Si es de conteo, el valor se redondea a entero; si es continua, se conservan los decimales (RN-031). Los valores ambiguos desaparecen porque corresponden a artículos contables |
| PENDIENTE-005 | Códigos de almacén no documentados | 2026-08-12 | **No eran excepciones.** `P122`, `P123`, `P212`, `P213` son almacenes normales de cada centro. Apenas aparecían en la muestra de 500 filas |
| PENDIENTE-007 | Rendimiento con el inventario completo | 2026-08-12 | Resuelto con un prefiltro por índice trigram antes de aplicar la comparación costosa. De 8.520 ms a 864 ms |

## Incidencias conocidas

Registradas, sin acción prevista por ahora.

| Descripción | Severidad |
|---|---|
| Algunos códigos antiguos fueron convertidos en fecha por la hoja de cálculo antes de la exportación. Son irrecuperables. El filtro detecta el formato con hora; si la hoja exporta la fecha de otro modo, el valor pasa. Afecta solo a la búsqueda por código antiguo | Menor |
| Al recargar, la pantalla de acceso aparece un instante antes de restaurarse la sesión | Menor |
| La conexión de botones en el arranque no comprueba la existencia del elemento de forma uniforme | Menor |
| `expandir_consulta()` repite internamente la lógica de `expandir_jerga()` en lugar de llamarla. Funciona, pero si se cambia una y no la otra divergen en silencio | Menor |
| `clasificar_ubicacion()` recibe el parámetro `p_almacen` y no lo usa: clasifica solo por centro. Corregirlo exige `DROP FUNCTION` por cambio de firma | Menor |
| `iniciar_sesion_app()` devuelve el perfil sin `area` ni `recibe_solicitudes`, así que la aplicación los pide en una segunda llamada. Contradice el propósito de ADR-017 | Menor |
| El orden de ejecución de los guiones SQL no coincide con su numeración: `011_clave_ubicacion` debe ejecutarse antes que `008_importacion`. Documentado en `sql/README.md` | Menor |

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
15. Rediseño del frontend. Entre otros ajustes: hacer más notable la
    advertencia de material marcado para baja, hoy demasiado sutil
16. La coincidencia exacta por código debería ganar siempre. Al buscar
    un código, el prefiltro por similitud puede colar otros materiales
    por encima del exacto
17. Revisar el modelo de sesión si el sistema escala a terminales
    compartidos en planta. Hoy la sesión persiste por navegador y se
    comparte entre pestañas, decisión tomada para no añadir fricción al
    uso de madrugada. En un equipo compartido convendría sesión por
    pestaña o cierre automático por inactividad

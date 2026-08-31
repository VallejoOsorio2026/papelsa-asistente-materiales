# Pendientes abiertos

Ninguno se cierra sin confirmación explícita del responsable del proyecto.

| ID | Descripción | Estado | Se resuelve en |
|---|---|---|---|
| PENDIENTE-002 | Almacén físico del Corrugador. La muestra de 500 filas respalda el valor asumido: 124 filas cruzan ese centro con ese almacén, sin excepciones. Falta confirmación formal antes de darlo por validado. | Abierto · con evidencia | Confirmación del responsable |
| PENDIENTE-006 | Variantes fonéticas de palabras extranjeras. **Medido el 2026-08-26 con el banco de pruebas:** `carft` ya funciona y encabeza correctamente con Cartulina Kraft; se convirtió en caso de control. Solo falla `craf`, y es peor de lo documentado: no aparece ni entre los 20 primeros, encabeza un sello mecánico sin relación. Contraste útil: `kra` y `carft` aciertan en el puesto 1 con la misma raíz. Causa probable: el algoritmo fonético colapsa consonantes distintas. |
| PENDIENTE-008 | Validación del pegado en SAP real. El bloque de ocho columnas separadas por tabulador (sin la columna TE, corregido el 2026-08-24) se verificó en Excel y las columnas caen correctamente. Falta comprobarlo en la pantalla de SAP. | Abierto | Cuando haya acceso a SAP |
| PENDIENTE-009 | El sustantivo principal no pesa más que los calificativos. **Medido el 2026-08-26:** el disco correcto está en posición 2, no perdido. La guarda para pulidora le gana por poco porque contiene las mismas palabras. Menos grave de lo que se creía, pero sigue siendo un fallo: el ingeniero ve primero lo que no busca. Idea a evaluar: dar más peso cuando la palabra coincide al inicio de la descripción. **No se implementa sin medir todo el banco**: podría mejorar este caso y empeorar otros. | Abierto | Banco de pruebas |
| PENDIENTE-013 | Verificar la equivalencia «aisi = varilla roscada» antes de integrarla al diccionario. AISI es un instituto de normas de acero (AISI 304, AISI 1045), no un tipo de pieza. Integrarla sin comprobar contaminaría la búsqueda de aceros. | Abierto | Confirmación del responsable |
| PENDIENTE-015 | El dominio `elsa-ai.link` está registrado a título personal y es hoy una dependencia del sistema: si caduca, los avisos dejan de enviarse sin aviso previo. Anotar la fecha de renovación y decidir si el proyecto crece hacia un dominio institucional. | Abierto | Renovación anual |
| PENDIENTE-016 | La abreviatura `AC` se pierde por longitud. `extraer_palabras()` descarta lo de menos de tres letras, así que en «AC Rsc» la búsqueda efectiva es solo `rsc` y el material correcto cae al puesto 7. La expansión de sinónimos añade `acero`, que no coincide porque el inventario escribe `AC`. **No corregir bajando el mínimo a dos letras sin medir**: metería `de`, `mm`, `un` y decenas de fragmentos en todas las búsquedas del catálogo. Alternativa a evaluar: permitir palabras de dos letras solo si están en el diccionario de abreviaturas. | Abierto | Banco de pruebas |

## Cerrados

| ID | Descripción | Cerrado el | Resolución |
|---|---|---|---|
| PENDIENTE-001 | Semántica de la columna `XCentro` | 2026-08-12 | **No aplica.** Se confirmó que no es relevante para el propósito del asistente. La columna se carga por fidelidad al origen, pero el motor la ignora (ADR-009) |
| PENDIENTE-003 | Autorización para alojar el catálogo en la nube | 2026-08-11 | Autorización obtenida. El alcance quedó reducido a catálogo técnico con existencias y ubicación, sin costos ni consumos (ADR-005) |
| PENDIENTE-004 | Formato numérico mixto en el archivo de origen | 2026-08-12 | Resuelto mediante la unidad de medida. Si es de conteo, el valor se redondea a entero; si es continua, se conservan los decimales (RN-031). Los valores ambiguos desaparecen porque corresponden a artículos contables |
| PENDIENTE-005 | Códigos de almacén no documentados | 2026-08-12 | **No eran excepciones.** `P122`, `P123`, `P212`, `P213` son almacenes normales de cada centro. Apenas aparecían en la muestra de 500 filas |
| PENDIENTE-007 | Rendimiento con el inventario completo | 2026-08-12 | Resuelto con un prefiltro por índice trigram antes de aplicar la comparación costosa. De 8.520 ms a 864 ms |
| PENDIENTE-010 | La cola de reintento ignoraba el estado `sin_servicio` | 2026-08-26 | Resuelto. `correos_pendientes()` incluye ahora ambos estados. Se borraron además las solicitudes de prueba, para que no salieran todas de golpe al activar el correo |
| PENDIENTE-011 | `marcar_solicitud()` sin verificación de sesión | 2026-08-26 | Resuelto. Se añadió `es_usuario_activo()` al inicio, como en el resto de funciones `SECURITY DEFINER` |
| PENDIENTE-012 | Ratificar el alcance ampliado a contratistas | 2026-08-26 | Autorizado. Se confirmó el acceso de personal externo al catálogo técnico, en las mismas condiciones del piloto: solo lectura, sin costos ni consumos |
| PENDIENTE-014 | Paso a producción de las cuentas de solicitante | 2026-08-26 | Hecho. `Mecánicos Molino` y `FAISMON` pasaron al área `mantenimiento`. Verificado con envío controlado a los tres ingenieros, avisados previamente para que el remitente no cayera en spam |
| PENDIENTE-017 | Prefiltro de búsqueda (`LIMIT 600`) cortaba sin orden: con más de 600 candidatos, Postgres descartaba dos tercios al azar. | 2026-08-31 | Corregido: orden por conteo de coincidencias (refs, medidas, palabras). Validado: retenedor 110x142x15 → puesto 1 de 1.884; AC Rsc → puesto 42 de 4.231. Ambos sobreviven el corte; lo pendiente en cada uno es otro problema (vocabulario, PENDIENTE-016) |

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
| Las cuentas de solicitante son compartidas (`Mecánicos Molino`, `FAISMON`). Es deliberado: el personal de planta no tiene correo corporativo. La trazabilidad se sostiene porque el formulario exige el nombre completo en cada envío. Sin recuperación de contraseña: las direcciones no existen y el administrador debe restablecerlas | Menor |

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
16. ~~La coincidencia exacta por código debería ganar siempre.~~
    **Resuelto.** Medido el 2026-08-26: al buscar `5824421` el código
    exacto encabeza. Se conserva como caso de control en el banco
17. Revisar el modelo de sesión si el sistema escala a terminales
    compartidos en planta. Hoy la sesión persiste por navegador y se
    comparte entre pestañas, decisión tomada para no añadir fricción al
    uso de madrugada. En un equipo compartido convendría sesión por
    pestaña o cierre automático por inactividad
18. Vista previa por rol para el administrador: un selector que muestre qué
    paneles ve cada rol, sin cambiar de identidad. Útil para revisar la
    interfaz. **No sirve para auditar permisos**: la consulta seguiría
    haciéndose con credenciales de administrador. Para verificar que un rol
    no ve lo que no debe, hay que iniciar sesión con esa cuenta
19. Permitir que el solicitante elija el área de destino. Hoy la solicitud
    va siempre al área del perfil, así que un material eléctrico pedido por
    un mecánico llega a mantenimiento y se deriva a mano. Decisión tomada a
    conciencia: obliga menos al mecánico, que no debería clasificar el
    material antes de buscarlo

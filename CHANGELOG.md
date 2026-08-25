# Historial de versiones

Todas las modificaciones relevantes del proyecto quedan registradas aquí.

Formato de versión: `vMAYOR.MENOR.PARCHE`

- **MAYOR** — cambio que rompe compatibilidad o redefine el alcance
- **MENOR** — funcionalidad nueva compatible con lo anterior
- **PARCHE** — corrección de errores o ajustes menores

## [No publicado]

### En construcción
- Banco de pruebas y medición objetiva del motor
- Pantalla de administración de sinónimos sugeridos
- Servicio de correo real: pendiente de dominio propio
- Tarea programada de reintento de avisos con `pg_cron`

---

## [v1.1.0] — 2026-08-24

El alcance se amplió más rápido de lo previsto. El piloto había sido
concebido para ingenieros; la dirección decidió abrirlo a mecánicos y
contratistas, y se incorporó el área de almacén. El asistente deja de
ser una herramienta de consulta para convertirse también en un canal de
solicitud.

### Añadido

**Escalado a mecánicos, contratistas y almacén**
- Seis roles (`admin`, `ingeniero`, `mecanico`, `contratista`,
  `jefe_almacen`, `almacenista`) y dos áreas (`mantenimiento`, `almacen`)
- Envío de solicitudes de materiales: el mecánico busca, elige y envía al
  ingeniero, que sigue siendo quien decide y quien lleva la información a
  SAP (RN-024, RN-028)
- Validación de orden de trabajo de siete dígitos, en el navegador **y**
  en la base de datos
- El nombre se pide en cada solicitud aunque haya sesión iniciada: la
  cuenta puede compartirse entre varias personas y, sin ese campo, el
  registro diría «mecánico» en todas
- **Bandeja de solicitudes recibidas** para quienes tienen
  `recibe_solicitudes`, con copia del número de orden en un clic y marcado
  de atendida
- Generación de Excel en el navegador, sin librerías externas
- Edge Function `enviar-correo` desplegada, con el contenido del mensaje
  armado en la base de datos

**Motor de búsqueda**
- **Jerga de planta** atada a ámbito: «disco pulidora pequeño» encuentra
  los discos de 4 1/2". La equivalencia solo se aplica si el término y su
  ámbito aparecen juntos en la consulta
- Descubrimiento automático de variantes sobre el vocabulario real del
  inventario, para proponer abreviaturas al administrador
- **Ver más resultados** (5 → 10 → 15), con registro de cada ampliación

**Trazabilidad**
- Registro de **todas** las búsquedas, no solo las de confianza baja
- Aviso «¿No es esto lo que buscabas?» siempre disponible y plegado, con
  cinco motivos concretos derivados de fallos observados
- Panel de métricas del piloto restringido al administrador

### Reglas de negocio
- **RN-027 — CORREGIDA.** La salida para SAP tiene **ocho** columnas, no
  nueve. La columna `TE` aparece en la pantalla de SAP pero no admite valor
  al pegar: incluirla desplazaba todos los datos una posición a la derecha
- **RN-030 — NUEVA.** Disponible = libre utilización + consignación.
  El stock de proyectos se presenta aparte como comprometido: existe
  físicamente pero está asignado. No se oculta ni se suma. En una parada de
  madrugada, saber que un material existe aunque esté comprometido puede
  ser justo la información que se necesita
- **RN-031 — NUEVA.** Conversión numérica según unidad de medida
- **RN-032 — NUEVA.** Código de almacén desconocido se clasifica como «otra
  ubicación», nunca oculta el material

### Decisiones adoptadas
- **ADR-019** — Cada área tiene sus propios destinatarios. Una solicitud de
  mantenimiento no llega al almacén aunque su jefe tenga
  `recibe_solicitudes`. Añadir un departamento nuevo es un `INSERT`, no un
  rediseño
- **ADR-020** — Marcar una solicitud como atendida la retira de la bandeja
  de **todos** los destinatarios del área, no solo de quien pulsó. Si ya la
  atendió un ingeniero, el otro no debe volver a atenderla
- **ADR-021** — El contenido del correo se arma en la base de datos, no en
  la Edge Function: corregir el texto no exige volver a desplegar nada
- **ADR-022** — El aviso por correo se envía en el momento, no esperando a
  una tarea programada. Un mecánico de madrugada no puede esperar a que una
  cola se revise. Si falla, la solicitud queda encolada y se reintenta

### Corregido
- **Fracciones mixtas.** De «4 1/2» solo sobrevivía «1/2», porque el «4» se
  descartaba por corto. Un disco de 4 1/2" y uno de 1/2" no tienen relación.
  Ahora se detectan sobre el texto completo, antes de partirlo en palabras
- **Orden de expansión.** La jerga se aplicaba antes que los sinónimos y
  partía las medidas, con lo que dejaba de servir justo para el caso que la
  motivó. Ahora va al final
- **Fallo de seguridad en las métricas (grave).** El panel era consultable
  por cualquier usuario autenticado; ocultarlo en pantalla no protegía nada.
  Y el primer `REVOKE` no bastó: en PostgreSQL toda función nueva concede
  ejecución a `PUBLIC` por defecto. La protección real es la verificación de
  rol dentro de la propia función
- **Lectura de perfil.** No filtraba por usuario ni leía el área, de modo que
  la bandeja no aparecía a los ingenieros destinatarios
- **CORS de la Edge Function.** Faltaba `x-client-info` entre las cabeceras
  permitidas: la librería de Supabase la envía siempre. Y «Verify JWT» debe
  quedar desactivado, o la petición previa se bloquea antes de llegar al código
- **Botones de motivo del aviso** sin conectar: el aviso llegaba sin decir
  qué había fallado, que es justo el dato que interesa
- **Función `registrar_feedback` duplicada.** Convivían dos versiones con
  distinto número de parámetros; se eliminó la obsoleta

### Documentación
- Los guiones SQL que solo existían en la base quedan versionados: catorce
  archivos nuevos o actualizados. Si el proyecto de base de datos se perdiera,
  esa parte era la única no reproducible
- `sql/README.md` con el orden real de ejecución, que no coincide con la
  numeración de los archivos

### Conocido
- `correos_pendientes()` solo recoge los avisos en estado `pendiente`, no los
  marcados `sin_servicio`. Las solicitudes registradas antes de configurar el
  correo quedarían fuera de la cola de reintento. Severidad: media, sin efecto
  hasta que exista el dominio
- `marcar_solicitud()` no comprueba sesión activa dentro de la función y
  depende por completo de las políticas de seguridad. Severidad: media

---

## [v1.0.0] — 2026-08-15

Primera versión con todas las reglas del alcance inicial implementadas.
El asistente resuelve en aproximadamente un segundo lo que en SAP toma
entre cuatro y cinco minutos.

### Añadido
- **Cierre por inactividad (RN-009).** Dos mecanismos complementarios: una
  tarea programada dentro de la base de datos cada 15 minutos, y un cierre
  de respaldo al abrir la aplicación. El segundo garantiza que la regla se
  cumpla aunque la tarea programada falle
- **Historial de consultas** desplegable, con indicador de estado por
  consulta y resultado de la encuesta
- **Recuperación de la salida SAP** de una consulta anterior, sin repetir
  la búsqueda
- **Advertencia de materiales marcados para baja** en SAP

### Reglas de negocio
- **RN-034 — NUEVA.** Materiales marcados para baja (`BORRAR`, `BLOQUEADO`,
  `ANULADO`). No se ocultan: 37 conservan stock real, y ocultarlos sería
  decidir por el ingeniero. Se muestran al final y advertidos

### Decisiones adoptadas
- **ADR-017** — El estado de la sesión, el cierre por inactividad y la
  versión del inventario se resuelven en una sola llamada. Con la latencia
  del servidor, tres viajes se notan
- **ADR-018** — Al recuperar una salida antigua, la ubicación se toma del
  inventario vigente y no de la guardada. Si el material se movió de bodega,
  la salida antigua enviaría al ingeniero a un almacén donde ya no está.
  Contrapartida aceptada: se pierde la elección original de ubicación

### Estado del alcance inicial
Todas las reglas del brief están implementadas: interpretación en lenguaje
natural, tolerancia a errores de escritura, consultas de varios materiales,
niveles de confianza, alternativas, salida consolidada para SAP,
trazabilidad completa, encuesta de utilidad y cierre por inactividad.

### Lo que sigue
El motor funciona, pero su calidad aún no se mide de forma objetiva. El
siguiente paso es el banco de pruebas: un conjunto de casos representativos
contra el que evaluar cada cambio, en lugar de ajustar sobre ejemplos
sueltos. El registro de búsquedas sin resultado ya está alimentando ese
conjunto con casos reales.

### En construcción
- Materiales marcados para baja en SAP
- Pantalla de historial

---

## [v0.9.0] — 2026-08-15

### Añadido
- **Ítems desplegables** con indicador de estado: rojo mientras no se elige,
  verde al elegir. Lo resuelto se contrae mostrando código, descripción y
  almacén; lo pendiente queda abierto
- **Registro de búsquedas sin resultado útil.** Toda consulta con nivel 1 o 2,
  o sin candidatos, se registra automáticamente sin depender de que el
  ingeniero avise
- Botón de aviso que aparece cuando no hay resultados o la confianza es baja.
  El ingeniero indica qué esperaba encontrar
- Diccionario de abreviaturas del inventario (49 equivalencias) construido a
  partir del vocabulario real de 65.883 filas, no de intuiciones
- Expansión bidireccional de la consulta: quien escribe «válvula» encuentra
  «VVA», y quien escribe «VVA» encuentra «válvula»
- Coincidencia por truncamiento: `valv` ↔ `valvula`, `mang` ↔ `manguera`

### Hallazgo
Las descripciones de SAP están abreviadas (`TORN`, `VVA`, `ROD`) mientras el
ingeniero escribe la palabra completa. Ningún algoritmo de similitud resuelve
esto: no son errores de escritura, son abreviaturas. Además conviven varias
formas del mismo concepto (`VVA`, `VALV`, `VALVULA`) según la época en que se
creó cada registro.

Detectado analizando el vocabulario real del inventario completo, no casos
sueltos.

### Corregido
- **Normalización del punto final.** El inventario escribe la misma abreviatura
  con y sin punto: `rod` (1.247) y `rod.` (1.171), `mang` (277) y `mang.` (922).
  Conservarlo las convertía en palabras distintas, de modo que «manguera» no
  encontraba 922 filas. Ahora se elimina el punto al final de palabra y se
  conserva el intermedio, que forma parte de decimales y referencias
- **ADR-002 no se cumplía.** Cuatro versiones coexistían marcadas como
  «anterior» y el borrado dejaba filas huérfanas: 131.766 en lugar de 65.883.
  Se añadió el estado «histórica» y se corrigió la lógica de conmutación
- **El umbral del prefiltro no persistía.** Se fijaba con un comando de sesión
  que se perdía al terminar la consulta, volvía al valor por defecto y
  descartaba candidatos válidos antes de que la comparación fonética actuara:
  «sinta» no llegaba nunca a compararse con «cinta»
- El identificador de la búsqueda fallida se guardaba en una variable global
  que dependía del orden de carga de los archivos. Ahora vive en el propio ítem

### Espacio
La reconstrucción de índices recuperó 61 MB. Dos versiones completas del
inventario ocupan 88 MB de tabla, sobre un límite de 500 MB.

### Método
El descubrimiento automático de variantes propone, no decide (RN-025). La
primera ejecución encontró aciertos reales (`torn`↔`tornillo`, `transm`↔
`transmision`) junto a falsos positivos que habrían sido dañinos:
`contacto`↔`contactor` son piezas eléctricas distintas, y `papel`↔`papelsa`
confundiría materiales con el nombre de la empresa. Confirma que la aprobación
humana es necesaria.

### En construcción
- Banco de pruebas y medición objetiva del motor

---

## [v0.8.0] — 2026-08-12

### Hallazgo estructural
La premisa de que cada material aparece una sola vez era **incorrecta**.
Un material existe en SAP una vez por cada combinación de centro y almacén:
46.212 materiales distintos ocupan 65.883 filas. La muestra de 500 filas no
lo reveló porque las filas estaban dispersas.

Detectado porque la carga completa falló la validación de RN-012 y dejó
activa la versión anterior, tal como estaba previsto. La verificación
funcionó exactamente para lo que fue diseñada.

### Añadido
- **65.883 filas reales cargadas.** 46.212 materiales únicos, 43 MB de tabla
  y 55 MB de base completa, muy por debajo del límite del plan
- Agrupación por material: una tarjeta por código, con sus ubicaciones
  listadas y ordenadas por prioridad (RN-018)
- Selección de material **y** ubicación: la salida para SAP necesita saber
  de qué almacén se retira
- Aviso explícito cuando no hay inventario cargado, en lugar de devolver un
  resultado vacío que se interpretaría como «ese material no existe»

### Corregido
- **Rendimiento.** Con 65.883 filas la búsqueda agotaba el tiempo de espera
  del servidor (error 57014, más de 8 segundos). Se añadió un prefiltro por
  índice trigram que reduce el conjunto a unos cientos de candidatos antes
  de aplicar la comparación costosa. De 8.520 ms a **864 ms**
- La clave única del inventario pasó de `(versión, material)` a
  `(versión, material, centro, almacén)`

### Reglas de negocio
- **RN-014 — DEROGADA.** Afirmaba que el código de material es único por
  registro
- **RN-033 — NUEVA.** Un material puede aparecer en varias filas, una por
  cada combinación de centro y almacén donde tiene registro en SAP. La clave
  real es material + centro + almacén

### Pendientes
- **PENDIENTE-005 — CERRADO.** Los códigos de almacén «no documentados»
  (`P122`, `P123`, `P212`, `P213`) son almacenes normales de cada centro.
  Apenas aparecían en la muestra
- **PENDIENTE-007 — CERRADO.** Rendimiento resuelto con el prefiltro
- **ADR-002 — revisado.** El límite de espacio ya no aprieta: dos versiones
  completas ocupan unos 110 MB de los 500 MB disponibles

### Método de trabajo
Se detuvo el ajuste del motor basado en casos sueltos elegidos a mano. Ese
enfoque produce un motor afinado para esos casos y peor para los miles
restantes. El siguiente paso es construir el banco de pruebas con casos
representativos y medir cada cambio contra él.

### En construcción
- Fase 12 — Carga completa del inventario (65.884 filas)

---

## [v0.7.0] — 2026-08-12

### Añadido
- **Registro completo de solicitudes.** Cada consulta queda guardada con
  su mensaje original, los ítems detectados, las cantidades, el nivel de
  confianza y la decisión del ingeniero
- Se guardan **todos los candidatos mostrados**, no solo el elegido. Es lo
  que permite auditar un error crítico meses después: saber qué vio el
  ingeniero y qué descartó
- Encuesta de utilidad al final de cada solicitud (RN-029), opcional y sin
  bloquear una nueva consulta
- Función de historial propio por usuario
- La versión del sistema queda registrada en cada solicitud, de modo que
  siempre se sabe qué código produjo cada respuesta

### Verificado
- Una solicitud real quedó registrada con sus cinco candidatos, la decisión
  y la respuesta de la encuesta
- La reconstrucción completa de una solicitud funciona: qué se pidió,
  cuántas opciones se mostraron, cuál se eligió y si resultó útil

### Decisiones adoptadas
- **ADR-015** — El registro ocurre al generar la salida para SAP, no al
  buscar. Es el momento en que la solicitud queda realmente resuelta, y
  evita guardar búsquedas exploratorias que el ingeniero descartó
- **ADR-016** — Un fallo en el registro no interrumpe el trabajo. La salida
  se muestra primero y el guardado ocurre después: si la base de datos no
  responde, el ingeniero ya tiene lo que necesita

### En construcción
- Fase 11 — Historial, trazabilidad y encuesta de utilidad

---

## [v0.6.0] — 2026-08-12

### Añadido
- **Consulta de varios materiales en un solo mensaje.** «4 rodamientos 6205
  y dos correas» se interpreta como dos ítems independientes con sus
  cantidades (RN-005)
- Detección de cantidades en cifra y en palabra («4», «cuatro»)
- Limpieza de verbos introductorios: «necesito», «requiero», «por favor»
- Aviso visible de cantidad asumida, y cantidad editable por el ingeniero (RN-004)
- Selección de material por ítem, con preselección automática únicamente
  en nivel 5 (RN-021, ADR-003)
- Presentación conjunta de todos los ítems, resueltos y pendientes (RN-007)
- **Salida consolidada para SAP** (RN-008, RN-027): tabla de verificación
  más bloque copiable con las 9 columnas separadas por tabulador
- Botón de copia al portapapeles, con selección manual como alternativa
  si el navegador la bloquea

### Corregido
- La barra `/` dejó de ser separador de ítems. En planta es una medida
  (`3/4`, `1/2`, `3/8`) y dividir por ella destruía el atributo más
  decisivo para identificar el material. `12 tornillos 3/8 x 2` se
  interpretaba como dos materiales; ahora es uno solo con cantidad 12

### Formato de salida confirmado (RN-027 actualizado)
Nueve columnas, en este orden exacto y separadas por tabulador:
`Componente · Denominación · TE · Ctd. Neces. · UM · T · S · Almacén · Centro`
`TE` y `S` van siempre vacías. `T` lleva siempre la letra `L`.

### Verificado
- Interpretación correcta en los cuatro casos de prueba, incluida la
  conservación de medidas fraccionarias
- Flujo completo: consulta → selección → cantidades → salida → copiado
- El bloque copiado se pega en Excel y las nueve columnas caen en su sitio

### Pendiente de validación
- **PENDIENTE-008.** Confirmar el pegado en SAP real. Verificado en Excel,
  pendiente de acceso a SAP para la comprobación definitiva

### Decisiones adoptadas
- **ADR-013** — La salida se ofrece como bloque copiable en la propia
  página, no como archivo descargable. Evita descargar, abrir, copiar y
  cerrar un archivo en cada consulta, que es precisamente el tiempo que
  el piloto busca ahorrar
- **ADR-014** — Solo se preselecciona material en nivel 5. En cualquier
  otro nivel decide el ingeniero (RN-024)

### En construcción
- Fase 10 — Salida consolidada para SAP

---

## [v0.5.0] — 2026-08-12

### Añadido
- Motor de búsqueda con ranking por capas: código exacto, código antiguo,
  referencia, medida, palabras coincidentes, similitud textual y disponibilidad
- Extracción de atributos: referencias, medidas y palabras descriptivas
- Nivel de confianza de 1 a 5 (RN-021, ADR-003)
- Similitud fonética y por distancia de edición, mediante `fuzzystrmatch`
- Comparación palabra a palabra, que evita que un término corto se diluya
  dentro de una descripción larga
- Pantalla de consulta con presentación diferenciada de disponible y
  comprometido (RN-030)

### Decisiones adoptadas
- **ADR-011** — Arquitectura de búsqueda en capas. Cada capa cubre un tipo
  de error que las anteriores no pueden resolver:
  1. código exacto · 2. trigrama (letras omitidas o sobrantes) ·
  3. fonética y distancia (letras sustituidas o en otro orden) ·
  4. sinónimos validados (jerga local, Fase 14) ·
  5. aprendizaje sugerido a partir del uso (Fase 14).
  Ninguna sustituye a otra
- **ADR-012** — La disponibilidad pesa deliberadamente poco en el ranking
  (4 puntos sobre más de 100). RN-016: puede reordenar candidatos válidos,
  nunca elevar un material incorrecto

### Corregido
- El umbral de similitud mínima bajó de 0.25 a 0.12. El valor anterior
  descartaba consultas cortas con errores de escritura
- La distancia de edición normalizada producía falsos positivos entre
  palabras de longitud muy distinta: `rodamiento` frente a `liner` puntuaba
  0.78. Ahora solo se aplica con longitudes comparables y pocos cambios
  reales, y por debajo de 0.55 se descarta

### Verificado
- `kra` devuelve cinco materiales Kraft, todos correctos
- `sinta doble das`, con dos errores ortográficos, sitúa las dos cintas
  doble faz en las posiciones 1 y 2
- Los falsos positivos de la corrección anterior quedaron en 0.00

### Conocido
- **PENDIENTE-006.** Las variantes `craf` y `carft` devuelven ruido en las
  primeras posiciones. El material correcto aparece, pero no encabeza.
  Causa probable: el algoritmo fonético colapsa consonantes distintas.
  Se abordará con la capa de sinónimos en la Fase 14
- **PENDIENTE-007.** La comparación palabra a palabra recorre todas las
  filas. Con 500 el rendimiento es bueno; con 65.884 debe medirse y
  probablemente requiera un filtro previo por índice
### En construcción
- Fase 7 — Motor de búsqueda

---

## [v0.4.0] — 2026-08-12

### Añadido
- Importador de inventario: lee el archivo en el navegador, valida los 21
  encabezados y envía las filas por lotes de 500
- Detección automática del separador del archivo (coma, punto y coma o tabulador)
- Conversión numérica según la unidad de medida (RN-031)
- Clasificación de ubicación por centro (RN-018, RN-032)
- Versionado de cargas con activación validada y reversión a la versión anterior
- Panel de administración visible solo para el rol `admin`
- **500 filas reales cargadas y verificadas**

### Verificado
- 500 filas, 500 códigos únicos, ninguna sin texto normalizado
- Tildes conservadas correctamente en descripciones y encabezados
- Conversión numérica correcta: unidades de conteo en entero (`213`, `49`),
  unidades continuas con decimales (`0.00` en metros)
- **Búsqueda difusa funcionando.** La consulta `sinta doble fas`, con dos errores
  ortográficos, devuelve las dos cintas doble faz en las posiciones 1 y 2.
  La consulta `cinta aislante 3m` sitúa el material correcto con una similitud
  de 0.486, más del doble que el siguiente candidato

### Decisiones adoptadas
- **ADR-009** — `XCentro` se carga por fidelidad al origen pero el motor lo
  ignora. Se confirmó que no es relevante para el propósito del asistente
- **ADR-010** — El archivo de origen se lee y se envía desde el navegador del
  administrador directamente a la base de datos, sin pasar en ningún momento
  por el repositorio

### Pendientes
- **PENDIENTE-001 — CERRADO.** `XCentro` no aplica al propósito del sistema
- **PENDIENTE-004 — CERRADO.** La ambigüedad numérica se resuelve mediante la
  unidad de medida (RN-031)
- **PENDIENTE-002** — Abierto. Almacén del Corrugador, con evidencia sólida
  pero sin confirmación formal
- **PENDIENTE-005** — Abierto. Códigos de almacén no documentados. Sin impacto:
  RN-032 garantiza que ningún material se oculte por esta causa

### Conocido
- Al recargar, la pantalla de acceso aparece un instante antes de restaurarse
  la sesión. Severidad: menor
- El filtro de códigos antiguos corrompidos detecta el formato con hora. Si la
  hoja de cálculo exporta la fecha en otro formato, el valor no se descarta.
  Afecta únicamente a la búsqueda por código antiguo. Severidad: menor
- La conexión de botones en el arranque no comprueba la existencia del elemento
  de forma uniforme. Sin impacto actual. Severidad: menor

### Observado para la Fase 7
- La similitud textual por sí sola no basta para el ranking: en una búsqueda de
  cinta aislante aparece un material sin relación en cuarta posición. Se requiere
  el ranking completo de RN-017
- El umbral de similitud debe elevarse por encima de 0.15, ajustándolo mediante
  el parámetro de configuración correspondiente

### En construcción
- Fase 5 — Carga del inventario

---

## [v0.3.0] — 2026-08-12

### Añadido
- Aplicación web publicada y accesible desde navegador
- Pantalla de acceso con correo y contraseña
- Sesión persistente: no se piden credenciales en cada visita
- Panel de estado del sistema: conexión, versión y volumen de datos
- Hoja de estilos con énfasis en la legibilidad de códigos y cantidades
  (cifras tabulares, tipografía monoespaciada, sin fuentes externas)

### Verificado
- **Aislamiento en producción.** Sin sesión iniciada, y con la dirección
  de la aplicación y la clave publicable a la vista, una consulta directa
  a la base de datos devuelve cero filas

### Corregido
- La URL del proyecto incluía la ruta del endpoint, que la librería añade
  por su cuenta
- Credenciales duplicadas en un segundo archivo. Ahora residen únicamente
  en el archivo de configuración
- La validación de arranque usaba textos de relleno; ahora comprueba el
  formato real e indica con precisión qué valor está mal

### Conocido
- Al recargar, la pantalla de acceso aparece un instante antes de
  restaurarse la sesión. Sin impacto funcional. Severidad: menor

### Hallazgos de la muestra de inventario (500 filas)
- **PENDIENTE-002 — resuelto en la práctica.** El cruce entre centro y
  almacén es consistente y sin excepciones en las 124 filas del Corrugador.
  Pendiente únicamente de confirmación formal
- **PENDIENTE-001 — sigue abierto.** La columna `XCentro` no es un centro
  de costos, sino un número entero de 0 a 15. Los valores altos aparecen
  en consumibles genéricos y los bajos en repuestos específicos. Hipótesis:
  cuenta de ubicaciones adicionales donde existe el material. **No se
  implementa lógica alguna sobre esta columna hasta confirmarlo**
- **PENDIENTE-004 — nuevo.** Los valores numéricos llegan como texto con
  formato mixto. Ocho casos son ambiguos porque el punto puede significar
  separador de miles o decimal. Se cargarán marcados para revisión, nunca
  interpretados por conjetura
- **PENDIENTE-005 — nuevo.** Aparecen códigos de almacén no documentados
  en la definición inicial. Poco frecuentes, sin impacto en la búsqueda
- **Incidencia de origen.** Seis códigos antiguos fueron convertidos en
  fechas por la hoja de cálculo. Al preparar el archivo, esa columna debe
  importarse como texto

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

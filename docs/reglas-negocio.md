# Reglas de negocio

Identificador `RN-###`. Toda regla vigente es de cumplimiento obligatorio para el motor.
Los valores concretos de centros y almacenes residen en la tabla `reglas_negocio`
de la base de datos, no en este repositorio.

## Interpretación de la solicitud

- **RN-001** — La entrada es lenguaje natural. Debe tolerar errores ortográficos,
  abreviaciones, singular/plural, marcas, referencias, medidas y cantidades escritas
  con palabras.
- **RN-002** — El mensaje original del usuario se conserva siempre, sin alterar.
- **RN-003** — Por cada ítem se intenta extraer: cantidad, tipo, descripción, marca,
  referencia, modelo, medida, dimensiones y características relevantes.
- **RN-004** — Si no se indica cantidad, se asume **1 unidad**, se advierte de forma
  visible en la respuesta y se registra internamente como cantidad asumida.
- **RN-005** — Una solicitud puede contener de 1 a N materiales. Cada uno se procesa
  de forma independiente dentro de la misma solicitud.

## Ciclo de vida de la solicitud

- **RN-006** — La solicitud permanece **abierta** mientras quede algún ítem sin resolver.
- **RN-007** — No se entregan resultados parciales. Los ítems resueltos se conservan
  internamente y se pregunta en **un solo mensaje** todo lo pendiente.
- **RN-008** — Al resolverse todos los ítems se entrega **una única salida consolidada**,
  para que el ingeniero copie y pegue una sola vez.
- **RN-009** — Tras 60 minutos de inactividad la solicitud se cierra y se marca como
  **incompleta**, nunca como resuelta.
- **RN-010** — Una solicitud cerrada no se modifica retroactivamente. Continuar sobre
  ella genera una **solicitud nueva vinculada** a la anterior.

## Datos e inventario

- **RN-011** — Los datos provenientes de SAP son inmutables. La normalización se guarda
  en columnas auxiliares; el texto original nunca se sobrescribe.
- **RN-012** — Toda carga valida la presencia y el orden exacto de **21 encabezados**
  (ADR-005), la existencia de la columna clave, la unicidad de códigos y la cantidad
  de registros. Si algo falla, la carga se rechaza completa. El separador del archivo
  se detecta automáticamente: coma, punto y coma o tabulador.
- **RN-013** — La versión de datos anterior permanece activa hasta que la nueva se valida
  por completo. Ante una carga fallida, el sistema sigue operando con la última versión
  válida. Nunca opera con una actualización parcial.
- **RN-014** — **DEROGADA.** Sustituida por RN-033. Afirmaba que el código de
  material es único por registro y que no debían asumirse filas repetidas por
  bodega. La carga del inventario completo demostró lo contrario.

- **RN-031** — Conversión de valores numéricos. El archivo de origen entrega los
  números como texto con formato mixto: unos con punto de miles y coma decimal
  (`3.514.207,24`), otros como entero limpio. Si la unidad de medida es de conteo
  (`UND` y equivalentes), el resultado se redondea a entero: no existen 8,2 guantes.
  Para unidades continuas (`KG`, `MT`, `LT`, `M`) los decimales se conservan.

  Esta regla resuelve además los valores donde el punto era interpretable de dos
  formas, porque corresponden casi siempre a artículos contables.

- **RN-033** — **Multiubicación.** Un material puede aparecer en **varias filas**,
  una por cada combinación de centro y almacén donde tiene registro en SAP. La
  clave real del inventario es **material + centro + almacén**.

  Consecuencias:
  - La búsqueda agrupa por código: un material es una sola tarjeta, con sus
    ubicaciones listadas dentro y ordenadas por prioridad (RN-018)
  - El ingeniero elige material **y** ubicación, porque la salida para SAP
    necesita saber de qué almacén se retira
  - El stock disponible se muestra por ubicación y también como total

  Comprobado: 46.212 materiales distintos ocupan 65.883 filas.

- **RN-034** — **Materiales marcados para baja en SAP.** Algunas descripciones
  incluyen `BORRAR` (381 filas), `BLOQUEADO` (10) o `ANULADO` (6).

  **No se ocultan.** 37 de ellos conservan stock real: un retenedor marcado
  para baja con 5 unidades en el estante sigue siendo un retenedor que existe.
  Ocultarlo sería decidir por el ingeniero, que es justo lo que RN-024 prohíbe.

  Tratamiento: se muestran **al final** de la lista de candidatos, con una
  advertencia visible que indica que están marcados para baja y conviene
  verificar antes de solicitarlos.

## Búsqueda y ranking

- **RN-015** — Orden lógico obligatorio: primero identificar **qué** material es;
  después analizar **dónde** está y **cuánto** hay.
- **RN-016** — La disponibilidad solo puede reordenar candidatos que ya sean
  técnicamente razonables. Nunca puede elevar un material incorrecto por tener stock.
- **RN-017** — Prioridad de ranking: código y referencia → descripción → marca →
  similitud textual → disponibilidad y ubicación → historial del ingeniero.
- **RN-018** — Prioridad de ubicación: primero disponibilidad local del área objetivo,
  después otras ubicaciones de planta, después sedes remotas.
- **RN-019** — Ningún material se oculta por estar en una sede remota. Se distingue
  con claridad entre **disponibilidad inmediata** y **disponibilidad que exige traslado**.
- **RN-020** — **DEROGADA.** Sustituida por RN-030.

- **RN-030** — **Clasificación de disponibilidad.** Sustituye a RN-020.

  **Disponible:** `stock Libre_Utilización` + `Stock consignación`. Ambos están
  físicamente en planta y el ingeniero puede disponer de ellos.

  **Comprometido:** `Stock Proyectos`. Existe físicamente, pero ya está asignado
  a un proyecto. **No se oculta ni se suma al disponible.** Se presenta por
  separado con una advertencia explícita: el material existe, pero identificar a
  quién está asignado y valorar prioridades exige pasos adicionales.

  Fundamento: en una parada de máquina de madrugada, saber que un material existe
  aunque esté comprometido puede ser justo la información que se necesita. Ocultarlo
  sería decidir por el ingeniero.

- **RN-032** — **Códigos de almacén no documentados.** Un material nunca se oculta
  por desconocerse su ubicación. Los códigos no reconocidos se clasifican como
  «otra ubicación» y el material se muestra igual. Es preferible presentar un
  material sin saber exactamente dónde está que no presentarlo.

## Confianza

- **RN-021** — Escala interna de 1 a 5.
  - **5 — Exacto:** coincidencia completa de todos los atributos solicitados,
    sin contradicciones, **y candidato único**. Se muestra solo esa coincidencia.
  - **4:** coincidencia muy alta con algún aspecto no validado, o más de un candidato
    plausible. Se muestran alternativas.
  - **3:** coincide la familia y parte de los atributos; varias posibilidades razonables.
  - **2:** coincidencia parcial y solicitud poco específica. Se pide aclaración o se
    marcan los candidatos como dudosos.
  - **1:** solicitud ambigua, contradictoria o sin coincidencia confiable. Se pide
    información adicional.
- **RN-022** — Si varios materiales empatan técnicamente, el nivel **no puede ser 5**
  (ADR-003). Presentar un material incorrecto como Nivel 5 es un error **crítico**.

## Alternativas y decisión

- **RN-023** — Pueden existir varias marcas equivalentes. El sistema puede advertir que
  una cantidad se cubre combinando opciones, pero **nunca selecciona la combinación**.
- **RN-024** — La aplicación interpreta, busca, organiza, sugiere y presenta.
  El ingeniero decide. La aplicación no sustituye su criterio.

## Aprendizaje

- **RN-025** — El aprendizaje observado **no se convierte automáticamente en regla**.
  Las reglas oficiales se mantienen separadas y versionadas.
- **RN-026** — Las preferencias personales pueden modificar el ranking, pero **nunca
  ocultar** alternativas técnicamente válidas.

## Salida y feedback

- **RN-027** — Salida consolidada para SAP. **Ocho columnas**, en este orden
  exacto y separadas por tabulador:

  `Componente · Denominación · Ctd. Neces. · UM · T · S · Almacén · Centro`

  - `Componente` — código SAP del material
  - `Denominación` — descripción del material
  - `Ctd. Neces.` — cantidad solicitada
  - `UM` — unidad de medida base
  - `T` — **siempre la letra `L`**
  - `S` — **siempre vacía**
  - `Almacén` y `Centro` — ubicación del material elegido

  **La columna `TE` fue eliminada** (corrección de 2026-08-24). Aparece en la
  pantalla de SAP pero no admite valor al pegar: incluirla desplazaba todos los
  datos una posición a la derecha.

  El orden debe coincidir exactamente con la pantalla de SAP: cualquier
  desviación descoloca todas las columnas al pegar. Si alguna cantidad
  fue asumida, se advierte de forma visible antes de la salida.

- **RN-028** — El sistema no crea la orden en SAP. El ingeniero sigue siendo responsable
  de trasladar la información a la operación correspondiente.
- **RN-029** — Toda respuesta final incluye la encuesta «¿Te fue útil?». Es opcional
  y no bloquea una nueva consulta. Una respuesta negativa marca el caso para revisión.

## Roles y áreas

Incorporado en v1.1.0, al ampliarse el alcance a mecánicos, contratistas y almacén.

| Rol | Puede |
|-----|-------|
| `admin` | Todo lo anterior más cargar inventario, gestionar usuarios y reglas, revisar métricas |
| `ingeniero` | Consultar, elegir, obtener la salida SAP, ver su historial, recibir solicitudes |
| `mecanico` | Consultar y **enviar** solicitudes al ingeniero |
| `contratista` | Igual que `mecanico` |
| `jefe_almacen` | Consultar. Salidas específicas por definir |
| `almacenista` | Consultar. Salidas específicas por definir |

Áreas: `mantenimiento`, `almacen`.

**Cada área tiene sus propios destinatarios.** Una solicitud de mantenimiento no
llega al almacén aunque su jefe tenga `recibe_solicitudes`. No es un descuido: es
el diseño. Añadir un departamento nuevo es un `INSERT`, no un rediseño.

La solicitud pide el **nombre completo** en cada envío aunque haya sesión iniciada:
la cuenta puede compartirse entre varias personas y, sin ese campo, el registro
diría «mecánico» en todas y se perdería la trazabilidad.

El envío exige una **orden de trabajo de siete dígitos**, validada en el navegador
y en la base de datos. Una comprobación que solo vive en el navegador no protege nada.

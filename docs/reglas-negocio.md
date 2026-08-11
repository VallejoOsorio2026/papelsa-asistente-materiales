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
- **RN-012** — Toda carga valida la presencia y el orden exacto de **21 encabezados**,
  la existencia de la columna clave, la unicidad de códigos y la cantidad de registros.
  Si algo falla, la carga se rechaza completa.
- **RN-013** — La versión de datos anterior permanece activa hasta que la nueva se valida
  por completo. Ante una carga fallida, el sistema sigue operando con la última versión
  válida. Nunca opera con una actualización parcial.
- **RN-014** — El código de material es único por registro. No se asume que un mismo
  código se repita en varias filas para representar bodegas distintas.

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
- **RN-020** — No se implementa lógica de material reservado. La base actual no permite
  determinarlo de forma confiable y no se infiere desde otras columnas.

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

- **RN-027** — La salida consolidada incluye: Componente (código), Denominación,
  Cantidad, UM, T = `L`, S = vacío, Almacén y Centro. Si la cantidad fue asumida,
  se indica.
- **RN-028** — El sistema no crea la orden en SAP. El ingeniero sigue siendo responsable
  de trasladar la información a la operación correspondiente.
- **RN-029** — Toda respuesta final incluye la encuesta «¿Te fue útil?». Es opcional
  y no bloquea una nueva consulta. Una respuesta negativa marca el caso para revisión.

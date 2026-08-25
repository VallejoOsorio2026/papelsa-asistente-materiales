# Asistente de materiales — Guía rápida

Piloto. SAP sigue siendo la fuente de verdad.

---

## Entrar

**Dirección:** https://vallejoosorio2026.github.io/papelsa-asistente-materiales/

Tu correo y la contraseña que te compartieron. Funciona en computador y en
teléfono, desde cualquier navegador. No hay que instalar nada.

La sesión queda guardada: no tendrás que escribir la contraseña cada vez.
Si usas un equipo compartido, pulsa **Salir** al terminar.

---

## Buscar

Escribe como hablas. No hace falta el código ni la descripción exacta.

    cinta aislante
    rodamiento 6205 SKF
    4 guantes de cuero y dos correas
    valvula 1/2

**Funciona aunque escribas rápido o con errores.** «sinta doble fas»
encuentra las cintas doble faz.

**Puedes pedir varios materiales de una vez.** Cada uno aparece en su
propio bloque.

**Si no indicas cantidad, se asume 1** y te lo advierte. Puedes cambiarla
en el recuadro de cada bloque.

**También entiende cómo se habla en planta.** «disco pulidora pequeño»
encuentra los discos de 4 1/2".

---

## Elegir

Cada bloque muestra hasta cinco opciones, con su código, descripción y
existencias. Si ninguna sirve, pulsa **Ver más resultados**.

Un material puede estar en varias ubicaciones. **Pulsa la ubicación de
donde vas a retirarlo**, no solo el material: la salida para SAP necesita
saber de qué almacén sale.

El punto del bloque se pone verde cuando ya elegiste.

**Qué significan los avisos:**

- **En proyectos** — el material existe, pero está comprometido. Habría que
  identificar a quién está asignado y valorar prioridades
- **Marcado para baja en SAP** — verifica antes de solicitarlo
- **Otra sede · requiere traslado** — está fuera del Molino
- **Nivel de confianza 1 a 5** — qué tan seguro está el sistema. Con nivel
  bajo, añade la marca, la medida o la referencia

---

## Copiar a SAP

*(Ingenieros y administrador)*

Cuando hayas elegido todo, pulsa **Generar salida para SAP**.

Aparece la tabla de ocho columnas y un bloque para copiar. Pulsa
**Copiar para SAP** y pégalo directamente.

Revisa las cantidades antes de pegar, sobre todo si alguna fue asumida.

**El asistente no crea la orden en SAP.** Tú sigues siendo responsable de
esa parte.

---

## Enviar una solicitud

*(Mecánicos y contratistas)*

Después de elegir los materiales aparece el recuadro **Enviar solicitud de
materiales**. Necesitas dos datos:

- **Tu nombre completo.** Se pide siempre, aunque hayas entrado con tu
  cuenta: varias personas pueden usar el mismo acceso y sin el nombre no
  se sabe quién pidió qué
- **La orden de trabajo.** Siete dígitos, sin letras ni símbolos

Al enviar, la solicitud le llega al ingeniero de tu área con los códigos,
las cantidades y el almacén ya resueltos. Él decide y la lleva a SAP.

También puedes pulsar **Descargar Excel** si prefieres pasarla por otro
medio.

---

## Solicitudes recibidas

*(Ingenieros que reciben solicitudes)*

En **Solicitudes recibidas** están las que enviaron los mecánicos y
contratistas de tu área, con la orden de trabajo y los materiales elegidos.

- **⧉** junto a la orden copia el número, para no teclearlo a mano
- **Ver salida SAP** genera el bloque listo para pegar
- **Marcar atendida** la retira de la lista

Esa última acción la retira **para todos los ingenieros del área**, no solo
para ti: si ya la atendiste, nadie más tiene que volver a hacerlo.

La bandeja funciona aunque el aviso por correo falle o caiga en spam. El
correo es el aviso; la bandeja es el registro.

---

## Si algo no aparece

Bajo los resultados hay un recuadro plegado: **¿No es esto lo que
buscabas?** Ábrelo, marca qué pasó y, si quieres, escribe qué esperabas
encontrar.

No hace falta que sea perfecto. «buscaba una cinta aislante 3M negra»
sirve. Con marcar el motivo ya es suficiente.

Es la forma más directa de que el buscador mejore: cada aviso se revisa.

---

## Historial

En **Mis consultas anteriores** están tus búsquedas previas. Puedes volver
a generar la salida para SAP de cualquiera sin repetir la búsqueda, útil si
se te cerró la ventana o te equivocaste al pegar.

---

## Lo que conviene saber

- Los datos vienen de una extracción de SAP, **no se actualizan solos**.
  Si algo no cuadra con lo que ves en SAP, SAP tiene la razón
- Una consulta sin actividad se cierra sola a los 60 minutos
- Al final de cada consulta aparece «¿Te fue útil?». Responder toma un
  segundo y ayuda a saber si esto sirve

---

## Dudas o problemas

Juan Pablo Vallejo — responsable del piloto.

Si algo falla, anota **qué escribiste exactamente** y qué esperabas. Con eso
se puede reproducir el problema.

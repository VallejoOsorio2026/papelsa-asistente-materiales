// ============================================================
// requests.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Gestiona una solicitud completa: varios materiales, sus
// candidatos y lo que el ingeniero va eligiendo.
//
// RN-007: no se entregan resultados parciales. Los items
// resueltos se conservan y se pregunta todo de una vez.
// RN-008: al resolverse todos, una unica salida consolidada.
// ============================================================

// Solicitud en curso. Vive en memoria hasta generar la salida.
let solicitudActual = null;


// ------------------------------------------------------------
// nuevaSolicitud()
// Interpreta el mensaje y busca cada item por separado.
// ------------------------------------------------------------
async function nuevaSolicitud(mensaje, informar) {

  const items = interpretar(mensaje);

  solicitudActual = {
    mensajeOriginal: mensaje,
    creadaEn: new Date(),
    items: []
  };

  for (let i = 0; i < items.length; i++) {

    const it = items[i];

    if (informar) {
      informar('Buscando ' + (i + 1) + ' de ' + items.length + ': '
             + it.texto);
    }

    const respuesta = await buscar(it.texto);

    solicitudActual.items.push({
      orden:           it.orden,
      textoOriginal:   it.textoOriginal,
      texto:           it.texto,
      cantidad:        it.cantidad,
      cantidadAsumida: it.cantidadAsumida,
      nivel:           respuesta.nivel,
      mensaje:         respuesta.mensaje,
      candidatos:      respuesta.resultados || [],
      elegido:         null
    });
  }

  // Preseleccion solo con nivel 5: coincidencia exacta y
  // candidato unico (RN-021, ADR-003). En cualquier otro caso
  // decide el ingeniero (RN-024).
  solicitudActual.items.forEach(function (item) {
    if (item.nivel === 5 && item.candidatos.length === 1) {
      item.elegido = item.candidatos[0];
    }
  });

  return solicitudActual;
}


// ------------------------------------------------------------
// elegirMaterial()
// ------------------------------------------------------------
function elegirMaterial(orden, codigoMaterial) {

  const item = solicitudActual.items.find(function (i) {
    return i.orden === orden;
  });
  if (!item) return;

  const candidato = item.candidatos.find(function (c) {
    return c.material === codigoMaterial;
  });

  // Volver a pulsar el mismo material lo deselecciona.
  item.elegido = (item.elegido && item.elegido.material === codigoMaterial)
               ? null
               : candidato;
}


// ------------------------------------------------------------
// cambiarCantidad()
// ------------------------------------------------------------
function cambiarCantidad(orden, cantidad) {

  const item = solicitudActual.items.find(function (i) {
    return i.orden === orden;
  });
  if (!item) return;

  const n = Number(cantidad);
  if (!isNaN(n) && n > 0) {
    item.cantidad = n;
    item.cantidadAsumida = false;   // el ingeniero la confirmo
  }
}


// ------------------------------------------------------------
// itemsPendientes()
// RN-006: la solicitud sigue abierta mientras falte algun item.
// ------------------------------------------------------------
function itemsPendientes() {
  if (!solicitudActual) return [];
  return solicitudActual.items.filter(function (i) {
    return i.elegido === null;
  });
}


// ------------------------------------------------------------
// itemsResueltos()
// ------------------------------------------------------------
function itemsResueltos() {
  if (!solicitudActual) return [];
  return solicitudActual.items.filter(function (i) {
    return i.elegido !== null;
  });
}

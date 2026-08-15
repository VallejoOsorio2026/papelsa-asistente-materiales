// ============================================================
// requests.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Gestiona una solicitud completa: varios materiales, sus
// candidatos y lo que el ingeniero va eligiendo.
//
// RN-007: no se entregan resultados parciales.
// RN-008: al resolverse todos, una unica salida consolidada.
// RN-033: se elige material Y ubicacion.
// ============================================================

let solicitudActual = null;


// ------------------------------------------------------------
// nuevaSolicitud()
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
      informar('Buscando ' + (i + 1) + ' de ' + items.length + ': ' + it.texto);
    }

    const respuesta = await buscar(it.texto);

    solicitudActual.items.push({
      orden:           it.orden,
      textoOriginal:   it.textoOriginal,
      texto:           it.texto,
      cantidad:        it.cantidad,
      cantidadAsumida: it.cantidadAsumida,
      nivel:           respuesta.nivel,
      sinInventario:   respuesta.sin_inventario === true,
      mensaje:         respuesta.mensaje,
      candidatos:      respuesta.resultados || [],
      elegido:         null
    });
    // Registro automatico: no depende de que el ingeniero avise
    if (respuesta.nivel <= 2 || (respuesta.resultados || []).length === 0) {
      await registrarBusquedaFallida(
        it.orden, it.texto, respuesta.nivel,
        (respuesta.resultados || []).length
      );
    }
  }

  // Preseleccion solo con nivel 5, y solo si el material tiene
  // una unica ubicacion: si hay varias, decide el ingeniero
  // de donde se retira (RN-024, ADR-003).
  solicitudActual.items.forEach(function (item) {
    if (item.nivel === 5 && item.candidatos.length === 1) {
      const c = item.candidatos[0];
      const ubis = c.ubicaciones || [];
      if (ubis.length === 1) {
        item.elegido = {
          material:     c.material,
          descripcion:  c.descripcion,
          unidad:       c.unidad,
          centro:       ubis[0].centro,
          almacen:      ubis[0].almacen,
          disponible:   ubis[0].disponible,
          comprometido: ubis[0].comprometido
        };
      }
    }
  });

  return solicitudActual;
}


// ------------------------------------------------------------
// elegirUbicacion()
// La clave llega con el formato  material|centro|almacen
// ------------------------------------------------------------
function elegirUbicacion(orden, clave) {

  const item = solicitudActual.items.find(function (i) {
    return i.orden === orden;
  });
  if (!item) return;

  const partes  = clave.split('|');
  const codigo  = partes[0];
  const centro  = partes[1];
  const almacen = partes[2];

  // Volver a pulsar la misma ubicacion la deselecciona.
  if (item.elegido
      && item.elegido.material === codigo
      && item.elegido.almacen === almacen) {
    item.elegido = null;
    return;
  }

  const candidato = item.candidatos.find(function (c) {
    return c.material === codigo;
  });
  if (!candidato) return;

  const ubi = (candidato.ubicaciones || []).find(function (u) {
    return u.centro === centro && u.almacen === almacen;
  });

  // Se guarda plano, tal como lo necesita la salida SAP.
  item.elegido = {
    material:     candidato.material,
    descripcion:  candidato.descripcion,
    unidad:       candidato.unidad,
    centro:       centro,
    almacen:      almacen,
    disponible:   ubi ? ubi.disponible : 0,
    comprometido: ubi ? ubi.comprometido : 0
  };
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

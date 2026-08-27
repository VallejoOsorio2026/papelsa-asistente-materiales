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
    const candidatos = respuesta.resultados || [];

    const nuevoItem = {
      orden:           it.orden,
      textoOriginal:   it.textoOriginal,
      texto:           it.texto,
      cantidad:        it.cantidad,
      cantidadAsumida: it.cantidadAsumida,
      nivel:           respuesta.nivel,
      sinInventario:   respuesta.sin_inventario === true,
      mensaje:         respuesta.mensaje,
      candidatos:      candidatos,
      idBusqueda:      null,
      hayMas:          respuesta.hay_mas === true,
      limite:          5,
      elegido:         null
    };

    // Se registra TODA busqueda, no solo las que fallan.
    //
    // El ingeniero que abandona sin seleccionar nada es el caso
    // que mas interesa, y era justo el que no quedaba
    // registrado: la encuesta solo aparecia despues de generar
    // la salida, lo que obligaba a fingir una seleccion para
    // poder decir que no sirvio.
    nuevoItem.idBusqueda = await registrarBusquedaFallida(
      it.texto, respuesta.nivel, candidatos.length
    );

    solicitudActual.items.push(nuevoItem);
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

  // Cierra el ciclo de la busqueda: se eligio algo
  marcarResuelta(orden, true);
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


// ------------------------------------------------------------
// ampliarItem()
// Amplia los resultados de un item sin perder los que ya
// estaban. Cada ampliacion se registra: es la senal mas
// honesta de que el ranking no acerto, porque no depende de
// que el ingeniero se moleste en escribir un aviso.
// ------------------------------------------------------------
async function ampliarItem(orden) {

  const item = solicitudActual.items.find(function (i) {
    return i.orden === orden;
  });
  if (!item) return;

  const nuevoLimite = Math.min(item.limite + 5, 15);
  const respuesta = await buscar(item.texto, nuevoLimite);

  item.candidatos = respuesta.resultados || [];
  item.limite     = nuevoLimite;
  item.hayMas     = respuesta.hay_mas === true && nuevoLimite < 15;

  if (item.idBusqueda) {
    await db.rpc('registrar_ampliacion', { p_id: item.idBusqueda });
  }
}


// ------------------------------------------------------------
// marcarResuelta()
// Cierra el ciclo: permite saber si la ampliacion sirvio de
// algo o si el ingeniero se rindio.
// ------------------------------------------------------------
async function marcarResuelta(orden, resuelta) {

  const item = solicitudActual.items.find(function (i) {
    return i.orden === orden;
  });
  if (!item || !item.idBusqueda) return;

  await db.rpc('marcar_busqueda_resuelta', {
    p_id: item.idBusqueda,
    p_resuelta: resuelta
  });
}


// ------------------------------------------------------------
// rebuscarItem()
// Cambia el texto de un item y vuelve a buscar SOLO ese.
//
// Antes, si de "cinta, disco de corte y sal" solo fallaba la
// cinta, habia que rehacer la consulta entera y volver a
// elegir lo que ya estaba bien. Cada correccion costaba tres
// selecciones perdidas.
//
// Se conserva el orden para que el item no cambie de sitio, y
// se registra como busqueda nueva: es informacion valiosa
// saber que la primera redaccion no sirvio.
// ------------------------------------------------------------
async function rebuscarItem(orden, textoNuevo) {

  const item = solicitudActual.items.find(function (i) {
    return i.orden === orden;
  });
  if (!item) return;

  const texto = String(textoNuevo || '').trim();
  if (texto === '') return;

  // La busqueda anterior se cierra como no resuelta: el
  // ingeniero tuvo que reformular, y eso es un fallo del motor
  // aunque nadie lo reporte.
  if (item.idBusqueda && item.elegido === null) {
    await marcarResuelta(orden, false);
  }

  const respuesta  = await buscar(texto);
  const candidatos = respuesta.resultados || [];

  item.textoOriginal   = texto;
  item.texto           = texto;
  item.nivel           = respuesta.nivel;
  item.sinInventario   = respuesta.sin_inventario === true;
  item.mensaje         = respuesta.mensaje;
  item.candidatos      = candidatos;
  item.hayMas          = respuesta.hay_mas === true;
  item.limite          = 5;
  item.elegido         = null;
  item.reformulado     = true;

  item.idBusqueda = await registrarBusquedaFallida(
    texto, respuesta.nivel, candidatos.length
  );
}


// ------------------------------------------------------------
// agregarItem()
// Anade un material a la solicitud en curso, sin tocar lo ya
// elegido. Para lo que no se penso al escribir la consulta
// inicial.
// ------------------------------------------------------------
async function agregarItem(texto) {

  if (!solicitudActual) return;

  const limpio = String(texto || '').trim();
  if (limpio === '') return;

  // interpretar() puede devolver varios items: "dos correas y
  // un reten" es una entrada valida aqui tambien.
  const nuevos = interpretar(limpio);

  let siguiente = solicitudActual.items.reduce(function (max, i) {
    return Math.max(max, i.orden);
  }, 0);

  for (let k = 0; k < nuevos.length; k++) {

    const it = nuevos[k];
    siguiente += 1;

    const respuesta  = await buscar(it.texto);
    const candidatos = respuesta.resultados || [];

    const item = {
      orden:           siguiente,
      textoOriginal:   it.textoOriginal,
      texto:           it.texto,
      cantidad:        it.cantidad,
      cantidadAsumida: it.cantidadAsumida,
      nivel:           respuesta.nivel,
      sinInventario:   respuesta.sin_inventario === true,
      mensaje:         respuesta.mensaje,
      candidatos:      candidatos,
      idBusqueda:      null,
      hayMas:          respuesta.hay_mas === true,
      limite:          5,
      elegido:         null
    };

    item.idBusqueda = await registrarBusquedaFallida(
      it.texto, respuesta.nivel, candidatos.length
    );

    solicitudActual.items.push(item);
  }

  // El mensaje original se amplia: la trazabilidad debe
  // reflejar todo lo que se pidio, no solo la primera frase.
  solicitudActual.mensajeOriginal += ' · ' + limpio;
}

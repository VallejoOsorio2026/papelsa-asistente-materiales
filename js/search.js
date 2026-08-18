// ============================================================
// search.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Llama al motor de busqueda y presenta los resultados.
// Toda la logica de busqueda y ranking vive en la base de
// datos. Este archivo solo pide y muestra.
// ============================================================

// ------------------------------------------------------------
// buscar()
// ------------------------------------------------------------
async function buscar(consulta) {

  const { data, error } = await db.rpc('consultar_materiales', {
    p_consulta: consulta,
    p_limite: 5
  });

  if (error) {
    return {
      nivel: 1,
      total: 0,
      mensaje: 'No se pudo completar la busqueda: ' + error.message,
      resultados: []
    };
  }

  return data;
}


// ------------------------------------------------------------
// escapar()
// Evita que el texto del inventario se interprete como HTML.
// ------------------------------------------------------------
function escapar(texto) {
  const d = document.createElement('div');
  d.textContent = (texto === null || texto === undefined) ? '' : String(texto);
  return d.innerHTML;
}


// ------------------------------------------------------------
// textoAmbito()
// RN-019: se distingue disponibilidad inmediata de la que
// exige traslado.
// ------------------------------------------------------------
function textoAmbito(ambito) {
  switch (ambito) {
    case 'molino':  return 'Molino';
    case 'planta':  return 'Planta';
    case 'virtual': return 'Bodega virtual';
    case 'remoto':  return 'Otra sede · requiere traslado';
    default:        return 'Ubicación por confirmar';
  }
}


// ------------------------------------------------------------
// formatearCantidad()
// ------------------------------------------------------------
function formatearCantidad(valor) {
  const n = Number(valor || 0);
  return n.toLocaleString('es-CO', { maximumFractionDigits: 2 });
}


// ============================================================
// SOLICITUD CON VARIOS MATERIALES
// ============================================================

// ------------------------------------------------------------
// pintarSolicitud()
// RN-007: se muestran todos los items a la vez, resueltos y
// pendientes, para preguntar una sola vez.
// ------------------------------------------------------------
function pintarSolicitud(solicitud) {

  if (!solicitud || solicitud.items.length === 0) {
    return '';
  }

  let html = '';

  const pendientes = solicitud.items.filter(function (i) {
    return i.elegido === null;
  }).length;

  if (pendientes === 0) {
    html += '<div class="aviso aviso-ok visible">'
          + '<strong>Todo listo.</strong> '
          + solicitud.items.length + ' material'
          + (solicitud.items.length > 1 ? 'es' : '')
          + ' seleccionado' + (solicitud.items.length > 1 ? 's' : '')
          + '. Genera la salida para SAP.'
          + '</div>';
  } else {
    html += '<div class="aviso aviso-atencion visible">'
          + '<strong>Falta elegir ' + pendientes + ' de '
          + solicitud.items.length + '.</strong> '
          + 'Selecciona el material correcto en cada bloque.'
          + '</div>';
  }

  solicitud.items.forEach(function (item) {
    html += pintarItem(item);
  });

  if (pendientes === 0) {
    html += '<button id="boton-salida" class="boton" '
          + 'style="margin-top:16px">Generar salida para SAP</button>';
  }

  return html;
}


// ------------------------------------------------------------
// pintarItem()
// Cada material es un bloque desplegable con indicador de
// estado: rojo mientras no se elige, verde al elegir.
// ------------------------------------------------------------
function pintarItem(item) {

  const resuelto = item.elegido !== null;
  const abierto  = !resuelto;

  let html = '<div class="item-solicitud' + (resuelto ? ' resuelto' : '')
           + '" data-orden="' + item.orden + '">';

  // ---------- Cabecera desplegable ----------
  html += '<div class="item-cabecera desplegable" data-orden="' + item.orden + '">';

  html += '<span class="indicador ' + (resuelto ? 'verde' : 'rojo') + '"></span>';
  html += '<span class="item-texto">' + escapar(item.textoOriginal) + '</span>';

  if (resuelto) {
    html += '<span class="item-resumen">'
          + '<span class="dato resumen-codigo">'
          + escapar(item.elegido.material) + '</span>'
          + '<span class="resumen-descripcion">'
          + escapar(item.elegido.descripcion) + '</span>'
          + '<span class="dato resumen-almacen">'
          + escapar(item.elegido.centro) + ' · '
          + escapar(item.elegido.almacen) + '</span>'
          + '</span>';
  } else if (item.candidatos.length > 0) {
    html += '<span class="item-resumen">'
          + item.candidatos.length + ' opciones</span>';
  }

  html += '<span class="flecha' + (abierto ? ' abierta' : '') + '">›</span>';
  html += '</div>';

  // ---------- Cuerpo ----------
  html += '<div class="item-cuerpo' + (abierto ? ' visible' : '') + '" '
        + 'id="cuerpo-' + item.orden + '">';

  html += '<div class="item-cantidad">'
        + '<label for="cant-' + item.orden + '">Cantidad</label>'
        + '<input type="number" min="1" step="1" class="dato" '
        + 'id="cant-' + item.orden + '" '
        + 'data-orden="' + item.orden + '" '
        + 'value="' + item.cantidad + '">';

  if (item.cantidadAsumida) {
    html += '<span class="aviso-cantidad">Cantidad asumida. '
          + 'Confírmala si no es correcta.</span>';
  }
  html += '</div>';

  if (item.sinInventario) {
    html += '<div class="aviso aviso-error visible">'
          + escapar(item.mensaje) + '</div></div></div>';
    return html;
  }

  if (item.candidatos.length === 0) {
    html += '<p class="nota-sin-resultado">'
          + escapar(item.mensaje) + '</p>'
          + pintarAvisoBusqueda(item.orden)
          + '</div></div>';
    return html;
  }

  html += '<p class="item-nivel">Nivel de confianza '
        + item.nivel + ' de 5 · ' + escapar(item.mensaje) + '</p>';

    // El aviso esta disponible SIEMPRE, no solo cuando falla.
  // El peor caso no es que el sistema falle y lo sepa, sino que
  // devuelva algo plausible que no es lo que se buscaba: ahi
  // cree que acerto, el ingeniero se va, y no queda rastro.
  const avisoBajo = (item.nivel <= 2);

  item.candidatos.forEach(function (c) {
    const elegido = resuelto && item.elegido.material === c.material;
    const almacen = elegido ? item.elegido.almacen : null;
    html += pintarCandidato(c, item.orden, elegido, almacen);
  });

  html += pintarAvisoBusqueda(item.orden);

  html += '</div></div>';
  return html;
}


// ------------------------------------------------------------
// pintarCandidato()
// RN-033: un material puede existir en varias ubicaciones.
// Una tarjeta por material, con sus ubicaciones ordenadas por
// prioridad (RN-018). Se elige material Y ubicacion.
// RN-034: los marcados para baja se muestran advertidos.
// ------------------------------------------------------------
function pintarCandidato(c, orden, elegido, almacenElegido) {

  const totalDisp = Number(c.total_disponible || 0);
  const totalComp = Number(c.total_comprometido || 0);
  const ubis = c.ubicaciones || [];

  // RN-034: marcado para baja en SAP. Se muestra igual, pero
  // advertido: puede tener stock real en el estante.
  const deBaja = c.dado_de_baja === true;

  let html = '<div class="resultado candidato'
           + (elegido ? ' elegido' : '')
           + (deBaja ? ' de-baja' : '') + '">';

  if (deBaja) {
    html += '<p class="aviso-baja">Marcado para baja en SAP. '
          + 'Verifica antes de solicitarlo.</p>';
  }

  html += '<div class="resultado-cabecera">'
        + '<span class="dato resultado-codigo">' + escapar(c.material) + '</span>'
        + '<span class="resultado-ambito">'
        + ubis.length + (ubis.length === 1 ? ' ubicación' : ' ubicaciones')
        + '</span></div>';

  html += '<p class="resultado-descripcion">'
        + escapar(c.descripcion) + '</p>';

  html += '<div class="linea-estado">'
        + '<span>Disponible en total</span>'
        + '<span class="dato' + (totalDisp > 0 ? ' valor-ok' : ' valor-cero') + '">'
        + formatearCantidad(totalDisp) + ' ' + escapar(c.unidad || '')
        + '</span></div>';

  if (totalComp > 0) {
    html += '<div class="linea-estado">'
          + '<span>En proyectos</span>'
          + '<span class="dato valor-alerta">'
          + formatearCantidad(totalComp) + ' ' + escapar(c.unidad || '')
          + '</span></div>';
  }

  if (c.material_antiguo) {
    html += '<div class="linea-estado">'
          + '<span>Código antiguo</span>'
          + '<span class="dato">' + escapar(c.material_antiguo) + '</span></div>';
  }

  html += '<p class="titulo-ubicaciones">Elige de dónde se retira:</p>';

  ubis.forEach(function (u) {

    const disp  = Number(u.disponible || 0);
    const comp  = Number(u.comprometido || 0);
    const clave = c.material + '|' + u.centro + '|' + u.almacen;
    const activa = elegido && almacenElegido === u.almacen;

    html += '<div class="ubicacion' + (activa ? ' activa' : '') + '" '
          + 'data-orden="' + orden + '" '
          + 'data-clave="' + escapar(clave) + '">';

    html += '<div class="ubicacion-fila">'
          + '<span class="dato">' + escapar(u.centro) + ' · '
          + escapar(u.almacen) + '</span>'
          + '<span class="ubicacion-ambito">' + textoAmbito(u.ambito) + '</span>'
          + '</div>';

    html += '<div class="ubicacion-fila">'
          + '<span class="dato' + (disp > 0 ? ' valor-ok' : ' valor-cero') + '">'
          + formatearCantidad(disp) + ' ' + escapar(c.unidad || '') + '</span>';

    if (comp > 0) {
      html += '<span class="dato valor-alerta">'
            + formatearCantidad(comp) + ' en proyectos</span>';
    }

    html += '</div>';

    if (u.ubicacion) {
      html += '<div class="ubicacion-detalle">'
            + escapar(u.ubicacion) + '</div>';
    }

    html += '</div>';
  });

  if (totalComp > 0 && totalDisp === 0) {
    html += '<p class="nota-comprometido">'
          + 'Sin stock libre. Todo el material está comprometido por '
          + 'proyectos: habría que identificar a quién está asignado y '
          + 'valorar prioridades.</p>';
  }

  html += '</div>';
  return html;
}

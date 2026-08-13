// ============================================================
// search.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Llama al motor de busqueda y prepara los resultados para
// mostrarlos en pantalla.
//
// Toda la logica de busqueda y ranking vive en la base de
// datos. Este archivo solo pide y presenta.
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
// textoAmbito()
// RN-019: se distingue con claridad entre disponibilidad
// inmediata y disponibilidad que exige traslado.
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


// ------------------------------------------------------------
// pintarResultados()
// Construye el HTML de la lista de materiales encontrados.
// ------------------------------------------------------------
function pintarResultados(respuesta) {

  const nivel = respuesta.nivel;
  const filas = respuesta.resultados || [];

  let html = '';

  // Aviso del nivel de confianza
  const clase = nivel >= 4 ? 'aviso-ok'
              : nivel >= 2 ? 'aviso-atencion'
              : 'aviso-error';

  html += '<div class="aviso ' + clase + ' visible">'
        + '<strong>Nivel de confianza ' + nivel + ' de 5.</strong> '
        + escapar(respuesta.mensaje)
        + '</div>';

  if (filas.length === 0) {
    return html;
  }

  filas.forEach(function (r) {

    const disponible   = Number(r.disponible || 0);
    const comprometido = Number(r.comprometido || 0);

    html += '<div class="resultado">';

    html += '<div class="resultado-cabecera">'
          + '<span class="dato resultado-codigo">' + escapar(r.material) + '</span>'
          + '<span class="resultado-ambito">' + textoAmbito(r.ambito) + '</span>'
          + '</div>';

    html += '<p class="resultado-descripcion">'
          + escapar(r.descripcion) + '</p>';

    // RN-030: disponible
    html += '<div class="linea-estado">'
          + '<span>Disponible</span>'
          + '<span class="dato' + (disponible > 0 ? ' valor-ok' : ' valor-cero') + '">'
          + formatearCantidad(disponible) + ' ' + escapar(r.unidad || '')
          + '</span></div>';

    // RN-030: comprometido, solo si existe
    if (comprometido > 0) {
      html += '<div class="linea-estado">'
            + '<span>En proyectos</span>'
            + '<span class="dato valor-alerta">'
            + formatearCantidad(comprometido) + ' ' + escapar(r.unidad || '')
            + '</span></div>'
            + '<p class="nota-comprometido">'
            + 'Este material existe pero está comprometido por un proyecto. '
            + 'Para usarlo habría que identificar a quién está asignado y '
            + 'valorar prioridades.</p>';
    }

    html += '<div class="linea-estado">'
          + '<span>Centro · Almacén</span>'
          + '<span class="dato">' + escapar(r.centro) + ' · '
          + escapar(r.almacen) + '</span></div>';

    if (r.ubicacion) {
      html += '<div class="linea-estado">'
            + '<span>Ubicación</span>'
            + '<span class="dato">' + escapar(r.ubicacion) + '</span></div>';
    }

    if (r.material_antiguo) {
      html += '<div class="linea-estado">'
            + '<span>Código antiguo</span>'
            + '<span class="dato">' + escapar(r.material_antiguo) + '</span></div>';
    }

    html += '<div class="linea-estado">'
          + '<span>Coincidencia por</span>'
          + '<span>' + escapar(r.origen) + '</span></div>';

    html += '</div>';
  });

  return html;
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
// ============================================================
// PRESENTACION DE UNA SOLICITUD CON VARIOS MATERIALES
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

  // Resumen del estado
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
// ------------------------------------------------------------
function pintarItem(item) {

  const resuelto = item.elegido !== null;

  let html = '<div class="item-solicitud' + (resuelto ? ' resuelto' : '') + '">';

  // Cabecera del item
  html += '<div class="item-cabecera">'
        + '<span class="item-numero">' + item.orden + '</span>'
        + '<span class="item-texto">' + escapar(item.textoOriginal) + '</span>'
        + '</div>';

  // Cantidad editable
  html += '<div class="item-cantidad">'
        + '<label for="cant-' + item.orden + '">Cantidad</label>'
        + '<input type="number" min="1" step="1" class="dato" '
        + 'id="cant-' + item.orden + '" '
        + 'data-orden="' + item.orden + '" '
        + 'value="' + item.cantidad + '">';

  // RN-004: la cantidad asumida se advierte de forma visible
  if (item.cantidadAsumida) {
    html += '<span class="aviso-cantidad">Cantidad asumida. '
          + 'Confírmala si no es correcta.</span>';
  }

  html += '</div>';

  if (item.candidatos.length === 0) {
    html += '<p class="nota-sin-resultado">'
          + escapar(item.mensaje) + '</p></div>';
    return html;
  }

  html += '<p class="item-nivel">Nivel de confianza '
        + item.nivel + ' de 5 · ' + escapar(item.mensaje) + '</p>';

  item.candidatos.forEach(function (c) {
    const elegido = resuelto && item.elegido.material === c.material;
    html += pintarCandidato(c, item.orden, elegido);
  });

  html += '</div>';
  return html;
}


// ------------------------------------------------------------
// pintarCandidato()
// ------------------------------------------------------------
function pintarCandidato(c, orden, elegido) {

  const disponible   = Number(c.disponible || 0);
  const comprometido = Number(c.comprometido || 0);

  let html = '<div class="resultado candidato' + (elegido ? ' elegido' : '') + '" '
           + 'data-orden="' + orden + '" '
           + 'data-material="' + escapar(c.material) + '">';

  html += '<div class="resultado-cabecera">'
        + '<span class="dato resultado-codigo">' + escapar(c.material) + '</span>'
        + '<span class="resultado-ambito">' + textoAmbito(c.ambito) + '</span>'
        + '</div>';

  html += '<p class="resultado-descripcion">'
        + escapar(c.descripcion) + '</p>';

  html += '<div class="linea-estado">'
        + '<span>Disponible</span>'
        + '<span class="dato' + (disponible > 0 ? ' valor-ok' : ' valor-cero') + '">'
        + formatearCantidad(disponible) + ' ' + escapar(c.unidad || '')
        + '</span></div>';

  if (comprometido > 0) {
    html += '<div class="linea-estado">'
          + '<span>En proyectos</span>'
          + '<span class="dato valor-alerta">'
          + formatearCantidad(comprometido) + ' ' + escapar(c.unidad || '')
          + '</span></div>'
          + '<p class="nota-comprometido">'
          + 'Comprometido por un proyecto. Para usarlo habría que '
          + 'identificar a quién está asignado y valorar prioridades.'
          + '</p>';
  }

  html += '<div class="linea-estado">'
        + '<span>Centro · Almacén</span>'
        + '<span class="dato">' + escapar(c.centro) + ' · '
        + escapar(c.almacen) + '</span></div>';

  if (c.ubicacion) {
    html += '<div class="linea-estado">'
          + '<span>Ubicación</span>'
          + '<span class="dato">' + escapar(c.ubicacion) + '</span></div>';
  }

  html += '<div class="candidato-accion">'
        + (elegido ? '✓ Seleccionado · pulsa para quitar' : 'Seleccionar')
        + '</div>';

  html += '</div>';
  return html;
}

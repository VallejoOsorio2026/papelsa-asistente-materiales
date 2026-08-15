// ============================================================
// feedback.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Guarda la solicitud en la base de datos y gestiona la
// encuesta de utilidad.
//
// El registro ocurre al generar la salida para SAP: es el
// momento en que la solicitud queda realmente resuelta.
// ============================================================

// Identificador de la ultima solicitud guardada, para poder
// asociarle el feedback.
let solicitudGuardadaId = null;


// ------------------------------------------------------------
// guardarSolicitud()
// RN-011 y trazabilidad: se guardan todos los candidatos
// mostrados, no solo el elegido.
// ------------------------------------------------------------
async function guardarSolicitud(solicitud, ms) {

  const items = solicitud.items.map(function (i) {
    return {
      orden:           i.orden,
      textoOriginal:   i.textoOriginal,
      cantidad:        i.cantidad,
      cantidadAsumida: i.cantidadAsumida,
      nivel:           i.nivel,
      candidatos:      i.candidatos,
      elegido:         i.elegido
    };
  });

  const { data, error } = await db.rpc('registrar_solicitud', {
    p_mensaje: solicitud.mensajeOriginal,
    p_items: items,
    p_ms: ms || null
  });

  if (error) {
    // No se interrumpe el trabajo del ingeniero por un fallo
    // de registro: la salida para SAP ya esta generada.
    console.error('No se pudo registrar la solicitud:', error.message);
    return null;
  }

  solicitudGuardadaId = data;
  return data;
}


// ------------------------------------------------------------
// enviarFeedback()
// ------------------------------------------------------------
async function enviarFeedback(util) {

  if (!solicitudGuardadaId) return false;

  const { error } = await db.rpc('registrar_feedback', {
    p_solicitud_id: solicitudGuardadaId,
    p_util: util,
    p_comentario: null
  });

  if (error) {
    console.error('No se pudo registrar el feedback:', error.message);
    return false;
  }

  return true;
}


// ------------------------------------------------------------
// pintarEncuesta()
// RN-029: opcional, y no bloquea una nueva consulta.
// ------------------------------------------------------------
function pintarEncuesta() {
  return '<div class="encuesta" id="encuesta">'
       + '<span class="encuesta-pregunta">¿Te fue útil?</span>'
       + '<button class="boton boton-discreto" id="feedback-si">Sí</button>'
       + '<button class="boton boton-discreto" id="feedback-no">No</button>'
       + '</div>';
}


// ------------------------------------------------------------
// obtenerHistorial()
// ------------------------------------------------------------
async function obtenerHistorial(limite) {

  const { data, error } = await db.rpc('mi_historial', {
    p_limite: limite || 10
  });

  if (error) {
    console.error('No se pudo leer el historial:', error.message);
    return [];
  }

  return data || [];
}
// ============================================================
// BUSQUEDAS SIN RESULTADO UTIL
// ============================================================
// Se registran automaticamente. El aviso manual del ingeniero
// anade contexto, pero el dato base se captura solo.
// ============================================================

// Identificadores por orden de item, para asociar el reporte.
let busquedasFallidas = {};
// ------------------------------------------------------------
// registrarBusquedaFallida()
// Devuelve el identificador para que quien llama lo guarde.
// ------------------------------------------------------------
async function registrarBusquedaFallida(consulta, nivel, total) {

  const { data, error } = await db.rpc('registrar_busqueda_fallida', {
    p_consulta: consulta,
    p_nivel: nivel || null,
    p_total: total || 0
  });

  if (error) {
    console.error('No se pudo registrar la busqueda:', error.message);
    return null;
  }

  return data;
}


// ------------------------------------------------------------
// reportarBusqueda()
// ------------------------------------------------------------
async function reportarBusqueda(idBusqueda, esperaba) {

  if (!idBusqueda) {
    console.error('No hay registro de busqueda al que asociar el aviso.');
    return false;
  }

  const { data, error } = await db.rpc('reportar_busqueda', {
    p_id: idBusqueda,
    p_esperaba: esperaba,
    p_comentario: null
  });

  if (error) {
    console.error('No se pudo enviar el aviso:', error.message);
    return false;
  }

  return data === true;
}
// ------------------------------------------------------------
// pintarAvisoBusqueda()
// Aparece cuando no hay resultados o cuando la confianza es
// baja: es el momento en que el ingeniero esta a punto de
// abandonar y su informacion vale mas.
// ------------------------------------------------------------
function pintarAvisoBusqueda(orden) {
  return '<div class="reporte-busqueda" data-orden="' + orden + '">'
       + '<p class="reporte-titulo">¿No encontraste lo que buscabas?</p>'
       + '<p class="reporte-ayuda">Dinos qué material esperabas. '
       + 'Sirve para corregir el buscador.</p>'
       + '<div class="reporte-campos">'
       + '<input type="text" class="reporte-texto" '
       + 'id="reporte-texto-' + orden + '" '
       + 'placeholder="Ej: cinta aislante 3M negra">'
       + '<button class="boton boton-discreto reporte-enviar" '
       + 'data-orden="' + orden + '">Avisar</button>'
       + '</div></div>';
}
// ============================================================
// HISTORIAL
// ============================================================

// ------------------------------------------------------------
// pintarHistorial()
// Trazabilidad para el ingeniero: que pidio, cuando y si quedo
// resuelto. Las politicas de seguridad ya impiden ver las
// consultas de otros.
// ------------------------------------------------------------
function pintarHistorial(filas) {

  if (!filas || filas.length === 0) {
    return '<p class="ayuda-buscador">Todavía no hay consultas registradas.</p>';
  }

  let html = '';

  filas.forEach(function (s) {

    const fecha = new Date(s.creada_en).toLocaleString('es-CO', {
      day: '2-digit', month: 'short',
      hour: '2-digit', minute: '2-digit'
    });

    const completa = s.resueltos === s.total_items;

    html += '<div class="historial-fila">';

    html += '<span class="indicador '
          + (completa ? 'verde' : 'rojo') + '"></span>';

    html += '<span class="historial-texto">'
          + escapar(s.mensaje_original) + '</span>';

    html += '<span class="historial-meta">'
          + s.resueltos + ' de ' + s.total_items
          + (s.estado === 'incompleta' ? ' · cerrada por inactividad' : '')
          + '<br>' + fecha
          + (s.util === true  ? ' · útil' : '')
          + (s.util === false ? ' · no fue útil' : '')
          + '</span>';

    html += '</div>';
  });

  return html;
}


// ------------------------------------------------------------
// cargarHistorial()
// ------------------------------------------------------------
async function cargarHistorial() {
  const destino = document.getElementById('lista-historial');
  if (!destino) return;

  destino.innerHTML = '<p class="ayuda-buscador">Cargando…</p>';
  const filas = await obtenerHistorial(10);
  destino.innerHTML = pintarHistorial(filas);
}

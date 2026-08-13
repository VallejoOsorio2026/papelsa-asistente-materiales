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

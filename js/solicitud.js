// ============================================================
// solicitud.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Envio de solicitudes por parte de mecanicos y contratistas.
//
// Ellos no deciden el material desde SAP: lo buscan aqui, lo
// eligen y lo envian al ingeniero, que sigue siendo quien
// autoriza (RN-024).
//
// El nombre se pide en cada solicitud porque la cuenta puede
// ser compartida entre varias personas de mantenimiento. Sin
// eso, el registro diria "mecanico" en todas y se perderia la
// trazabilidad.
// ============================================================

// ------------------------------------------------------------
// esSolicitante()
// ------------------------------------------------------------
function esSolicitante() {
  return perfilActual !== null
      && (perfilActual.rol === 'mecanico'
       || perfilActual.rol === 'contratista');
}


// ------------------------------------------------------------
// pintarFormularioSolicitud()
// ------------------------------------------------------------
function pintarFormularioSolicitud(solicitud) {

  const total = solicitud.items.filter(function (i) {
    return i.elegido !== null;
  }).length;

  if (total === 0) return '';

  let html = '<div class="panel bloque-solicitud" id="bloque-solicitud">';
  html += '<h2>Enviar solicitud de materiales</h2>';

  html += '<p class="ayuda-buscador">'
        + total + ' material' + (total > 1 ? 'es' : '')
        + ' seleccionado' + (total > 1 ? 's' : '')
        + '. Se avisará a los ingenieros de tu área.</p>';

  html += '<div id="aviso-solicitud" class="aviso"></div>';

  html += '<div class="campo">'
        + '<label for="sol-nombre">Tu nombre completo</label>'
        + '<input type="text" id="sol-nombre" autocomplete="name" '
        + 'placeholder="Nombre y apellido">'
        + '</div>';

  html += '<div class="campo">'
        + '<label for="sol-orden">Orden de trabajo</label>'
        + '<input type="text" id="sol-orden" class="dato" '
        + 'inputmode="numeric" maxlength="7" '
        + 'placeholder="7 dígitos">'
        + '<span class="ayuda-campo">Siete dígitos, sin letras '
        + 'ni símbolos.</span>'
        + '</div>';

  html += '<button class="boton" id="boton-enviar-solicitud">'
        + 'Enviar solicitud</button>';

  html += '<button class="boton boton-discreto" id="boton-excel" '
        + 'style="margin-top:10px">Descargar Excel</button>';

  html += '</div>';
  return html;
}


// ------------------------------------------------------------
// validarOrden()
// Se valida aqui y tambien en la base de datos: una
// comprobacion que solo vive en el navegador no protege nada.
// ------------------------------------------------------------
function validarOrden(valor) {
  return /^[0-9]{7}$/.test(String(valor || '').trim());
}


// ------------------------------------------------------------
// enviarSolicitudMateriales()
// ------------------------------------------------------------
async function enviarSolicitudMateriales(solicitante, orden) {

  const materiales = construirFilasSAP(solicitudActual).map(function (f) {
    return {
      componente:  f[0],
      denominacion:f[1],
      cantidad:    f[2],
      um:          f[3],
      t:           f[4],
      s:           f[5],
      almacen:     f[6],
      centro:      f[7]
    };
  });

  const { data, error } = await db.rpc('enviar_solicitud_materiales', {
    p_solicitante: solicitante,
    p_orden: orden,
    p_materiales: materiales
  });

  if (error) {
    return { ok: false, mensaje: 'No se pudo enviar: ' + error.message };
  }

  return data;
}

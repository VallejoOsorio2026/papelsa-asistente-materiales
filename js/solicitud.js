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


// ============================================================
// BANDEJA DEL INGENIERO
// ============================================================
// Las solicitudes se ven aqui aunque el correo falle o caiga
// en spam. El correo es el aviso; esta bandeja es el registro.
// ============================================================

// ------------------------------------------------------------
// recibeSolicitudes()
// ------------------------------------------------------------
function recibeSolicitudes() {
  return perfilActual !== null
      && (perfilActual.recibe_solicitudes === true
       || perfilActual.rol === 'admin');
}


// ------------------------------------------------------------
// obtenerBandeja()
// ------------------------------------------------------------
async function obtenerBandeja() {
  const { data, error } = await db.rpc('solicitudes_pendientes', {
    p_limite: 20
  });
  if (error) {
    console.error('No se pudo leer la bandeja:', error.message);
    return [];
  }
  return data || [];
}


// ------------------------------------------------------------
// pintarBandeja()
// ------------------------------------------------------------
function pintarBandeja(filas) {

  if (!filas || filas.length === 0) {
    return '<p class="ayuda-buscador">No hay solicitudes pendientes.</p>';
  }

  let html = '';

  filas.forEach(function (s) {

    const fecha = new Date(s.creada_en).toLocaleString('es-CO', {
      day: '2-digit', month: 'short',
      hour: '2-digit', minute: '2-digit'
    });

    const nueva = s.estado === 'nueva';

    html += '<div class="solicitud-fila' + (nueva ? ' nueva' : '') + '">';

    html += '<div class="solicitud-cabecera">'
          + '<span class="solicitud-orden-grupo">'
          + '<span class="dato solicitud-orden">OT '
          + escapar(s.orden_trabajo) + '</span>'
          + '<button class="copiar-orden" '
          + 'data-orden="' + escapar(s.orden_trabajo) + '" '
          + 'title="Copiar número de orden" '
          + 'aria-label="Copiar número de orden">⧉</button>'
          + '</span>'
          + '<span class="solicitud-fecha">' + fecha + '</span>'
          + '</div>';

    html += '<p class="solicitud-quien">'
          + escapar(s.solicitante)
          + ' <span class="etiqueta-rol">'
          + escapar(s.rol_solicitante) + '</span></p>';

    // Materiales pedidos
    html += '<div class="solicitud-materiales">';
    (s.materiales || []).forEach(function (m) {
      html += '<div class="linea-estado">'
            + '<span><span class="dato">' + escapar(m.componente)
            + '</span> · ' + escapar(m.denominacion) + '</span>'
            + '<span class="dato">' + escapar(m.cantidad) + ' '
            + escapar(m.um) + ' · ' + escapar(m.centro) + '/'
            + escapar(m.almacen) + '</span></div>';
    });
    html += '</div>';

    // El correo puede no haberse enviado todavia
    if (s.estado_correo === 'pendiente') {
      html += '<p class="ayuda-campo">Aviso por correo pendiente de envío.</p>';
    }

    html += '<div class="solicitud-acciones">'
          + '<button class="boton boton-discreto bandeja-salida" '
          + 'data-id="' + escapar(s.id) + '">Ver salida SAP</button>'
          + '<button class="boton boton-discreto bandeja-atender" '
          + 'data-id="' + escapar(s.id) + '">Marcar atendida</button>'
          + '</div>';

    html += '</div>';
  });

  return html;
}


// ------------------------------------------------------------
// cargarBandeja()
// ------------------------------------------------------------
async function cargarBandeja() {
  const destino = document.getElementById('lista-bandeja');
  if (!destino) return;

  destino.innerHTML = '<p class="ayuda-buscador">Cargando…</p>';
  const filas = await obtenerBandeja();
  destino.innerHTML = pintarBandeja(filas);

  const contador = document.getElementById('contador-bandeja');
  if (contador) {
    const nuevas = filas.filter(function (s) {
      return s.estado === 'nueva';
    }).length;
    contador.textContent = nuevas > 0 ? nuevas : '';
    contador.style.display = nuevas > 0 ? 'inline-flex' : 'none';
  }
}


// ------------------------------------------------------------
// salidaDeSolicitudMateriales()
// Convierte la solicitud recibida al formato de la salida SAP.
// ------------------------------------------------------------
function salidaDeSolicitudMateriales(materiales) {
  return {
    items: (materiales || []).map(function (m, i) {
      return {
        orden: i + 1,
        cantidad: m.cantidad,
        cantidadAsumida: false,
        elegido: {
          material:    m.componente,
          descripcion: m.denominacion,
          unidad:      m.um,
          centro:      m.centro,
          almacen:     m.almacen
        }
      };
    })
  };
}

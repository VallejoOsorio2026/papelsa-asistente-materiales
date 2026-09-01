// ============================================================
// solicitud.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Envio de solicitudes por parte de mecanicos y contratistas,
// y bandeja de quienes las reciben.
//
// Ellos no deciden el material desde SAP: lo buscan aqui, lo
// eligen y lo envian al ingeniero, que sigue siendo quien
// autoriza (RN-024).
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
// El nombre se pide en cada solicitud porque la cuenta puede
// ser compartida entre varias personas. Sin eso, el registro
// diria "mecanico" en todas y se perderia la trazabilidad.
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

  // La orden de trabajo es OPCIONAL: en planta no siempre se
  // tiene el dato al pedir el material, y exigirla impedia
  // registrar solicitudes reales. Si se escribe, debe ser
  // valida: una orden mal tecleada es peor que ninguna.
  html += '<div class="campo">'
        + '<label for="sol-orden">Orden de trabajo '
        + '<span class="etiqueta-opcional">opcional</span></label>'
        + '<input type="text" id="sol-orden" class="dato" '
        + 'inputmode="numeric" maxlength="8" '
        + 'placeholder="8 dígitos">'
        + '<span class="ayuda-campo">Si no la tienes a mano, déjala '
        + 'vacía y envía la solicitud igual.</span>'
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
//
// Vacia se considera VALIDA (orden opcional). Con contenido,
// deben ser exactamente 7 digitos.
// ------------------------------------------------------------
function validarOrden(valor) {
  const v = String(valor || '').trim();
  if (v === '') return true;
  return /^[0-9]{8}$/.test(v);
}


// ------------------------------------------------------------
// hayOrden()
// Distingue "vacia y valida" de "escrita y valida".
// ------------------------------------------------------------
function hayOrden(valor) {
  return String(valor || '').trim() !== '';
}


// ------------------------------------------------------------
// enviarSolicitudMateriales()
// ------------------------------------------------------------
async function enviarSolicitudMateriales(solicitante, orden) {

  const materiales = construirFilasSAP(solicitudActual).map(function (f) {
    return {
      componente:   f[0],
      denominacion: f[1],
      cantidad:     f[2],
      um:           f[3],
      t:            f[4],
      s:            f[5],
      almacen:      f[6],
      centro:       f[7]
    };
  });

  const { data, error } = await db.rpc('enviar_solicitud_materiales', {
    p_solicitante: solicitante,
    p_orden: hayOrden(orden) ? String(orden).trim() : null,
    p_materiales: materiales
  });

  if (error) {
    return { ok: false, mensaje: 'No se pudo enviar: ' + error.message };
  }

  // Envio inmediato: un mecanico de madrugada no puede esperar
  // a que una tarea programada revise la cola. Si falla, la
  // solicitud queda en cola y se reintenta.
  if (data.ok && data.id) {
    try {
      const envio = await db.functions.invoke('enviar-correo', {
        body: { solicitud_id: data.id }
      });
      data.correo = envio.data || { ok: false };
    } catch (e) {
      console.error('El aviso por correo quedo en cola:', e);
      data.correo = { ok: false, sin_servicio: true };
    }
  }

  return data;
}


// ============================================================
// BANDEJA DE QUIEN RECIBE
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
    const conOrden = s.orden_trabajo !== null
                  && s.orden_trabajo !== undefined
                  && String(s.orden_trabajo).trim() !== '';

    html += '<div class="solicitud-fila' + (nueva ? ' nueva' : '') + '">';

    html += '<div class="solicitud-cabecera">'
          + '<span class="solicitud-orden-grupo">';

    // Sin orden de trabajo se avisa de forma visible: el
    // ingeniero puede necesitarla para la reserva en SAP.
    if (conOrden) {
      html += '<span class="dato solicitud-orden">OT '
            + escapar(s.orden_trabajo) + '</span>'
            + '<button class="copiar-orden" '
            + 'data-orden="' + escapar(s.orden_trabajo) + '" '
            + 'title="Copiar número de orden" '
            + 'aria-label="Copiar número de orden">⧉</button>';
    } else {
      html += '<span class="solicitud-sin-orden">sin orden de trabajo</span>';
    }

    html += '</span>'
          + '<span class="solicitud-fecha">' + fecha + '</span>'
          + '</div>';

    html += '<p class="solicitud-quien">'
          + escapar(s.solicitante)
          + ' <span class="etiqueta-rol">'
          + escapar(s.rol_solicitante) + '</span></p>';

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

    if (s.estado_correo === 'pendiente'
        || s.estado_correo === 'sin_servicio') {
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

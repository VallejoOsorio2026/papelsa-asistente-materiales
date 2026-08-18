// ============================================================
// feedback.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Registro de solicitudes, encuesta de utilidad, avisos de
// busqueda, historial y metricas.
// ============================================================

let solicitudGuardadaId = null;


// ============================================================
// REGISTRO DE LA SOLICITUD
// ============================================================

// ------------------------------------------------------------
// guardarSolicitud()
// Se guardan todos los candidatos mostrados, no solo el
// elegido: es lo que permite auditar un error meses despues.
// ------------------------------------------------------------
async function guardarSolicitud(solicitud, ms) {

  // El tiempo viaja en el propio objeto: asi no depende de que
  // quien llama lo pase correctamente.
  const tiempo = ms || solicitud.tiempoMs || null;

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
    p_ms: tiempo
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


// ============================================================
// ENCUESTA DE UTILIDAD (RN-029)
// ============================================================

// ------------------------------------------------------------
// enviarFeedback()
// ------------------------------------------------------------
async function enviarFeedback(util, motivo, esperado) {

  if (!solicitudGuardadaId) return false;

  const { error } = await db.rpc('registrar_feedback', {
    p_solicitud_id: solicitudGuardadaId,
    p_util: util,
    p_comentario: null,
    p_motivo: motivo || null,
    p_esperado: esperado || null
  });

  if (error) {
    console.error('No se pudo registrar el feedback:', error.message);
    return false;
  }

  return true;
}


// ------------------------------------------------------------
// pintarEncuesta()
// Opcional, y no bloquea una nueva consulta.
// ------------------------------------------------------------
function pintarEncuesta() {
  return '<div class="encuesta" id="encuesta">'
       + '<span class="encuesta-pregunta">¿Te fue útil?</span>'
       + '<button class="boton boton-discreto" id="feedback-si">Sí</button>'
       + '<button class="boton boton-discreto" id="feedback-no">No</button>'
       + '</div>'
       + '<div class="detalle-fallo" id="detalle-fallo"></div>';
}


// ------------------------------------------------------------
// pintarDetalleFallo()
// Saber que algo fallo no sirve si no se sabe QUE fallo.
// Los motivos salen de los modos de fallo observados en el
// piloto, no de categorias genericas.
// ------------------------------------------------------------
function pintarDetalleFallo() {

  const motivos = [
    ['no_estaba',      'El material que buscaba no apareció'],
    ['orden_malo',     'Apareció, pero muy abajo en la lista'],
    ['datos_erroneos', 'El stock o la ubicación no coincidían'],
    ['no_entendio',    'Interpretó mal lo que escribí'],
    ['otro',           'Otro motivo']
  ];

  let html = '<div class="panel bloque-fallo">';
  html += '<p class="reporte-titulo">¿Qué falló?</p>';
  html += '<p class="reporte-ayuda">Ayuda a corregir el buscador. '
        + 'Toma unos segundos.</p>';

  html += '<div class="motivos">';
  motivos.forEach(function (m) {
    html += '<button class="boton boton-discreto motivo-fallo" '
          + 'data-motivo="' + m[0] + '">' + m[1] + '</button>';
  });
  html += '</div>';

  html += '<div class="campo" style="margin-top:14px">'
        + '<label for="esperado">¿Qué material esperabas? '
        + '(opcional)</label>'
        + '<input type="text" id="esperado" '
        + 'placeholder="Ej: disco de pulidora pequeño, el de 4 1/2">'
        + '</div>';

  html += '<button class="boton" id="enviar-fallo">Enviar</button>';
  html += '</div>';

  return html;
}


// ============================================================
// AVISO DE BUSQUEDA
// ============================================================
// Disponible SIEMPRE, no solo cuando la busqueda falla.
//
// El peor caso no es que el sistema falle y lo sepa, sino que
// devuelva algo plausible que no es lo que el ingeniero
// buscaba: ahi el sistema cree que acerto, el ingeniero se va,
// y no queda rastro.
// ============================================================

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
async function reportarBusqueda(idBusqueda, esperaba, motivo) {

  if (!idBusqueda) {
    console.error('No hay registro de busqueda al que asociar el aviso.');
    return false;
  }

  const { data, error } = await db.rpc('reportar_busqueda', {
    p_id: idBusqueda,
    p_esperaba: esperaba || null,
    p_comentario: motivo || null
  });

  if (error) {
    console.error('No se pudo enviar el aviso:', error.message);
    return false;
  }

  return data === true;
}


// ------------------------------------------------------------
// pintarAvisoBusqueda()
// Se muestra plegado para no estorbar cuando todo va bien.
// ------------------------------------------------------------
function pintarAvisoBusqueda(orden) {

  const motivos = [
    ['no_estaba',      'No aparece el que busco'],
    ['orden_malo',     'Aparece, pero muy abajo'],
    ['datos_erroneos', 'El stock o la ubicación no cuadran'],
    ['no_entendio',    'Interpretó mal lo que escribí'],
    ['otro',           'Otro motivo']
  ];

  let html = '<div class="reporte-busqueda" data-orden="' + orden + '">';

  html += '<button class="abrir-reporte" data-orden="' + orden + '">'
        + '¿No es esto lo que buscabas?</button>';

  html += '<div class="reporte-cuerpo" id="reporte-cuerpo-' + orden + '">';

  html += '<p class="reporte-ayuda">Cuéntanos qué pasó. '
        + 'Es la forma más directa de corregir el buscador.</p>';

  html += '<div class="motivos">';
  motivos.forEach(function (m) {
    html += '<button class="boton boton-discreto motivo-busqueda" '
          + 'data-orden="' + orden + '" '
          + 'data-motivo="' + m[0] + '">' + m[1] + '</button>';
  });
  html += '</div>';

  html += '<div class="campo" style="margin:12px 0 10px">'
        + '<label for="reporte-texto-' + orden + '">'
        + '¿Qué material esperabas? (opcional)</label>'
        + '<input type="text" class="reporte-texto" '
        + 'id="reporte-texto-' + orden + '" '
        + 'placeholder="Ej: disco de pulidora pequeño, el de 4 1/2">'
        + '</div>';

  html += '<button class="boton boton-discreto reporte-enviar" '
        + 'data-orden="' + orden + '">Enviar</button>';

  html += '</div></div>';
  return html;
}


// ============================================================
// HISTORIAL
// ============================================================

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


// ------------------------------------------------------------
// pintarHistorial()
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

    // Solo tiene sentido recuperar la salida si hubo algo elegido
    if (s.resueltos > 0) {
      html += '<button class="boton boton-discreto historial-salida" '
            + 'data-id="' + escapar(s.id) + '">Ver salida SAP</button>';
    }

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


// ------------------------------------------------------------
// recuperarSalida()
// El ingeniero copio la salida y perdio la ventana, o se
// equivoco al pegar. Los datos ya estan guardados.
// ------------------------------------------------------------
async function recuperarSalida(solicitudId) {

  const { data, error } = await db.rpc('salida_de_solicitud', {
    p_solicitud_id: solicitudId
  });

  if (error || !data || data.ok !== true) {
    return null;
  }

  return {
    items: (data.items || []).map(function (f) {
      return {
        orden: f.orden,
        cantidad: f.cantidad,
        cantidadAsumida: f.cantidad_asumida === true,
        elegido: {
          material:    f.material,
          descripcion: f.descripcion,
          unidad:      f.unidad,
          centro:      f.centro,
          almacen:     f.almacen
        }
      };
    })
  };
}


// ============================================================
// METRICAS DEL PILOTO
// ============================================================
// El tiempo ahorrado no se estima: se cuenta el volumen. El
// valor por consulta se aplicara cuando exista una medicion
// real del tiempo que hoy toma buscar en SAP.
// ============================================================

async function obtenerMetricas(dias) {
  const { data, error } = await db.rpc('metricas_piloto', {
    p_dias: dias || 30
  });
  if (error) {
    console.error('No se pudieron leer las metricas:', error.message);
    return null;
  }
  return data;
}


function filaMetrica(etiqueta, valor, destacada) {
  return '<div class="linea-estado' + (destacada ? ' destacada' : '') + '">'
       + '<span>' + etiqueta + '</span>'
       + '<span class="dato">' + valor + '</span></div>';
}


function pintarMetricas(m) {

  if (!m) return '<p class="ayuda-buscador">No se pudieron cargar.</p>';

  const franja = m.por_franja || {};
  const niveles = m.por_nivel_confianza || {};
  const total = m.solicitudes_total || 0;

  const laboral = franja.laboral || 0;
  const fuera   = m.fuera_horario_ingenieria || 0;
  const pct     = total > 0 ? Math.round(fuera * 100 / total) : 0;

  const altos = (niveles['4'] || 0) + (niveles['5'] || 0);
  const items = m.materiales_total || 0;
  const pctAltos = items > 0 ? Math.round(altos * 100 / items) : 0;

  let html = '<h3 class="metricas-titulo">Uso</h3>';
  html += filaMetrica('Consultas realizadas', total);
  html += filaMetrica('Materiales consultados', items);
  html += filaMetrica('Usuarios activos', m.usuarios_activos || 0);

  html += '<h3 class="metricas-titulo">Cobertura fuera de horario</h3>';
  html += filaMetrica('Fuera del horario de ingeniería',
                      fuera + ' de ' + total + ' · ' + pct + '%', true);
  html += filaMetrica('En horario laboral', laboral);
  html += filaMetrica('Fuera de horario', franja.fuera_horario || 0);
  html += filaMetrica('Madrugada (22:00–06:00)', franja.madrugada || 0);
  html += filaMetrica('Fin de semana', franja.fin_semana || 0);

  html += '<h3 class="metricas-titulo">Calidad de las respuestas</h3>';
  html += filaMetrica('Confianza alta (nivel 4–5)',
                      altos + ' de ' + items + ' · ' + pctAltos + '%', true);
  [5,4,3,2,1].forEach(function (n) {
    html += filaMetrica('Nivel ' + n, niveles[String(n)] || 0);
  });

  html += '<h3 class="metricas-titulo">Rendimiento y satisfacción</h3>';
  html += filaMetrica('Tiempo medio de respuesta',
    m.tiempo_respuesta_ms_medio
      ? Number(m.tiempo_respuesta_ms_medio).toLocaleString('es-CO') + ' ms'
      : 'sin datos');
  html += filaMetrica('Respuestas «sí fue útil»', m.feedback_positivo || 0);
  html += filaMetrica('Respuestas «no fue útil»', m.feedback_negativo || 0);

  html += '<h3 class="metricas-titulo">Fallos detectados</h3>';
  html += filaMetrica('Búsquedas registradas',
                      m.busquedas_sin_resultado || 0);
  html += filaMetrica('Reportadas por el ingeniero',
                      m.busquedas_reportadas || 0);

  html += '<p class="metricas-nota">Últimos ' + m.periodo_dias + ' días. '
        + 'El tiempo ahorrado se calculará cuando exista una medición real '
        + 'del tiempo que hoy toma buscar en SAP.</p>';

  return html;
}


async function cargarMetricas() {
  const destino = document.getElementById('contenido-metricas');
  if (!destino) return;
  destino.innerHTML = '<p class="ayuda-buscador">Cargando…</p>';
  destino.innerHTML = pintarMetricas(await obtenerMetricas(30));
}

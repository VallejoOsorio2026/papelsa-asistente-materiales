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

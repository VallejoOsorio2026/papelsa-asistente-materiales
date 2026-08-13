// ============================================================
// output.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// RN-008: una unica salida consolidada, para que el ingeniero
// copie y pegue una sola vez.
// RN-027: nueve columnas separadas por tabulador, en el orden
// exacto de la pantalla de SAP:
//
//   Componente · Denominacion · TE · Ctd. Neces. · UM ·
//   T · S · Almacen · Centro
//
// TE y S van siempre vacias. T lleva siempre la letra L.
//
// RN-028: el sistema NO crea la orden en SAP. El ingeniero
// sigue siendo responsable de trasladar la informacion.
// ============================================================

const ENCABEZADOS_SAP = [
  'Componente',
  'Denominación',
  'TE',
  'Ctd. Neces.',
  'UM',
  'T',
  'S',
  'Almacén',
  'Centro'
];


// ------------------------------------------------------------
// construirFilasSAP()
// ------------------------------------------------------------
function construirFilasSAP(solicitud) {

  return solicitud.items
    .filter(function (i) { return i.elegido !== null; })
    .map(function (i) {
      const m = i.elegido;
      return [
        m.material,          // Componente
        m.descripcion,       // Denominación
        '',                  // TE  (siempre vacío)
        String(i.cantidad),  // Ctd. Neces.
        m.unidad || '',      // UM
        'L',                 // T   (siempre L)
        '',                  // S   (siempre vacío)
        m.almacen || '',     // Almacén
        m.centro || ''       // Centro
      ];
    });
}


// ------------------------------------------------------------
// textoParaPegar()
// Tabulador entre columnas, salto de linea entre filas.
// Sin encabezados: SAP espera solo los datos.
// ------------------------------------------------------------
function textoParaPegar(solicitud) {
  return construirFilasSAP(solicitud)
    .map(function (fila) { return fila.join('\t'); })
    .join('\n');
}


// ------------------------------------------------------------
// pintarSalida()
// Dos bloques: uno para verificar y otro para copiar.
// ------------------------------------------------------------
function pintarSalida(solicitud) {

  const filas = construirFilasSAP(solicitud);

  if (filas.length === 0) {
    return '<div class="aviso aviso-error visible">'
         + 'No hay materiales seleccionados.</div>';
  }

  let html = '<div class="panel salida">';
  html += '<h2>Salida para SAP</h2>';

  // Aviso de cantidades asumidas (RN-004)
  const asumidas = solicitud.items.filter(function (i) {
    return i.elegido !== null && i.cantidadAsumida;
  });

  if (asumidas.length > 0) {
    html += '<div class="aviso aviso-atencion visible">'
          + '<strong>Revisa las cantidades.</strong> '
          + asumidas.length + ' material'
          + (asumidas.length > 1 ? 'es tienen' : ' tiene')
          + ' cantidad asumida porque no se indicó en la solicitud.'
          + '</div>';
  }

  // Tabla de verificación
  html += '<div class="tabla-envoltura"><table class="tabla-salida"><thead><tr>';
  ENCABEZADOS_SAP.forEach(function (h) {
    html += '<th>' + escapar(h) + '</th>';
  });
  html += '</tr></thead><tbody>';

  filas.forEach(function (fila) {
    html += '<tr>';
    fila.forEach(function (celda, i) {
      const clase = (i === 0 || i === 3) ? ' class="dato"' : '';
      html += '<td' + clase + '>' + escapar(celda) + '</td>';
    });
    html += '</tr>';
  });

  html += '</tbody></table></div>';

  // Bloque para copiar
  html += '<p class="ayuda-buscador" style="margin-top:16px">'
        + 'Copia este bloque y pégalo directamente en SAP.</p>';

  html += '<pre id="bloque-sap" class="bloque-sap">'
        + escapar(textoParaPegar(solicitud)) + '</pre>';

  html += '<button id="boton-copiar" class="boton">Copiar para SAP</button>';

  html += '<p class="nota-responsabilidad">'
        + 'El asistente no crea la orden en SAP. Verifica los materiales '
        + 'y las cantidades antes de continuar.</p>';

  html += '</div>';
  return html;
}


// ------------------------------------------------------------
// copiarSalida()
// ------------------------------------------------------------
async function copiarSalida(solicitud) {
  try {
    await navigator.clipboard.writeText(textoParaPegar(solicitud));
    return true;
  } catch (e) {
    // Algunos navegadores bloquean el portapapeles sin gesto
    // directo del usuario. Se selecciona el texto para que
    // pueda copiarlo con Ctrl+C.
    const bloque = document.getElementById('bloque-sap');
    if (bloque) {
      const rango = document.createRange();
      rango.selectNodeContents(bloque);
      const sel = window.getSelection();
      sel.removeAllRanges();
      sel.addRange(rango);
    }
    return false;
  }
}

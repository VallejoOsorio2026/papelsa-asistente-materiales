// ============================================================
// excel.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Genera el archivo de solicitud en el navegador, sin servidor
// ni instalaciones.
//
// Se usa formato Excel XML (SpreadsheetML): lo abre Excel
// directamente, conserva las columnas y no necesita ninguna
// libreria externa. Un CSV se abriria en una sola columna con
// la configuracion regional de Colombia, que usa punto y coma.
// ============================================================

// Mismo orden que la salida SAP (RN-027, sin la columna TE)
const COLUMNAS_EXCEL = [
  'Componente',
  'Denominación',
  'Ctd. Neces.',
  'UM',
  'T',
  'S',
  'Almacén',
  'Centro'
];


// ------------------------------------------------------------
// escaparXML()
// ------------------------------------------------------------
function escaparXML(texto) {
  return String(texto === null || texto === undefined ? '' : texto)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}


// ------------------------------------------------------------
// generarExcel()
// Devuelve el contenido del archivo como texto.
// ------------------------------------------------------------
function generarExcel(solicitud, datos) {

  const filas = construirFilasSAP(solicitud);

  let xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
  xml += '<?mso-application progid="Excel.Sheet"?>\n';
  xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" '
       + 'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">\n';

  xml += '<Styles>'
       + '<Style ss:ID="cab"><Font ss:Bold="1" ss:Color="#FFFFFF"/>'
       + '<Interior ss:Color="#006975" ss:Pattern="Solid"/></Style>'
       + '<Style ss:ID="tit"><Font ss:Bold="1" ss:Size="12" '
       + 'ss:Color="#006975"/></Style>'
       + '</Styles>\n';

  xml += '<Worksheet ss:Name="Solicitud"><Table>\n';

  // Encabezado con el contexto de la solicitud
  xml += fila([['Solicitud de materiales', 'tit']]);
  xml += fila([['Orden de trabajo', null], [datos.orden, null]]);
  xml += fila([['Solicitante', null], [datos.solicitante, null]]);
  xml += fila([['Fecha', null],
               [new Date().toLocaleString('es-CO'), null]]);
  xml += fila([]);

  // Cabecera de la tabla
  xml += fila(COLUMNAS_EXCEL.map(function (c) { return [c, 'cab']; }));

  // Materiales
  filas.forEach(function (f) {
    xml += fila(f.map(function (celda) { return [celda, null]; }));
  });

  xml += '</Table></Worksheet></Workbook>';
  return xml;
}


// ------------------------------------------------------------
// fila()
// Cada celda llega como [valor, estilo]
// ------------------------------------------------------------
function fila(celdas) {
  let xml = '<Row>';
  celdas.forEach(function (c) {
    xml += '<Cell' + (c[1] ? ' ss:StyleID="' + c[1] + '"' : '') + '>'
         + '<Data ss:Type="String">' + escaparXML(c[0]) + '</Data>'
         + '</Cell>';
  });
  xml += '</Row>\n';
  return xml;
}


// ------------------------------------------------------------
// descargarExcel()
// ------------------------------------------------------------
function descargarExcel(solicitud, datos) {

  const contenido = generarExcel(solicitud, datos);
  const blob = new Blob([contenido], {
    type: 'application/vnd.ms-excel;charset=utf-8'
  });

  const url = URL.createObjectURL(blob);
  const enlace = document.createElement('a');
  enlace.href = url;
  enlace.download = 'solicitud_' + datos.orden + '.xls';
  document.body.appendChild(enlace);
  enlace.click();
  document.body.removeChild(enlace);
  URL.revokeObjectURL(url);
}

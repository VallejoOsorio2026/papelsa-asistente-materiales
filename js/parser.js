// ============================================================
// parser.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Interpreta el mensaje del ingeniero y lo separa en items,
// cada uno con su cantidad.
//
// RN-004: si no se indica cantidad, se asume 1 y se marca como
// cantidad asumida para poder advertirlo despues.
// RN-005: una solicitud puede contener de 1 a N materiales.
// ============================================================

// Numeros escritos con palabras. En planta se dicta tanto
// "4 rodamientos" como "cuatro rodamientos".
const NUMEROS_TEXTO = {
  'un': 1, 'uno': 1, 'una': 1,
  'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5,
  'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9, 'diez': 10,
  'once': 11, 'doce': 12, 'trece': 13, 'catorce': 14,
  'quince': 15, 'veinte': 20, 'treinta': 30,
  'cincuenta': 50, 'cien': 100
};

// Palabras que separan un material de otro.
// La barra "/" NO es separador: en planta es una medida
// (3/4, 1/2, 3/8). Dividir por ella destruiria el dato mas
// decisivo para identificar el material (RN-017).
const SEPARADORES = /\s*(?:,|;|\by\b|\btambien\b|\bademas\b|\n)\s*/i;

// Verbos y muletillas con que suele empezar una solicitud.
// No aportan a la busqueda y ensucian la similitud.
const INTRODUCCIONES = /^(?:necesito|necesitamos|requiero|quiero|busco|buscar|dame|deme|enviar|env[ií]e|mandar|por\s+favor|porfa|hola|solicito|pedir|pido)\s+/i;


// ------------------------------------------------------------
// separarItems()
// Divide el mensaje en materiales independientes.
// ------------------------------------------------------------
function separarItems(mensaje) {

  const partes = mensaje
    .split(SEPARADORES)
    .map(function (p) { return p.trim(); })
    .filter(function (p) { return p.length >= 3; });

  return partes.length > 0 ? partes : [mensaje.trim()];
}


// ------------------------------------------------------------
// extraerCantidad()
// Busca la cantidad al inicio del texto, en cifra o en palabra.
// Devuelve el texto limpio y si la cantidad fue asumida.
//
// Solo se acepta al INICIO para no confundirla con una medida:
// en "llave 12mm" el 12 es una medida, no una cantidad.
// ------------------------------------------------------------
function extraerCantidad(texto) {

  let limpio = texto.trim().replace(INTRODUCCIONES, '').trim();

  // Cifra al inicio: "4 rodamientos", "10 und de cinta"
  const enCifra = limpio.match(
    /^(\d+)\s*(?:und|unds|unidades|unidad|pcs|piezas|rollos|rls|kg|mt|m|lt)?\s+(.+)$/i
  );

  if (enCifra) {
    return {
      cantidad: parseInt(enCifra[1], 10),
      texto: enCifra[2].trim(),
      asumida: false
    };
  }

  // Palabra al inicio: "cuatro rodamientos"
  const primera = limpio.split(/\s+/)[0].toLowerCase();
  if (NUMEROS_TEXTO[primera] !== undefined) {
    const resto = limpio.substring(primera.length).trim();
    if (resto.length >= 3) {
      return {
        cantidad: NUMEROS_TEXTO[primera],
        texto: resto,
        asumida: false
      };
    }
  }

  // RN-004: sin cantidad indicada
  return { cantidad: 1, texto: limpio, asumida: true };
}


// ------------------------------------------------------------
// interpretar()
// Punto de entrada. Devuelve la lista de items detectados.
// ------------------------------------------------------------
function interpretar(mensaje) {

  return separarItems(mensaje).map(function (parte, i) {
    const r = extraerCantidad(parte);
    return {
      orden: i + 1,
      textoOriginal: parte,
      texto: r.texto,
      cantidad: r.cantidad,
      cantidadAsumida: r.asumida
    };
  });
}

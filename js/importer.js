// ------------------------------------------------------------
// detectarSeparador()
// Excel usa coma o punto y coma segun la configuracion regional
// del equipo. Se decide contando cual aparece mas en la primera
// linea, que es la de encabezados.
// ------------------------------------------------------------
function detectarSeparador(texto) {

  const primeraLinea = texto.split('\n')[0];

  const comas = (primeraLinea.match(/,/g)  || []).length;
  const puntoYComa = (primeraLinea.match(/;/g) || []).length;
  const tabuladores = (primeraLinea.match(/\t/g) || []).length;

  if (tabuladores > comas && tabuladores > puntoYComa) return '\t';
  if (puntoYComa > comas) return ';';
  return ',';
}


// ------------------------------------------------------------
// leerCSV()
// Lector que respeta las comillas dobles, porque las
// descripciones pueden contener el separador y medidas
// en pulgadas.
// ------------------------------------------------------------
function leerCSV(texto) {

  const sep = detectarSeparador(texto);

  const filas = [];
  let campo = '';
  let fila = [];
  let entreComillas = false;

  for (let i = 0; i < texto.length; i++) {
    const c = texto[i];

    if (entreComillas) {
      if (c === '"' && texto[i + 1] === '"') { campo += '"'; i++; }
      else if (c === '"') { entreComillas = false; }
      else { campo += c; }
    } else {
      if (c === '"') { entreComillas = true; }
      else if (c === sep) { fila.push(campo); campo = ''; }
      else if (c === '\n') {
        fila.push(campo); campo = '';
        if (fila.some(function (v) { return v.trim() !== ''; })) {
          filas.push(fila);
        }
        fila = [];
      }
      else if (c !== '\r') { campo += c; }
    }
  }

  if (campo !== '' || fila.length > 0) {
    fila.push(campo);
    if (fila.some(function (v) { return v.trim() !== ''; })) {
      filas.push(fila);
    }
  }

  return filas;
}

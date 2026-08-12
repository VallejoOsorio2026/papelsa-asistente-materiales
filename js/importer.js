// ============================================================
// importer.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Lee el archivo de inventario en el navegador y lo envia por
// lotes a la base de datos.
//
// El archivo NUNCA sale hacia el repositorio: va del equipo del
// administrador directamente a la base de datos.
//
// RN-013: la version activa sigue respondiendo consultas
// durante toda la carga. Solo se conmuta al validar.
// ============================================================

// Orden exacto de los 21 encabezados (ADR-005).
const ENCABEZADOS = [
  'Material',
  'Texto breve material',
  'stock Libre_Utilizacion',
  'Stock consignación',
  'Stock Proyectos',
  'XCentro',
  'Máximo',
  'Minimo',
  'Centro',
  'Almacén',
  'Ubicación',
  'Unidad medida base',
  'Planif.necesidades',
  'Grupo Compra',
  'Tipo Material',
  'Grupo Articulo',
  'Clase Valoracion',
  'CatValStockPProyecto',
  'Caract.planif.nec.',
  'Tam.lote planif.nec.',
  'Nºmaterial antiguo'
];

// Nombres de columna en la base de datos, en el mismo orden.
const CAMPOS = [
  'material',
  'texto_breve_material',
  'stock_libre_utilizacion',
  'stock_consignacion',
  'stock_proyectos',
  'xcentro',
  'maximo',
  'minimo',
  'centro',
  'almacen',
  'ubicacion',
  'unidad_medida_base',
  'planif_necesidades',
  'grupo_compra',
  'tipo_material',
  'grupo_articulo',
  'clase_valoracion',
  'cat_val_stock_proyecto',
  'caract_planif_nec',
  'tam_lote_planif_nec',
  'material_antiguo'
];

const TAMANO_LOTE = 500;


// ------------------------------------------------------------
// detectarSeparador()
// Excel usa coma o punto y coma segun la configuracion regional
// del equipo. Se decide contando cual aparece mas en la linea
// de encabezados.
// ------------------------------------------------------------
function detectarSeparador(texto) {

  const primeraLinea = texto.split('\n')[0];

  const comas = (primeraLinea.match(/,/g) || []).length;
  const puntoYComa = (primeraLinea.match(/;/g) || []).length;
  const tabuladores = (primeraLinea.match(/\t/g) || []).length;

  if (tabuladores > comas && tabuladores > puntoYComa) return '\t';
  if (puntoYComa > comas) return ';';
  return ',';
}


// ------------------------------------------------------------
// leerCSV()
// Respeta las comillas dobles, porque las descripciones pueden
// contener el separador y medidas en pulgadas.
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


// ------------------------------------------------------------
// validarEncabezados()
// RN-012: los 21 encabezados deben estar presentes y en orden.
// Si algo no cuadra, la carga se rechaza completa.
// ------------------------------------------------------------
function validarEncabezados(fila) {

  if (fila.length !== ENCABEZADOS.length) {
    return {
      ok: false,
      mensaje: 'El archivo tiene ' + fila.length + ' columnas y se esperaban '
             + ENCABEZADOS.length + '.'
    };
  }

  for (let i = 0; i < ENCABEZADOS.length; i++) {
    const leido = fila[i].trim().replace(/^\uFEFF/, '');
    if (leido !== ENCABEZADOS[i]) {
      return {
        ok: false,
        mensaje: 'Columna ' + (i + 1) + ': se esperaba "' + ENCABEZADOS[i]
               + '" y se encontro "' + leido + '".'
      };
    }
  }

  return { ok: true };
}


// ------------------------------------------------------------
// importarInventario()
// Proceso completo. informar() recibe el avance para mostrarlo
// en pantalla.
// ------------------------------------------------------------
async function importarInventario(archivo, informar) {

  informar('Leyendo el archivo…');

  const texto = await archivo.text();
  const filas = leerCSV(texto);

  if (filas.length < 2) {
    return { ok: false, mensaje: 'El archivo no contiene datos.' };
  }

  const revision = validarEncabezados(filas[0]);
  if (!revision.ok) {
    return { ok: false, mensaje: revision.mensaje };
  }

  const datos = filas.slice(1);
  informar('Archivo valido: ' + datos.length.toLocaleString('es-CO') + ' filas.');

  // Abrir version en preparacion
  const { data: versionId, error: errorVersion } =
    await db.rpc('iniciar_version_datos', {
      p_archivo: archivo.name,
      p_filas_esperadas: datos.length
    });

  if (errorVersion) {
    return { ok: false, mensaje: 'No se pudo iniciar la carga: ' + errorVersion.message };
  }

  // Enviar por lotes
  let enviadas = 0;

  for (let i = 0; i < datos.length; i += TAMANO_LOTE) {

    const lote = datos.slice(i, i + TAMANO_LOTE).map(function (fila) {
      const objeto = {};
      CAMPOS.forEach(function (campo, j) {
        objeto[campo] = (fila[j] || '').trim();
      });
      return objeto;
    });

    const { data: insertadas, error } =
      await db.rpc('cargar_lote_inventario', {
        p_version_id: versionId,
        p_filas: lote
      });

    if (error) {
      return {
        ok: false,
        mensaje: 'Fallo en la fila ' + (i + 1) + ': ' + error.message
               + '. La version anterior sigue activa.'
      };
    }

    enviadas += insertadas;
    informar('Cargando… ' + enviadas.toLocaleString('es-CO')
           + ' de ' + datos.length.toLocaleString('es-CO'));
  }

  // Validar y conmutar
  informar('Validando la carga…');

  const { data: resultado, error: errorActivar } =
    await db.rpc('activar_version_datos', { p_version_id: versionId });

  if (errorActivar) {
    return { ok: false, mensaje: 'Error al activar: ' + errorActivar.message };
  }

  return resultado;
}

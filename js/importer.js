// ============================================================
// importer.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Lee el archivo de inventario en el navegador y lo envia por
// lotes a la base de datos.
//
// El archivo NUNCA sale hacia el repositorio: va del equipo del
// administrador directamente a la base de datos (ADR-010).
//
// RN-013: la version activa sigue respondiendo consultas
// durante toda la carga. Solo se conmuta al validar.
//
// ⚠️ ACTUALIZADO 10-09-2026 — ADR-023.
//
// Dos cambios respecto a la version anterior:
//
// 1. Se envian 10 columnas en lugar de 21. Las once eliminadas
//    no las leia ninguna funcion ni pantalla.
//
// 2. Los encabezados se buscan POR NOMBRE, no por posicion.
//    Motivo: SAP renombro cuatro columnas sin cambiar su
//    significado y la validacion por posicion habria rechazado
//    la carga entera. El orden dejo de importar; lo que importa
//    es que las 10 columnas esten. Asi el mismo importador
//    acepta el archivo de 28 columnas de hoy y el de 10 que
//    producira el script automatizado.
// ============================================================


// ------------------------------------------------------------
// COLUMNAS
// Para cada campo de la base, los nombres que puede traer el
// archivo. El primero es el vigente; los siguientes son
// historicos, para poder recargar archivos antiguos.
// ------------------------------------------------------------
const COLUMNAS = [
  { campo: 'material',
    nombres: ['Material'] },

  { campo: 'texto_breve_material',
    nombres: ['Texto breve de material', 'Texto breve material'] },

  { campo: 'stock_libre_utilizacion',
    nombres: ['Stock Libre_Utilizacion', 'Stock Libre Utilizacion'] },

  { campo: 'stock_consignacion',
    nombres: ['Stock consignación'] },

  { campo: 'stock_proyectos',
    nombres: ['Stock Proyectos'] },

  { campo: 'centro',
    nombres: ['Centro'] },

  { campo: 'almacen',
    nombres: ['Almacén'] },

  { campo: 'ubicacion',
    nombres: ['Ubicación'] },

  { campo: 'unidad_medida_base',
    nombres: ['Unidad medida base'] },

  { campo: 'material_antiguo',
    nombres: ['Nºmaterial antiguo', 'No.material antiguo'] }
];

// 500 filas por lote. Con 10 columnas en vez de 21 el peso
// enviado se reduce casi a la mitad, asi que subirlo a 1000
// seria viable. NO se sube todavia: cambiar dos cosas a la vez
// impide saber cual fallo si algo falla.
const TAMANO_LOTE = 500;


// ------------------------------------------------------------
// normalizarEncabezado()
// Para comparar titulos sin que una tilde o una mayuscula
// tumben una carga de 65.883 filas. Quita la marca invisible
// que Excel pone al principio del archivo (BOM), las tildes,
// las mayusculas y los espacios repetidos.
// ------------------------------------------------------------
function normalizarEncabezado(texto) {
  return String(texto || '')
    .replace(/^\uFEFF/, '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}


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
// ubicarColumnas()
// RN-012 (revisada por ADR-023): las 10 columnas deben ESTAR.
// El orden ya no importa y las sobrantes se ignoran.
//
// Si falta alguna, la carga se rechaza entera y el mensaje dice
// cuales faltan y que titulos llegaron, para poder compararlos
// sin abrir el archivo.
// ------------------------------------------------------------
function ubicarColumnas(filaEncabezados) {

  const leidos = filaEncabezados.map(normalizarEncabezado);

  const indices  = {};
  const faltantes = [];
  const repetidas = [];

  COLUMNAS.forEach(function (col) {

    const buscados = col.nombres.map(normalizarEncabezado);

    // Todas las posiciones que coinciden con algun nombre valido
    const encontradas = [];
    leidos.forEach(function (titulo, i) {
      if (titulo !== '' && buscados.indexOf(titulo) !== -1) {
        encontradas.push(i);
      }
    });

    if (encontradas.length === 0) {
      faltantes.push(col.nombres[0]);
    } else if (encontradas.length > 1) {
      // Dos columnas con el mismo titulo: no se adivina cual es
      repetidas.push(col.nombres[0]);
    } else {
      indices[col.campo] = encontradas[0];
    }
  });

  if (repetidas.length > 0) {
    return {
      ok: false,
      mensaje: 'El archivo trae repetida la columna: '
             + repetidas.join(', ')
             + '. No se puede saber cual usar.'
    };
  }

  if (faltantes.length > 0) {
    return {
      ok: false,
      mensaje: 'Faltan ' + faltantes.length + ' columnas obligatorias: '
             + faltantes.join(' · ')
             + '. El archivo trae estos titulos: '
             + filaEncabezados.join(' | ')
    };
  }

  return {
    ok: true,
    indices: indices,
    sobrantes: filaEncabezados.length - COLUMNAS.length
  };
}


// ------------------------------------------------------------
// diagnosticoUbicacion()
// PENDIENTE-017. Un 17% de las filas trae Ubicacion vacia y no
// esta claro si son vacios legitimos o el reporte de SAP
// suprime los valores repetidos.
//
// La supresion tiene una firma inconfundible: si suprime, el
// mismo valor NUNCA aparece en dos filas seguidas. Contar esas
// repeticiones consecutivas resuelve la duda sin abrir Excel.
//
//   repetidas = 0      -> hay supresion, el arrastre es real
//   repetidas = miles  -> no hay supresion, los blancos son
//                         vacios legitimos y NULL es correcto
//
// Es solo medicion: no modifica ni un dato.
// ------------------------------------------------------------
function diagnosticoUbicacion(datos, indice) {

  let conValor = 0;
  let vacias   = 0;
  let repetidasSeguidas = 0;
  let anterior = null;

  datos.forEach(function (fila) {

    const valor = (fila[indice] || '').trim();

    if (valor === '') {
      vacias++;
    } else {
      conValor++;
      if (anterior !== null && valor === anterior) {
        repetidasSeguidas++;
      }
    }

    anterior = (valor === '') ? anterior : valor;
  });

  return {
    conValor: conValor,
    vacias: vacias,
    repetidasSeguidas: repetidasSeguidas,
    texto: 'Ubicación: ' + conValor.toLocaleString('es-CO') + ' con valor · '
         + vacias.toLocaleString('es-CO') + ' vacías · '
         + repetidasSeguidas.toLocaleString('es-CO') + ' repeticiones seguidas'
         + (repetidasSeguidas === 0
              ? ' (PENDIENTE-017: apunta a arrastre)'
              : ' (PENDIENTE-017: apunta a vacíos legítimos)')
  };
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

  const mapa = ubicarColumnas(filas[0]);
  if (!mapa.ok) {
    return { ok: false, mensaje: mapa.mensaje };
  }

  const datos = filas.slice(1);

  informar('Archivo válido: ' + datos.length.toLocaleString('es-CO') + ' filas · '
         + '10 columnas localizadas'
         + (mapa.sobrantes > 0
              ? ' · ' + mapa.sobrantes + ' columnas sobrantes ignoradas'
              : ''));

  // PENDIENTE-017: se mide antes de enviar nada
  const diag = diagnosticoUbicacion(datos, mapa.indices.ubicacion);
  console.log('PENDIENTE-017 · ' + diag.texto);

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
      COLUMNAS.forEach(function (col) {
        const valor = fila[mapa.indices[col.campo]];
        objeto[col.campo] = (valor || '').trim();
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
               + '. La versión anterior sigue activa.'
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

  // El diagnostico viaja en el mensaje final para que quede a la
  // vista sin tener que abrir la consola
  if (resultado && resultado.ok) {
    resultado.mensaje = resultado.mensaje + ' · ' + diag.texto;
  }

  return resultado;
}

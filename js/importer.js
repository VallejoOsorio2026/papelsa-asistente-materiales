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
// ⚠️ ACTUALIZADO 10-09-2026 — ADR-023 y salida cruda de SAP.
//
// Cuatro cambios respecto a la version de agosto:
//
// 1. Se envian 10 columnas en lugar de 21 (ADR-023).
//
// 2. Los encabezados se buscan POR NOMBRE, no por posicion.
//    La salida cruda de SAP usa abreviaturas (Ce., Alm., UMB)
//    y otro orden: los stocks pasaron de las posiciones 3-4-5
//    a la 16-17-18. La validacion por posicion no habria
//    acertado ni una columna.
//
// 3. Se detecta la codificacion. El archivo de SAP viene en
//    Windows-1252, no en UTF-8. Leerlo mal no solo rompe los
//    titulos: corrompe cada descripcion con tilde, y como
//    texto_normalizado se calcula a partir de ellas, el motor
//    de busqueda queda envenenado en silencio.
//
// 4. La fila de titulos se busca; no se supone que sea la
//    primera. El reporte puede traer lineas de cabecera.
// ============================================================


// ------------------------------------------------------------
// COLUMNAS
// Para cada campo de la base, los nombres que puede traer el
// archivo. El primero es el de la salida cruda de SAP; los
// siguientes son historicos, para poder recargar archivos
// antiguos preparados a mano.
// ------------------------------------------------------------
const COLUMNAS = [
  { campo: 'material',
    nombres: ['Material'] },

  { campo: 'texto_breve_material',
    nombres: ['Texto breve de material', 'Texto breve material'] },

  { campo: 'stock_libre_utilizacion',
    nombres: ['S.Lib-Ut', 'Stock Libre_Utilizacion', 'stock Libre_Utilizacion'] },

  { campo: 'stock_consignacion',
    nombres: ['Stock cons', 'Stock consignación'] },

  { campo: 'stock_proyectos',
    nombres: ['St. Proy', 'Stock Proyectos'] },

  { campo: 'centro',
    nombres: ['Ce.', 'Centro'] },

  { campo: 'almacen',
    nombres: ['Alm.', 'Almacén'] },

  { campo: 'ubicacion',
    nombres: ['Ubic.', 'Ubicación'] },

  { campo: 'unidad_medida_base',
    nombres: ['UMB', 'Unidad medida base'] },

  { campo: 'material_antiguo',
    nombres: ['Nºmaterial antiguo', 'No.material antiguo'] }
];

// 500 filas por lote. Con 10 columnas en vez de 21 el peso
// enviado se reduce casi a la mitad, asi que subirlo seria
// viable. NO se sube todavia: cambiar dos cosas a la vez impide
// saber cual fallo si algo falla.
const TAMANO_LOTE = 500;


// ------------------------------------------------------------
// leerTexto()
// Decide la codificacion en lugar de suponerla.
//
// Con fatal:true, el decodificador de UTF-8 lanza error ante un
// byte invalido en vez de sustituirlo por el simbolo de
// interrogacion. Ese error es la senal de que el archivo no es
// UTF-8, y se reintenta con Windows-1252, que es lo que produce
// Excel en espanol por defecto.
//
// Importa mas de lo que parece: una tilde mal leida corrompe la
// descripcion, y de la descripcion sale texto_normalizado, que
// es sobre lo que busca el motor.
// ------------------------------------------------------------
async function leerTexto(archivo) {

  const bytes = await archivo.arrayBuffer();

  try {
    return {
      texto: new TextDecoder('utf-8', { fatal: true }).decode(bytes),
      codificacion: 'UTF-8'
    };
  } catch (e) {
    return {
      texto: new TextDecoder('windows-1252').decode(bytes),
      codificacion: 'Windows-1252'
    };
  }
}


// ------------------------------------------------------------
// normalizarEncabezado()
// Para comparar titulos sin que una tilde o una mayuscula
// tumben una carga de 65.883 filas. Quita la marca invisible
// que Excel pone al principio del archivo (BOM), las tildes,
// las mayusculas y los espacios repetidos.
//
// Tambien quita el simbolo de grado y el de sustitucion: asi
// "Nºmaterial antiguo" sigue reconociendose aunque el archivo
// llegue con ese caracter estropeado.
// ------------------------------------------------------------
function normalizarEncabezado(texto) {
  return String(texto || '')
    .replace(/^\uFEFF/, '')
    .replace(/[\uFFFD°º]/g, '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}


// ------------------------------------------------------------
// detectarSeparador()
// Excel usa coma o punto y coma segun la configuracion regional
// del equipo, y SAP a veces entrega tabulador.
//
// Se cuentan las 20 primeras lineas, no solo la primera: si el
// archivo empieza con una linea de cabecera sin separadores, se
// elegiria mal y no se partiria ninguna columna.
// ------------------------------------------------------------
function detectarSeparador(texto) {

  const lineas = texto.split('\n').slice(0, 20).join('\n');

  const comas       = (lineas.match(/,/g)  || []).length;
  const puntoYComa  = (lineas.match(/;/g)  || []).length;
  const tabuladores = (lineas.match(/\t/g) || []).length;

  if (tabuladores >= comas && tabuladores >= puntoYComa && tabuladores > 0) {
    return '\t';
  }
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
// ------------------------------------------------------------
function ubicarColumnas(filaEncabezados) {

  const leidos = filaEncabezados.map(normalizarEncabezado);

  const indices   = {};
  const faltantes = [];
  const repetidas = [];

  COLUMNAS.forEach(function (col) {

    const buscados = col.nombres.map(normalizarEncabezado);

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
             + repetidas.join(', ') + '. No se puede saber cuál usar.'
    };
  }

  if (faltantes.length > 0) {
    return {
      ok: false,
      mensaje: 'Faltan ' + faltantes.length + ' columnas obligatorias: '
             + faltantes.join(' · ')
    };
  }

  return {
    ok: true,
    indices: indices,
    sobrantes: filaEncabezados.length - COLUMNAS.length
  };
}


// ------------------------------------------------------------
// localizarEncabezados()
// El reporte puede traer lineas de cabecera antes de la tabla.
// Se prueban las 20 primeras y se usa la primera donde aparezcan
// las 10 columnas. Lo anterior se descarta.
//
// Si ninguna sirve, el mensaje incluye las cinco primeras filas
// tal como se leyeron: sin eso hay que abrir el Bloc de notas
// para saber que llego, y eso es tiempo perdido cada vez.
// ------------------------------------------------------------
function localizarEncabezados(filas) {

  const tope = Math.min(20, filas.length);

  for (let i = 0; i < tope; i++) {
    const intento = ubicarColumnas(filas[i]);
    if (intento.ok) {
      intento.filaEncabezados = i;
      return intento;
    }
  }

  const fallo = ubicarColumnas(filas[0]);

  let muestra = '';
  for (let i = 0; i < Math.min(5, filas.length); i++) {
    muestra += '\n[fila ' + (i + 1) + '] ' + filas[i].join(' | ');
  }

  return {
    ok: false,
    mensaje: fallo.mensaje
           + '\n\nSe revisaron las ' + tope + ' primeras filas sin encontrar '
           + 'los títulos. Principio del archivo:' + muestra
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
      anterior = valor;
    }
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

  const lectura = await leerTexto(archivo);
  const filas   = leerCSV(lectura.texto);

  console.log('Codificación detectada: ' + lectura.codificacion);

  if (filas.length < 2) {
    return { ok: false, mensaje: 'El archivo no contiene datos.' };
  }

  const mapa = localizarEncabezados(filas);
  if (!mapa.ok) {
    return { ok: false, mensaje: mapa.mensaje };
  }

  // Todo lo anterior a la fila de titulos se descarta
  const datos = filas.slice(mapa.filaEncabezados + 1);

  informar('Archivo válido: ' + datos.length.toLocaleString('es-CO') + ' filas · '
         + lectura.codificacion
         + (mapa.filaEncabezados > 0
              ? ' · ' + mapa.filaEncabezados + ' línea(s) de cabecera descartadas'
              : '')
         + (mapa.sobrantes > 0
              ? ' · ' + mapa.sobrantes + ' columnas ignoradas'
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

  if (resultado && resultado.ok) {
    resultado.mensaje = resultado.mensaje + ' · ' + diag.texto;
  }

  return resultado;
}

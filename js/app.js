// ============================================================
// app.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Orquestador: arranca la aplicacion, atiende los botones y
// decide que pantalla se muestra.
// ============================================================

// ------------------------------------------------------------
// Arranque
// ------------------------------------------------------------
document.addEventListener('DOMContentLoaded', async function () {

  if (!iniciarCliente()) {
    mostrarAviso('aviso-acceso',
      'No se pudo conectar. Revisa la configuracion.', 'error');
    return;
  }

  // Si el navegador guarda una sesion previa, entramos directo.
  const perfil = await recuperarSesion();
  if (perfil) {
    abrirAplicacion(perfil);
  }

  conectarBotones();
});


// ------------------------------------------------------------
// Botones
// ------------------------------------------------------------
function conectarBotones() {

  document.getElementById('boton-entrar')
          .addEventListener('click', entrar);

  document.getElementById('boton-salir')
          .addEventListener('click', salir);
 const botonBuscar = document.getElementById('boton-buscar');
  if (botonBuscar) {
    botonBuscar.addEventListener('click', ejecutarBusqueda);
  }

  const campoConsulta = document.getElementById('consulta');
  if (campoConsulta) {
    campoConsulta.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') ejecutarBusqueda();
    });
  } 
  const botonCargar = document.getElementById('boton-cargar');
  if (botonCargar) {
    botonCargar.addEventListener('click', cargarInventario);
  }
// Metricas desplegables, solo para administracion
  const cabMetricas = document.getElementById('metricas-cabecera');
  if (cabMetricas) {
    cabMetricas.addEventListener('click', async function () {
      const caja   = document.getElementById('contenido-metricas');
      const flecha = document.getElementById('flecha-metricas');
      const abierto = caja.classList.toggle('visible');
      if (flecha) flecha.classList.toggle('abierta', abierto);
      if (abierto) await cargarMetricas();
    });
  }
  // Historial desplegable
  const cabHistorial = document.getElementById('historial-cabecera');
  if (cabHistorial) {
    cabHistorial.addEventListener('click', async function () {
      const lista  = document.getElementById('lista-historial');
      const flecha = document.getElementById('flecha-historial');
      const abierto = lista.classList.toggle('visible');
      if (flecha) flecha.classList.toggle('abierta', abierto);
      if (abierto) {
        await cargarHistorial();
        conectarBotonesHistorial();
      }
    });
  }
  const botonRevertir = document.getElementById('boton-revertir');
  if (botonRevertir) {
    botonRevertir.addEventListener('click', revertirInventario);
  }

  // Enter en cualquiera de los dos campos inicia sesion.
  ['correo', 'contrasena'].forEach(function (id) {
    document.getElementById(id)
            .addEventListener('keydown', function (e) {
      if (e.key === 'Enter') entrar();
    });
  });
}


// ------------------------------------------------------------
// Entrar
// ------------------------------------------------------------
async function entrar() {

  const boton      = document.getElementById('boton-entrar');
  const correo     = document.getElementById('correo').value.trim();
  const contrasena = document.getElementById('contrasena').value;

  ocultarAviso('aviso-acceso');

  if (!correo || !contrasena) {
    mostrarAviso('aviso-acceso',
      'Escribe el correo y la contrasena.', 'error');
    return;
  }

  boton.disabled = true;
  boton.textContent = 'Entrando…';

  const resultado = await iniciarSesion(correo, contrasena);

  boton.disabled = false;
  boton.textContent = 'Entrar';

  if (!resultado.ok) {
    mostrarAviso('aviso-acceso', resultado.mensaje, 'error');
    return;
  }

  document.getElementById('contrasena').value = '';
  abrirAplicacion(resultado.perfil);
}


// ------------------------------------------------------------
// Salir
// ------------------------------------------------------------
async function salir() {
  await cerrarSesion();
  cambiarPantalla('pantalla-acceso');
  document.getElementById('correo').value = '';
}


// ------------------------------------------------------------
// Abrir la aplicacion
// ------------------------------------------------------------
async function abrirAplicacion(perfil) {

  let nombre = perfil.nombre;
  if (perfil.rol === 'admin') {
    nombre += ' <span class="etiqueta-rol">admin</span>';
  }

  document.getElementById('nombre-usuario').innerHTML = nombre;
  document.getElementById('correo-usuario').textContent = perfil.correo;
  document.getElementById('estado-version').textContent =
    CONFIG.VERSION_SISTEMA;

  cambiarPantalla('pantalla-app');
  // Los paneles de administracion solo se muestran al admin.
  // Ocultarlos no es una medida de seguridad: la proteccion
  // real esta en las politicas de la base de datos.
  if (esAdministrador()) {
    document.getElementById('panel-metricas').style.display = 'block';
    document.getElementById('panel-carga').style.display = 'block';
    document.getElementById('panel-revertir').style.display = 'block';
  }
  actualizarEstado();
}


// ------------------------------------------------------------
// Estado del sistema
// ------------------------------------------------------------
// ------------------------------------------------------------
// actualizarEstado()
// Una sola llamada resuelve tres cosas: cierra las solicitudes
// vencidas (RN-009), lee el perfil y lee la version de datos
// activa. Con la latencia del servidor, tres viajes se notan.
// ------------------------------------------------------------
async function actualizarEstado() {

  const conexion = document.getElementById('estado-conexion');

  const { data, error } = await db.rpc('iniciar_sesion_app');

  if (error || !data || data.ok !== true) {
    conexion.textContent = 'sin respuesta';
    conexion.style.color = 'var(--error)';
    return;
  }

  conexion.textContent = 'activa';
  conexion.style.color = 'var(--ok)';

  if (data.inventario) {
    document.getElementById('estado-datos').textContent =
      'version ' + data.inventario.numero;
    document.getElementById('estado-materiales').textContent =
      Number(data.inventario.filas_cargadas).toLocaleString('es-CO');
  } else {
    document.getElementById('estado-datos').textContent =
      'sin inventario cargado';
    document.getElementById('estado-materiales').textContent = '0';
  }

  if (data.cerradas_por_inactividad > 0) {
    console.log('RN-009: se cerraron '
      + data.cerradas_por_inactividad
      + ' solicitudes por inactividad.');
  }
}// ------------------------------------------------------------
// Utilidades de pantalla
// ------------------------------------------------------------
function cambiarPantalla(id) {
  document.querySelectorAll('.pantalla').forEach(function (p) {
    p.classList.remove('visible');
  });
  document.getElementById(id).classList.add('visible');
}

function mostrarAviso(id, texto, tipo) {
  const aviso = document.getElementById(id);
  aviso.textContent = texto;
  aviso.className = 'aviso aviso-' +
    (tipo === 'ok' ? 'ok' : tipo === 'atencion' ? 'atencion' : 'error') +
    ' visible';
}

function ocultarAviso(id) {
  document.getElementById(id).classList.remove('visible');
}
// ------------------------------------------------------------
// cargarInventario()
// ------------------------------------------------------------
async function cargarInventario() {

  const entrada = document.getElementById('archivo-inventario');
  const boton   = document.getElementById('boton-cargar');
  const avance  = document.getElementById('avance-carga');

  ocultarAviso('aviso-carga');

  if (!entrada.files || entrada.files.length === 0) {
    mostrarAviso('aviso-carga', 'Elige un archivo CSV.', 'error');
    return;
  }

  boton.disabled = true;
  boton.textContent = 'Cargando…';

  const resultado = await importarInventario(
    entrada.files[0],
    function (texto) { avance.textContent = texto; }
  );

  boton.disabled = false;
  boton.textContent = 'Cargar inventario';

  if (resultado.ok) {
    mostrarAviso('aviso-carga', resultado.mensaje, 'ok');
    avance.textContent = '';
    entrada.value = '';
    actualizarEstado();
  } else {
    mostrarAviso('aviso-carga', resultado.mensaje, 'error');
  }
}


// ------------------------------------------------------------
// revertirInventario()
// ------------------------------------------------------------
async function revertirInventario() {

  if (!confirm('Se restaurara la version anterior del inventario. ¿Continuar?')) {
    return;
  }

  const { data, error } = await db.rpc('revertir_version_datos');

  if (error) {
    mostrarAviso('aviso-carga', 'Error: ' + error.message, 'error');
    return;
  }

  mostrarAviso('aviso-carga', data.mensaje, data.ok ? 'ok' : 'atencion');
  actualizarEstado();
}
// ------------------------------------------------------------
// ejecutarBusqueda()
// Interpreta el mensaje, busca cada material y muestra todos
// los items juntos (RN-007).
// ------------------------------------------------------------
async function ejecutarBusqueda() {

  const campo   = document.getElementById('consulta');
  const boton   = document.getElementById('boton-buscar');
  const destino = document.getElementById('resultados-busqueda');

  const consulta = campo.value.trim();

  if (!consulta) {
    destino.innerHTML = '';
    campo.focus();
    return;
  }

  boton.disabled = true;
  boton.textContent = 'Buscando…';
  bloquesAbiertos = {};

  const inicio = Date.now();

  const solicitud = await nuevaSolicitud(consulta, function (texto) {
    // Se usa textContent en lugar de innerHTML: el texto de
    // avance no necesita interpretarse como HTML y asi este
    // archivo no depende de funciones de otro modulo.
    destino.textContent = '';
    const aviso = document.createElement('p');
    aviso.className = 'ayuda-buscador';
    aviso.textContent = texto;
    destino.appendChild(aviso);
  });

  const ms = Date.now() - inicio;
  // Se guarda para poder medir el rendimiento real del piloto
  if (solicitud) solicitud.tiempoMs = ms;

  boton.disabled = false;
  boton.textContent = 'Buscar';

  refrescarSolicitud();

  console.log('Solicitud: ' + solicitud.items.length + ' items · ' + ms + ' ms');
}


// ------------------------------------------------------------
// refrescarSolicitud()
// Vuelve a pintar la solicitud y reconecta sus controles.
//
// Se recuerda que bloques estaban desplegados: sin esto, al
// elegir un material se cerraria todo y el ingeniero perderia
// el sitio donde estaba mirando.
// ------------------------------------------------------------
let bloquesAbiertos = {};



function refrescarSolicitud() {

  const destino = document.getElementById('resultados-busqueda');
  destino.innerHTML = pintarSolicitud(solicitudActual);

  // Restaurar el estado de despliegue anterior
  Object.keys(bloquesAbiertos).forEach(function (orden) {
    const cuerpo = document.getElementById('cuerpo-' + orden);
    if (!cuerpo) return;
    const flecha = cuerpo.parentElement.querySelector('.flecha');
    if (bloquesAbiertos[orden]) {
      cuerpo.classList.add('visible');
      if (flecha) flecha.classList.add('abierta');
    } else {
      cuerpo.classList.remove('visible');
      if (flecha) flecha.classList.remove('abierta');
    }
  });

  // Desplegar y contraer
  destino.querySelectorAll('.item-cabecera.desplegable').forEach(function (cab) {
    cab.addEventListener('click', function () {
      const orden  = this.dataset.orden;
      const cuerpo = document.getElementById('cuerpo-' + orden);
      const flecha = this.querySelector('.flecha');
      if (!cuerpo) return;

      const abierto = cuerpo.classList.toggle('visible');
      if (flecha) flecha.classList.toggle('abierta', abierto);
      bloquesAbiertos[orden] = abierto;
    });
  });

  // Seleccionar o quitar una ubicacion (RN-033)
  destino.querySelectorAll('.ubicacion').forEach(function (fila) {
    fila.addEventListener('click', function (e) {
      e.stopPropagation();
      const orden = Number(this.dataset.orden);
      elegirUbicacion(orden, this.dataset.clave);
      // Al resolverse, el bloque se contrae para dar paso
      // a lo que sigue pendiente.
      const item = solicitudActual.items.find(function (i) {
        return i.orden === orden;
      });
      bloquesAbiertos[orden] = (item && item.elegido === null);
      refrescarSolicitud();
    });
  });

  // Cambiar la cantidad
  destino.querySelectorAll('.item-cantidad input').forEach(function (campo) {
    campo.addEventListener('change', function () {
      cambiarCantidad(Number(this.dataset.orden), this.value);
      refrescarSolicitud();
    });
    campo.addEventListener('click', function (e) { e.stopPropagation(); });
  });
// Aviso de busqueda sin resultado util
  destino.querySelectorAll('.reporte-enviar').forEach(function (boton) {
    boton.addEventListener('click', async function (e) {
      e.stopPropagation();

      const orden  = this.dataset.orden;
      const campo  = document.getElementById('reporte-texto-' + orden);
      const texto  = campo ? campo.value.trim() : '';

      if (!texto) {
        campo.focus();
        return;
      }

    const item = solicitudActual.items.find(function (i) {
        return i.orden === Number(orden);
      });
      const ok = await reportarBusqueda(item ? item.idBusqueda : null, texto);
      const caja = this.closest('.reporte-busqueda');

      caja.innerHTML = ok
        ? '<p class="reporte-gracias">Gracias. Revisaremos por qué no apareció.</p>'
        : '<p class="reporte-ayuda">No se pudo enviar el aviso.</p>';
    });
  });
  // Salida para SAP
  const botonSalida = document.getElementById('boton-salida');
  if (botonSalida) {
    botonSalida.addEventListener('click', generarSalida);
  }
}
// ------------------------------------------------------------
// generarSalida()
// RN-008: una unica salida consolidada al final.
// Es tambien el momento en que la solicitud se registra: aqui
// queda realmente resuelta.
// ------------------------------------------------------------
async function generarSalida() {

  const destino = document.getElementById('resultados-busqueda');

  // Se anade debajo de la solicitud, sin borrarla: el ingeniero
  // debe poder seguir viendo que eligio.
  const existente = document.getElementById('zona-salida');
  if (existente) existente.remove();

  const zona = document.createElement('div');
  zona.id = 'zona-salida';
  zona.innerHTML = pintarSalida(solicitudActual) + pintarEncuesta();
  destino.appendChild(zona);

  conectarBotonCopiar();
  conectarEncuesta();

  zona.scrollIntoView({ behavior: 'smooth', block: 'start' });

  // El registro va despues de mostrar la salida: si fallara,
  // el ingeniero ya tiene lo que necesita.
  await guardarSolicitud(solicitudActual, solicitudActual.tiempoMs || null);
}


// ------------------------------------------------------------
// conectarBotonCopiar()
// ------------------------------------------------------------
function conectarBotonCopiar() {

  const boton = document.getElementById('boton-copiar');
  if (!boton) return;

  boton.addEventListener('click', async function () {
    const ok = await copiarSalida(solicitudActual);
    this.textContent = ok ? '✓ Copiado' : 'Selecciona y copia con Ctrl+C';
    const b = this;
    setTimeout(function () { b.textContent = 'Copiar para SAP'; }, 2500);
  });
}


// ------------------------------------------------------------
// conectarEncuesta()
// RN-029: opcional. Responder no bloquea nada.
//
// El "si" se registra al instante. El "no" abre el detalle:
// es el caso donde la informacion vale mas.
// ------------------------------------------------------------
function conectarEncuesta() {

  const encuesta = document.getElementById('encuesta');
  if (!encuesta) return;

  const botonSi = document.getElementById('feedback-si');
  if (botonSi) {
    botonSi.addEventListener('click', async function () {
      await enviarFeedback(true, null, null);
      encuesta.innerHTML = '<span class="encuesta-gracias">'
        + 'Gracias. Tu respuesta ayuda a mejorar el asistente.</span>';
    });
  }

  const botonNo = document.getElementById('feedback-no');
  if (botonNo) {
    botonNo.addEventListener('click', function () {
      encuesta.innerHTML = '<span class="encuesta-pregunta">'
        + 'No fue útil</span>';
      const zona = document.getElementById('detalle-fallo');
      zona.innerHTML = pintarDetalleFallo();
      conectarDetalleFallo();
      zona.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    });
  }
}


// ------------------------------------------------------------
// conectarDetalleFallo()
// ------------------------------------------------------------
function conectarDetalleFallo() {

  let motivoElegido = null;

  document.querySelectorAll('.motivo-fallo').forEach(function (boton) {
    boton.addEventListener('click', function () {
      document.querySelectorAll('.motivo-fallo').forEach(function (b) {
        b.classList.remove('activo');
      });
      this.classList.add('activo');
      motivoElegido = this.dataset.motivo;
    });
  });

  const enviar = document.getElementById('enviar-fallo');
  if (!enviar) return;

  enviar.addEventListener('click', async function () {

    const campo = document.getElementById('esperado');
    const esperado = campo ? campo.value.trim() : '';

    // Se registra aunque no elija motivo: un "no" sin detalle
    // sigue siendo informacion.
    this.disabled = true;
    this.textContent = 'Enviando…';

    await enviarFeedback(false, motivoElegido, esperado);

    document.getElementById('detalle-fallo').innerHTML =
      '<p class="encuesta-gracias" style="padding:14px 0">'
      + 'Gracias. Revisaremos este caso.</p>';
  });
}
// ------------------------------------------------------------
// conectarBotonesHistorial()
// ------------------------------------------------------------
function conectarBotonesHistorial() {

  document.querySelectorAll('.historial-salida').forEach(function (boton) {
    boton.addEventListener('click', async function (e) {
      e.stopPropagation();

      const original = this.textContent;
      this.disabled = true;
      this.textContent = 'Recuperando…';

      const salida = await recuperarSalida(this.dataset.id);

      this.disabled = false;
      this.textContent = original;

      if (!salida || salida.items.length === 0) {
        alert('No se pudo recuperar la salida de esa consulta.');
        return;
      }

      // Se reutiliza la solicitud recuperada para generar la
      // misma salida, sin repetir la busqueda.
      solicitudActual = salida;

      const destino = document.getElementById('resultados-busqueda');
      const previa = document.getElementById('zona-salida');
      if (previa) previa.remove();

      const zona = document.createElement('div');
      zona.id = 'zona-salida';
      zona.innerHTML = pintarSalida(solicitudActual);
      destino.appendChild(zona);

      conectarBotonCopiar();
      zona.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  });
}

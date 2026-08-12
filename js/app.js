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
    document.getElementById('panel-carga').style.display = 'block';
    document.getElementById('panel-revertir').style.display = 'block';
  }
  actualizarEstado();
}


// ------------------------------------------------------------
// Estado del sistema
// ------------------------------------------------------------
async function actualizarEstado() {

  const conexion = document.getElementById('estado-conexion');
  const viva = await probarConexion();
  conexion.textContent = viva ? 'activa' : 'sin respuesta';
  conexion.style.color = viva ? 'var(--ok)' : 'var(--error)';

  // Version de inventario activa. Todavia no existe ninguna:
  // es correcto que aparezca vacio hasta la carga de datos.
  const { data: version } = await db
    .from('versiones_datos')
    .select('numero, filas_cargadas, finalizado_en')
    .eq('estado', 'activa')
    .maybeSingle();

  if (version) {
    document.getElementById('estado-datos').textContent =
      'version ' + version.numero;
    document.getElementById('estado-materiales').textContent =
      version.filas_cargadas.toLocaleString('es-CO');
  }
}


// ------------------------------------------------------------
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
  destino.innerHTML = '<p class="ayuda-buscador">Buscando…</p>';

  const inicio = Date.now();
  const respuesta = await buscar(consulta);
  const ms = Date.now() - inicio;

  boton.disabled = false;
  boton.textContent = 'Buscar';

  destino.innerHTML = pintarResultados(respuesta);

  console.log('Busqueda "' + consulta + '" · nivel ' + respuesta.nivel
            + ' · ' + respuesta.total + ' candidatos · ' + ms + ' ms');
}

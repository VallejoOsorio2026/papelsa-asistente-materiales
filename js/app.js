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

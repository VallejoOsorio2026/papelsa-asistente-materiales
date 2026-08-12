// ============================================================
// auth.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Inicio de sesion, cierre y verificacion.
//
// El registro publico esta desactivado en el servidor: los
// usuarios los crea unicamente el administrador. Este archivo
// no incluye funcion de registro de forma deliberada.
// ============================================================

let usuarioActual = null;   // datos de autenticacion
let perfilActual  = null;   // fila de la tabla perfiles

// ------------------------------------------------------------
// iniciarSesion()
// ------------------------------------------------------------
async function iniciarSesion(correo, contrasena) {

  const { data, error } = await db.auth.signInWithPassword({
    email: correo,
    password: contrasena
  });

  if (error) {
    return { ok: false, mensaje: traducirError(error.message) };
  }

  usuarioActual = data.user;
  perfilActual  = await obtenerPerfil();

  // Tener credenciales no basta: el perfil debe existir y
  // estar activo. Sin perfil, la base de datos no devuelve
  // ninguna fila y la aplicacion no serviria de nada.
  if (!perfilActual) {
    await cerrarSesion();
    return {
      ok: false,
      mensaje: 'Este usuario no tiene un perfil asignado. ' +
               'Solicita al administrador que lo habilite.'
    };
  }

  if (!perfilActual.activo) {
    await cerrarSesion();
    return { ok: false, mensaje: 'Tu usuario esta desactivado.' };
  }

  return { ok: true, perfil: perfilActual };
}

// ------------------------------------------------------------
// cerrarSesion()
// ------------------------------------------------------------
async function cerrarSesion() {
  await db.auth.signOut();
  usuarioActual = null;
  perfilActual  = null;
}

// ------------------------------------------------------------
// recuperarSesion()
// Al abrir la aplicacion comprueba si ya existe una sesion
// guardada en el navegador, para no pedir la contrasena
// en cada visita.
// ------------------------------------------------------------
async function recuperarSesion() {

  const { data } = await db.auth.getSession();

  if (!data.session) {
    return null;
  }

  usuarioActual = data.session.user;
  perfilActual  = await obtenerPerfil();

  if (!perfilActual || !perfilActual.activo) {
    await cerrarSesion();
    return null;
  }

  return perfilActual;
}

// ------------------------------------------------------------
// esAdministrador()
// Solo sirve para mostrar u ocultar opciones en pantalla.
// La proteccion real esta en las politicas de la base de
// datos: ocultar un boton no protege nada por si solo.
// ------------------------------------------------------------
function esAdministrador() {
  return perfilActual !== null && perfilActual.rol === 'admin';
}

// ------------------------------------------------------------
// traducirError()
// Convierte los mensajes tecnicos en espanol comprensible.
// ------------------------------------------------------------
function traducirError(mensaje) {

  const traducciones = {
    'Invalid login credentials':
      'Correo o contrasena incorrectos.',
    'Email not confirmed':
      'El correo aun no ha sido confirmado.',
    'Email logins are disabled':
      'El acceso por correo esta desactivado en el servidor.',
    'Signups not allowed for this instance':
      'El registro publico esta desactivado. Solicita acceso al administrador.'
  };

  return traducciones[mensaje] || ('Error: ' + mensaje);
}

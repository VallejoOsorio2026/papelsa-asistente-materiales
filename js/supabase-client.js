// ============================================================
// supabase-client.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Crea la conexion con la base de datos y comprueba que
// responde. La libreria se carga desde index.html.
// ============================================================

let db = null;

// ------------------------------------------------------------
// iniciarCliente()
// Se llama una sola vez al abrir la aplicacion.
// ------------------------------------------------------------
function iniciarCliente() {

  if (typeof supabase === 'undefined') {
    console.error('No se cargo la libreria de Supabase.');
    return false;
  }

  if (CONFIG.SUPABASE_URL.startsWith('https://mqthgvholgjfyoiczgqy.supabase.co/rest/v1/') ||
      CONFIG.SUPABASE_KEY.startsWith('sb_publishable_y3w_8r-3RfuL4NypOmkbyA_ZkGzVP7s')) {
    console.error('Faltan los valores en config.js');
    return false;
  }

  db = supabase.createClient(
    CONFIG.SUPABASE_URL,
    CONFIG.SUPABASE_KEY
  );

  console.log('Cliente iniciado. Version ' + CONFIG.VERSION_SISTEMA);
  return true;
}

// ------------------------------------------------------------
// probarConexion()
// Invoca la funcion ping() de la base de datos. Es la unica
// operacion permitida sin sesion iniciada y no expone datos:
// solo confirma que el servicio responde.
// ------------------------------------------------------------
async function probarConexion() {
  try {
    const { data, error } = await db.rpc('ping');
    if (error) {
      console.error('Error de conexion:', error.message);
      return false;
    }
    return data === 'ok';
  } catch (e) {
    console.error('Fallo la conexion:', e);
    return false;
  }
}

// ------------------------------------------------------------
// obtenerPerfil()
// Devuelve el perfil del usuario con sesion activa.
// Si no hay sesion, las politicas de seguridad devuelven
// cero filas y esta funcion retorna null.
// ------------------------------------------------------------
async function obtenerPerfil() {
  try {
    const { data, error } = await db
      .from('perfiles')
      .select('id, correo, nombre, rol, activo')
      .maybeSingle();

    if (error) {
      console.error('Error al leer el perfil:', error.message);
      return null;
    }
    return data;
  } catch (e) {
    console.error('Fallo al leer el perfil:', e);
    return null;
  }
}

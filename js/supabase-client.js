// ============================================================
// supabase-client.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Crea la conexion con la base de datos y comprueba que
// responde. La libreria se carga desde index.html.
//
// IMPORTANTE: este archivo NO lleva credenciales. La URL y la
// clave viven unicamente en config.js. Aqui solo se comprueba
// que tengan un formato valido.
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

  const url   = (CONFIG.SUPABASE_URL || '').trim();
  const clave = (CONFIG.SUPABASE_KEY || '').trim();

  if (!url.startsWith('https://')) {
    console.error('La URL debe empezar por https:// . Valor actual: ' + url);
    return false;
  }

  if (url.includes('/rest/') || url.endsWith('/')) {
    console.error('La URL no debe llevar rutas ni barra final. ' +
                  'Debe terminar en .supabase.co');
    return false;
  }

  if (clave.length < 20) {
    console.error('La clave publicable parece incompleta.');
    return false;
  }

  db = supabase.createClient(url, clave);

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
   const { data: sesion } = await db.auth.getUser();
    if (!sesion || !sesion.user) return null;

    const { data, error } = await db
      .from('perfiles')
      .select('id, correo, nombre, rol, activo')
      .eq('id', sesion.user.id)
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

// ============================================================
// config.js
// Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
// ============================================================
// Estos dos valores son publicos por diseno.
//
// La clave publicable esta pensada para exponerse en el
// navegador: por si sola no da acceso a nada. Toda consulta
// pasa por las politicas de seguridad de la base de datos,
// que exigen sesion valida y perfil activo.
//
// PROHIBIDO en este archivo: clave secreta, contrasena de la
// base de datos, credenciales de SAP o cualquier token.
// ============================================================

const CONFIG = {

  // Pegar aqui el valor de Settings > API Keys > Project URL
  SUPABASE_URL: 'https://mqthgvholgjfyoiczgqy.supabase.co',

  // Pegar aqui el valor de Settings > API Keys > Publishable key
  SUPABASE_KEY: 'sb_publishable_y3w_8r-3RfuL4NypOmkbyA_ZkGzVP7s',

  // Version logica de la aplicacion. Se registra en cada
  // solicitud para saber que codigo produjo cada respuesta.
  VERSION_SISTEMA: 'v0.6.0'

};

-- ============================================================
-- 027_reintento_correo.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- Red de seguridad del aviso por correo.
--
-- ADR-022: el envio normal es inmediato, no esperando a esta
-- tarea. Un mecanico de madrugada no puede esperar a que una
-- cola se revise. Esto solo recoge lo que fallo en el momento.
--
-- REQUIERE la extension pg_net en el esquema 'extensions'.
-- Se activa en Supabase → Database → Extensions.
--
-- La llamada no lleva cabecera de autorizacion porque la Edge
-- Function tiene "Verify JWT" desactivado, condicion necesaria
-- para que funcione CORS desde el navegador.
--
-- Tope de 10 por ejecucion, y correos_pendientes() ya descarta
-- las de 3 intentos: si el servicio de correo estuviera caido,
-- no se genera una tormenta de peticiones.
-- ============================================================

CREATE OR REPLACE FUNCTION public.reintentar_correos()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_pendientes jsonb;
  v_fila       jsonb;
  v_n          integer := 0;
begin
  v_pendientes := public.correos_pendientes(10);

  for v_fila in select * from jsonb_array_elements(v_pendientes)
  loop
    -- Llamada asincrona a la Edge Function. No se espera
    -- respuesta: la propia funcion marca el estado al terminar.
    perform net.http_post(
      url := 'https://mqthgvholgjfyoiczgqy.supabase.co/functions/v1/enviar-correo',
      body := jsonb_build_object('solicitud_id', v_fila->>'id'),
      headers := '{"Content-Type": "application/json"}'::jsonb
    );
    v_n := v_n + 1;
  end loop;

  return v_n;
end;
$function$;


-- ============================================================
-- TAREA PROGRAMADA
-- ============================================================
-- Cada 10 minutos. Con tope de 3 intentos, un aviso fallido se
-- reintenta durante media hora antes de darse por perdido. La
-- solicitud sigue visible en la bandeja de todos modos.
--
-- Si la tarea ya existe, cron.schedule la sustituye.
-- ============================================================

select cron.schedule(
  'reintentar-correos',
  '*/10 * * * *',
  $$select public.reintentar_correos();$$
);

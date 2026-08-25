-- ============================================================
-- 015_busquedas_fallidas.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- Registro de TODAS las busquedas, no solo las fallidas.
--
-- El nombre de la tabla quedo corto: nacio para registrar
-- busquedas sin resultado y hoy guarda cada consulta. Se
-- conserva porque renombrarla romperia codigo en marcha
-- (anotado en repo_pending_tasks).
--
-- Por que registrar tambien las que aciertan: el peor caso no
-- es que el sistema falle y lo sepa, sino que devuelva algo
-- plausible que no era lo buscado. Ahi el sistema cree que
-- acerto, el ingeniero se va, y no queda rastro.
--
-- Las tres funciones usan SECURITY DEFINER con verificacion de
-- sesion, y limitan la escritura al dueno del registro o al
-- admin: un ingeniero no puede alterar el aviso de otro.
-- ============================================================


-- ------------------------------------------------------------
-- registrar_busqueda_fallida()
-- Se llama en CADA busqueda. Sella la version de datos y la
-- version del sistema para poder comparar entre versiones.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.registrar_busqueda_fallida(
  p_consulta text,
  p_nivel    smallint DEFAULT NULL::smallint,
  p_total    integer  DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
begin
  if not public.es_usuario_activo() then
    return null;
  end if;

  insert into public.busquedas_sin_resultado (
    usuario_id, consulta, consulta_norm, nivel, total,
    version_datos_id, version_sistema
  ) values (
    auth.uid(), p_consulta, public.normalizar_texto(p_consulta),
    p_nivel, p_total,
    public.version_datos_activa(),
    coalesce((select valor from public.configuracion
              where clave = 'version_sistema'), 'sin registrar')
  )
  returning id into v_id;

  return v_id;
end;
$function$;


-- ------------------------------------------------------------
-- reportar_busqueda()
-- Recoge el aviso "¿No es esto lo que buscabas?".
-- p_comentario guarda el MOTIVO elegido; p_esperaba, el texto
-- libre. Se admite uno de los dos: elegir motivo sin escribir
-- nada ya es informacion util.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reportar_busqueda(
  p_id         uuid,
  p_esperaba   text,
  p_comentario text DEFAULT NULL::text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not public.es_usuario_activo() then
    return false;
  end if;

  update public.busquedas_sin_resultado
     set reportada  = true,
         esperaba   = p_esperaba,
         comentario = p_comentario
   where id = p_id
     and (usuario_id = auth.uid() or public.es_admin());

  return found;
end;
$function$;


-- ------------------------------------------------------------
-- marcar_busqueda_resuelta()
-- Distingue la busqueda que termino en una seleccion de la que
-- el ingeniero abandono. El abandono es el caso que mas
-- interesa y el que menos se declara.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.marcar_busqueda_resuelta(
  p_id       uuid,
  p_resuelta boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not public.es_usuario_activo() or p_id is null then
    return false;
  end if;

  update public.busquedas_sin_resultado
     set resuelta = p_resuelta
   where id = p_id
     and (usuario_id = auth.uid() or public.es_admin());

  return found;
end;
$function$;

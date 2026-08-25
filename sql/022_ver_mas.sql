-- ============================================================
-- 022_ver_mas.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- Cuenta cuantas veces el ingeniero pidio "Ver mas resultados"
-- (5 -> 10 -> 15) sobre una misma busqueda.
--
-- Para que sirve: si el material correcto estuviera siempre en
-- los cinco primeros, nadie ampliaria. Cada ampliacion es una
-- senal de que el ranking no puso arriba lo que se buscaba, y
-- se registra sin pedirle nada al ingeniero.
--
-- Es dato objetivo para PENDIENTE-009, a diferencia de
-- preguntar si el orden le parecio bueno.
-- ============================================================

CREATE OR REPLACE FUNCTION public.registrar_ampliacion(p_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_n integer;
begin
  if not public.es_usuario_activo() or p_id is null then
    return 0;
  end if;

  update public.busquedas_sin_resultado
     set ampliaciones = ampliaciones + 1
   where id = p_id
     and (usuario_id = auth.uid() or public.es_admin())
  returning ampliaciones into v_n;

  return coalesce(v_n, 0);
end;
$function$;

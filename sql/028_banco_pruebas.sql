-- ============================================================
-- 028_banco_pruebas.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- La pieza que faltaba para medir el motor en lugar de
-- ajustarlo sobre casos sueltos.
--
-- Regla derivada del proyecto: NO se toca el ranking sin
-- ejecutar el banco antes y despues. Un cambio que mejora un
-- caso puede empeorar otros cien, y sin medicion no hay forma
-- de saberlo.
--
-- La tabla banco_pruebas se creo en 002_schema.sql y estuvo
-- vacia hasta el 2026-08-26.
--
-- LO QUE SE MIDE ES LA POSICION del material correcto, no si
-- aparece. Pasar del puesto 7 al 2 es una mejora cuantificable;
-- "parece que ahora sale mejor" no lo es.
-- ============================================================


-- ------------------------------------------------------------
-- evaluar_banco_pruebas()
-- Ejecuta cada caso activo y devuelve en que posicion sale el
-- material esperado, junto a lo que encabeza en su lugar.
--
-- Se piden 20 resultados, no 5: si el material correcto esta
-- en el puesto 12, interesa saberlo. Fuera de 20 se considera
-- que no aparece.
--
-- es_admin() porque recorre el inventario con permisos
-- elevados.
--
-- ⚠️ NO se puede ejecutar desde el SQL Editor de Supabase:
-- buscar_materiales exige sesion activa y el editor no la
-- tiene. Se ejecuta desde la consola del navegador con sesion
-- de administrador:
--   const b = await db.rpc('evaluar_banco_pruebas');
--   console.table(b.data);
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.evaluar_banco_pruebas()
RETURNS TABLE(
  categoria     text,
  consulta      text,
  esperado      text,
  posicion      integer,
  encontrado    boolean,
  primero       text,
  desc_primero  text
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
declare
  c record;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede evaluar el banco.';
  end if;

  for c in
    select b.categoria, b.consulta, b.material_esperado
    from public.banco_pruebas b
    where b.activo
    order by b.categoria, b.consulta
  loop
    return query
    with res as (
      select r.material, r.descripcion,
             row_number() over () as pos
      from public.buscar_materiales(c.consulta, 20) r
    )
    select
      c.categoria,
      c.consulta,
      c.material_esperado,
      (select pos::integer from res
        where res.material = c.material_esperado limit 1),
      exists (select 1 from res where res.material = c.material_esperado),
      (select res.material    from res where pos = 1),
      (select res.descripcion from res where pos = 1);
  end loop;
end;
$function$;


-- ============================================================
-- CASOS INICIALES
-- ============================================================
-- Siete casos reales observados durante el piloto, no
-- inventados. Cuatro son de CONTROL: hoy funcionan y estan
-- aqui para detectar regresiones.
--
-- Las notas explican POR QUE falla cada caso y que no hacer.
-- Sin eso, dentro de tres meses serian siete consultas sueltas
-- sin contexto.
-- ============================================================

insert into public.banco_pruebas
  (categoria, consulta, material_esperado, nivel_esperado, notas, activo)
values

('abreviatura', 'AC Rsc', '5801168', 3,
 'FALLA. Posicion 7 el 2026-08-26. Encabezan reles Phoenix y carbones '
 || 'que solo comparten RSC. Causa diagnosticada: "ac" tiene 2 letras y '
 || 'extraer_palabras descarta lo menor de 3, asi que la busqueda '
 || 'efectiva es solo "rsc". La expansion anade "acero", que no coincide '
 || 'porque el inventario escribe AC. NO corregir bajando el minimo a 2 '
 || 'letras sin medir: meteria de, mm, un en todo el catalogo.', true),

('codigo', '5824421', '5824421', 5,
 'CONTROL. Posicion 1 el 2026-08-26. La mejora futura 16 decia que '
 || 'aparecia primero un grifo por similitud numerica; ya no ocurre. '
 || 'Nota: el material lleva BORRAR en la descripcion y aun asi va '
 || 'primero, que es lo correcto por RN-034.', true),

('fonetica', 'carft', '93220', 3,
 'CONTROL. Posicion 1 el 2026-08-26 con Cartulina Optima Kraft. '
 || 'PENDIENTE-006 lo daba por fallido; se corrigio en algun cambio '
 || 'posterior sin quedar registrado. Se conserva para detectar una '
 || 'regresion.', true),

('fonetica', 'craf', '5005794', 3,
 'FALLA. Unico caso vivo de PENDIENTE-006. El 2026-08-26 no aparecia '
 || 'ni entre los 20 primeros: encabeza SELLO MCO J-CRANE, sin relacion '
 || 'alguna. Peor de lo documentado, que decia "aparece pero no '
 || 'encabeza". Contraste util: kra y carft aciertan en el puesto 1 con '
 || 'la misma raiz. Causa probable: el algoritmo fonetico colapsa '
 || 'consonantes distintas.', true),

('jerga', 'disco pulidora pequeno', '3402284', 3,
 'FALLA LEVE. Posicion 2 el 2026-08-26, no perdido: la GUARDA PARA '
 || 'PULIDORA DEWALT 4-1/2 le gana por poco porque contiene las mismas '
 || 'palabras. PENDIENTE-009: el sustantivo principal no pesa mas que '
 || 'los calificativos. Idea a evaluar: mas peso si la palabra coincide '
 || 'al INICIO de la descripcion. No implementar sin medir todo el '
 || 'banco.', true),

('ortografia', 'kra', '5005794', 3,
 'CONTROL. Posicion 1 el 2026-08-26 con KRAFT BODEGA. Contrasta con '
 || 'craf, que falla con la misma raiz.', true),

('ortografia', 'sinta doble das', '5000043', 3,
 'CONTROL. Posicion 1 el 2026-08-26 pese a dos errores ortograficos. '
 || 'Caso historico: fue la primera prueba que demostro que la busqueda '
 || 'difusa funcionaba.', true);


-- ============================================================
-- LINEA BASE  ·  2026-08-26  ·  v1.2.0
-- ============================================================
--   consulta                 posicion
--   -------------------------------------
--   5824421                     1  ✓
--   carft                       1  ✓
--   kra                         1  ✓
--   sinta doble das             1  ✓
--   disco pulidora pequeno      2
--   AC Rsc                      7
--   craf                     fuera de 20
--
-- Cualquier cambio en el ranking se compara contra esta tabla.
-- ============================================================

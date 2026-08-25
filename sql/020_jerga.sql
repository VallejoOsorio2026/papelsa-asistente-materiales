-- ============================================================
-- 020_jerga.sql  (parte 1: aplicacion y validacion)
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- Capa 5 de ADR-011: vocabulario local -> especificacion
-- tecnica. No son abreviaturas ni erratas, sino como se pide
-- realmente un material en planta: "disco pulidora pequeno"
-- cuando el inventario dice DISCO PULIR 4 1/2".
--
-- LA JERGA VA ATADA A UN AMBITO. Sin esa condicion, la
-- equivalencia "pequeno -> 4 1/2" se aplicaria a cualquier
-- consulta con la palabra "pequeno", incluidos tornillos y
-- mangueras, y contaminaria la busqueda entera.
--
-- SE APLICA AL FINAL, despues de los sinonimos (error 18 del
-- historial): expandirla antes partia la medida y de "4 1/2"
-- quedaban "4" y "1/2" sueltos. Aqui la equivalencia se anade
-- entera al texto ya normalizado.
--
-- RN-025: lo observado NO se convierte solo en regla. Solo
-- entran las filas en estado 'validado', y validarlas exige
-- decision del administrador.
-- ============================================================


-- ------------------------------------------------------------
-- expandir_jerga()
-- Anade al texto normalizado las equivalencias cuyo termino Y
-- ambito aparecen ambos en la consulta.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.expandir_jerga(p_consulta text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path TO 'public', 'extensions'
AS $function$
  with norm as (
    select public.normalizar_texto(p_consulta) as texto
  ),
  aplicables as (
    select j.equivale_a
    from public.jerga_planta j, norm n
    where j.estado = 'validado'
      -- el termino de jerga esta en la consulta
      and n.texto ~ ('(^|\s)' || j.termino || '($|\s)')
      -- y el ambito tambien: sin esto la equivalencia se
      -- aplicaria a familias donde no corresponde
      and exists (
        select 1
        from unnest(string_to_array(j.ambito, ' ')) as palabra
        where n.texto like '%' || palabra || '%'
      )
  )
  select trim(
    (select texto from norm) || ' ' ||
    coalesce((select string_agg(distinct equivale_a, ' ') from aplicables), '')
  );
$function$;


-- ------------------------------------------------------------
-- validar_jerga()
-- Solo el administrador aprueba o rechaza (RN-025). Se guarda
-- quien valido y cuando: una equivalencia mal aprobada debe
-- poder rastrearse.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validar_jerga(
  p_id      uuid,
  p_aprobar boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede validar.';
  end if;

  update public.jerga_planta
     set estado = case when p_aprobar then 'validado' else 'rechazado' end,
         validado_por = auth.uid(),
         validado_en  = now()
   where id = p_id;

  return found;
end;
$function$;

-- ------------------------------------------------------------
-- proponer_jerga()
-- Cualquier usuario activo propone; nadie aprueba solo. La
-- fila entra como 'propuesto' y no afecta a la busqueda hasta
-- que el administrador la valide (RN-025).
--
-- on conflict do nothing: proponer dos veces lo mismo no crea
-- duplicados ni da error. Devuelve null si ya existia.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.proponer_jerga(
  p_termino    text,
  p_equivale_a text,
  p_ambito     text,
  p_nota       text DEFAULT NULL::text
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
    raise exception 'Se requiere sesion activa.';
  end if;

  insert into public.jerga_planta
    (termino, equivale_a, ambito, nota, estado, propuesto_por)
  values (
    public.normalizar_texto(p_termino),
    trim(p_equivale_a),
    public.normalizar_texto(p_ambito),
    p_nota,
    'propuesto',
    auth.uid()
  )
  on conflict (termino, equivale_a, ambito) do nothing
  returning id into v_id;

  return v_id;
end;
$function$;


-- ------------------------------------------------------------
-- descubrir_variantes()
-- Herramienta de administracion, no de busqueda.
--
-- Recorre el vocabulario REAL del inventario y encuentra pares
-- donde una palabra corta es prefijo de una larga: mang/
-- manguera, torn/tornillo, rod/rodamiento. Es como se armo el
-- diccionario de abreviaturas, en vez de inventarlas.
--
-- Solo propone candidatos: quien decide sigue siendo el
-- administrador (RN-025). Descarta palabras con cifras, que
-- son referencias y no abreviaturas.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.descubrir_variantes(
  p_min_frecuencia integer DEFAULT 20
)
RETURNS TABLE(
  palabra_larga text,
  palabra_corta text,
  frec_larga    bigint,
  frec_corta    bigint,
  parecido      real
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
  with vocabulario as (
    select w as palabra, count(*) as frec
    from public.inventario_materiales i,
         unnest(string_to_array(i.texto_normalizado, ' ')) as w
    where i.version_id = public.version_datos_activa()
      and length(w) >= 3
      and w !~ '[0-9]'
    group by w
    having count(*) >= p_min_frecuencia
  )
  select
    a.palabra,
    b.palabra,
    a.frec,
    b.frec,
    public.parecido_palabra(a.palabra, b.palabra)
  from vocabulario a
  join vocabulario b
    on length(b.palabra) < length(a.palabra)
   and a.palabra like b.palabra || '%'      -- b es prefijo de a
   and length(b.palabra) >= 3
  where public.parecido_palabra(a.palabra, b.palabra) >= 0.70
  order by b.frec desc, a.frec desc;
$function$;

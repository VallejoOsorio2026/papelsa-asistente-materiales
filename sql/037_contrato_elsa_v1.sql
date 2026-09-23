-- ============================================================
-- 037_contrato_elsa_v1.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- Fachada contractual Materiales-ELSA V1 (M1-C).
--
-- Esta es la superficie ESTABLE que ELSA consume. No es el
-- buscador, y no debe confundirse con el: el buscador responde
-- "que se parece a este texto", y esta fachada responde
-- "que es este codigo". Son preguntas distintas y el contrato
-- las separa a proposito.
--
-- Lo que esta fachada aporta sobre lo que ya existia:
--
--   1. acota la coincidencia a exacta por codigo;
--   2. adjunta la vigencia del inventario;
--   3. adjunta la cobertura del snapshot;
--   4. tipa la ausencia en vez de devolver cero filas mudas;
--   5. declara su propia version de contrato.
--
-- NO reutiliza consultar_materiales, buscar_agrupado ni
-- buscar_materiales. Esa cadena normaliza la consulta pero no
-- el valor almacenado, y cuando un codigo no coincide
-- literalmente CAE EN SILENCIO a similitud sobre la
-- descripcion. Para un buscador asistido eso es util; para una
-- identificacion autoritativa es exactamente el fallo que el
-- contrato existe para impedir. Por eso el lookup exacto de
-- aqui consulta inventario_materiales directamente.
--
-- Transporte V1: RPC de Supabase sobre HTTPS/PostgREST.
-- El contrato no depende del transporte: el descriptor lo
-- declara, y cambiarlo no redefine la semantica.
--
-- Identidad: es_usuario_activo(), el mismo control que ya
-- gobierna todo acceso. Sin service_role, sin secretos y sin
-- bypass de RLS.
--
-- Version del contrato: "1", CADENA y no entero, para permitir
-- cambios compatibles sin renumerar.
--
-- Definicion canonica del proveedor: docs/contrato-elsa-v1.md
-- ============================================================


-- ============================================================
-- get_contract_descriptor
-- Que version habla esta fachada y que operaciones OFRECE.
--
-- Requiere sesion autenticada. No consulta ni expone datos de
-- inventario: declara forma, no contenido.
--
-- La version nunca se adivina; si el descriptor no responde,
-- el consumidor declara desconocida la version y se degrada.
--
-- El descriptor enumera UNICAMENTE las operaciones que esta
-- fachada ofrece de verdad. search_materials_by_text sigue
-- definida normativamente en los ADR para el futuro, pero no
-- tiene RPC y no se ofrece aqui: listarla seria prometer una
-- superficie que nadie puede llamar.
--
-- El enlace de transporte es la ruta HTTPS/PostgREST concreta
-- de cada operacion, que es lo que un consumidor necesita para
-- invocarla. El contrato no depende de esa ruta: cambiarla no
-- redefine la semantica.
-- ============================================================

CREATE OR REPLACE FUNCTION public.elsa_v1_get_contract_descriptor()
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'contract_version', '1',
    'operations', jsonb_build_array(
      jsonb_build_object(
        'name',              'lookup_material_by_code',
        'transport_binding', '/rest/v1/rpc/elsa_v1_lookup_material_by_code',
        'deprecated',        false
      ),
      jsonb_build_object(
        'name',              'get_inventory_status',
        'transport_binding', '/rest/v1/rpc/elsa_v1_get_inventory_status',
        'deprecated',        false
      ),
      jsonb_build_object(
        'name',              'get_contract_descriptor',
        'transport_binding', '/rest/v1/rpc/elsa_v1_get_contract_descriptor',
        'deprecated',        false
      )
    ),
    -- Lo que este contrato NO transporta se declara aqui, no
    -- omitiendo claves del payload. El descriptor declara la
    -- capacidad; un null clasificado declara el caso.
    --
    -- Solo extracted_at. Los cuatro campos de coverage SI los
    -- transporta el contrato: llegan nulos por falta de metadata
    -- de ingestion, que es un caso, no una capacidad ausente.
    'unsupported_fields', jsonb_build_array('inventory.extracted_at')
  );
$function$;

comment on function public.elsa_v1_get_contract_descriptor is
  'Contrato Materiales-ELSA V1: version, operaciones y enlace de transporte.';


-- ============================================================
-- _elsa_v1_inventory
-- Bloque inventory del contrato, para la version activa.
-- Interna: no se concede a nadie.
--
-- Devuelve null si no hay version activa utilizable. Un
-- inventory con version_number o loaded_at nulos seria un
-- defecto de contrato, asi que ese caso se resuelve aguas
-- arriba como NO_ACTIVE_INVENTORY y no emitiendo nulos.
--
-- extracted_at va SIEMPRE en null y significa "este contrato no
-- transporta la fecha de extraccion desde SAP". NO significa
-- que SAP carezca de ella: el esquema auditado no la registra,
-- que es una afirmacion sobre Materiales, no sobre SAP.
-- ============================================================

CREATE OR REPLACE FUNCTION public._elsa_v1_inventory(p_version_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'version_number',    vd.numero,
    'loaded_at',         vd.finalizado_en,
    'row_count',         vd.filas_cargadas,
    'source_file_label', vd.archivo_nombre,
    'extracted_at',      null
  )
  from public.versiones_datos vd
  where vd.id = p_version_id
    and vd.numero is not null
    and vd.finalizado_en is not null;
$function$;

comment on function public._elsa_v1_inventory is
  'Interna del contrato V1. Bloque inventory; null si la version no es utilizable.';


-- ============================================================
-- _elsa_v1_coverage
-- Bloque coverage del contrato.
-- Interna: no se concede a nadie.
--
-- observed_scope significa "el ambito que Materiales DECLARA
-- que este snapshot cubrio", y debe venir de metadata de
-- ingestion. Esa metadata no existe todavia, de modo que el
-- estado es UNKNOWN y los cuatro ambitos van en null.
--
-- UNKNOWN no se disfraza de completo NI de incompleto. Y no se
-- deriva cobertura de los valores de ambito presentes en las
-- filas: contar los ambitos de los que llego algo responde a
-- una pregunta distinta de que ambito intento cubrir la carga.
-- ============================================================

CREATE OR REPLACE FUNCTION public._elsa_v1_coverage()
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'state',          'UNKNOWN',
    'observed_scope', null,
    'expected_scope', null,
    'missing_scope',  null,
    'scope_kind',     null,
    'declared_at',    null
  );
$function$;

comment on function public._elsa_v1_coverage is
  'Interna del contrato V1. Bloque coverage; UNKNOWN mientras no exista metadata de ingestion.';


-- ============================================================
-- get_inventory_status
-- Vigencia y cobertura, sin consultar material alguno.
-- ============================================================

CREATE OR REPLACE FUNCTION public.elsa_v1_get_inventory_status(
  p_contract_version text DEFAULT '1'
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_version_id uuid;
  v_inventory  jsonb;
begin
  -- La autorizacion no es una ausencia ni un fallo de la fuente.
  if not public.es_usuario_activo() then
    return jsonb_build_object(
      'contract_version', '1',
      'call_status',      'REJECTED',
      'inventory',        null,
      'coverage',         null
    );
  end if;

  v_version_id := public.version_datos_activa();
  v_inventory  := case when v_version_id is null
                       then null
                       else public._elsa_v1_inventory(v_version_id) end;

  -- Sin version activa no hubo donde mirar. NO es una ausencia.
  if v_inventory is null then
    return jsonb_build_object(
      'contract_version', '1',
      'call_status',      'NO_ACTIVE_INVENTORY',
      'inventory',        null,
      'coverage',         null
    );
  end if;

  return jsonb_build_object(
    'contract_version', '1',
    'call_status',      'OK',
    'inventory',        v_inventory,
    'coverage',         public._elsa_v1_coverage()
  );
end;
$function$;

comment on function public.elsa_v1_get_inventory_status is
  'Contrato Materiales-ELSA V1: vigencia y cobertura del inventario activo.';


-- ============================================================
-- lookup_material_by_code
-- Identificacion autoritativa: coincidencia exacta, o nada.
--
-- INVARIANTE, verificable: en un lookup exacto el origen de la
-- coincidencia solo puede ser EXACT_MATERIAL_CODE u
-- OLD_MATERIAL_CODE. Cualquier otro valor seria una violacion
-- del contrato, no un resultado de peor calidad.
--
-- Por eso aqui NO hay, y no puede haber:
--   - lower() ni normalizar_texto() sobre el codigo;
--   - trim() como regla de equivalencia;
--   - LIKE, ILIKE ni comodines;
--   - similarity() ni umbrales;
--   - orden por puntaje;
--   - "el mas parecido" como respuesta.
--
-- La comparacion es igualdad literal de cadena. El codigo se
-- devuelve tal como llego: sin anadir ceros, sin quitarlos y
-- sin relleno.
--
-- Un material ocupa VARIAS filas, una por combinacion de centro
-- y almacen (RN-033), y por eso stock_locations es una
-- coleccion: cada elemento procede de la MISMA fila y sus
-- atributos pueden afirmarse juntos. Los escalares agregados,
-- no.
-- ============================================================

CREATE OR REPLACE FUNCTION public.elsa_v1_lookup_material_by_code(
  p_contract_version text,
  p_material_code    text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_version_id   uuid;
  v_inventory    jsonb;
  v_coverage     jsonb;
  v_match_origin text;
  v_codigo       text;
  v_material     jsonb;
  v_read_at      timestamptz := now();
begin
  if not public.es_usuario_activo() then
    return jsonb_build_object(
      'contract_version', '1',
      'call_status',      'REJECTED',
      'inventory',        null,
      'coverage',         null,
      'results',          jsonb_build_array()
    );
  end if;

  v_version_id := public.version_datos_activa();
  v_inventory  := case when v_version_id is null
                       then null
                       else public._elsa_v1_inventory(v_version_id) end;

  if v_inventory is null then
    return jsonb_build_object(
      'contract_version', '1',
      'call_status',      'NO_ACTIVE_INVENTORY',
      'inventory',        null,
      'coverage',         null,
      'results',          jsonb_build_array()
    );
  end if;

  v_coverage := public._elsa_v1_coverage();

  -- 1) Coincidencia literal por codigo actual.
  select im.material into v_codigo
  from public.inventario_materiales im
  where im.version_id = v_version_id
    and im.material = p_material_code
  limit 1;

  if v_codigo is not null then
    v_match_origin := 'EXACT_MATERIAL_CODE';
  else
    -- 2) Coincidencia literal por codigo antiguo. Es un hecho
    --    DISTINTO de coincidir por el actual, y el contrato
    --    conserva la diferencia.
    select im.material into v_codigo
    from public.inventario_materiales im
    where im.version_id = v_version_id
      and im.material_antiguo = p_material_code
    limit 1;

    if v_codigo is not null then
      v_match_origin := 'OLD_MATERIAL_CODE';
    end if;
  end if;

  -- 3) Sin coincidencia literal NO se busca nada mas.
  --    Aqui es donde el buscador habria caido a similitud.
  if v_codigo is null then
    return jsonb_build_object(
      'contract_version', '1',
      'call_status',      'OK',
      'inventory',        v_inventory,
      'coverage',         v_coverage,
      'results', jsonb_build_array(
        jsonb_build_object(
          'requested_code', p_material_code,
          'outcome',        'NOT_RETURNED',
          'absence', jsonb_build_object(
            'reason',        'NOT_RETURNED_BY_SOURCE',
            'authoritative', false,
            'basis',         'La fuente respondio correctamente sobre la '
                          || 'version de inventario indicada y no devolvio '
                          || 'este codigo.'
          ),
          'material',    null,
          'match',       null,
          'attribution', null
        )
      )
    );
  end if;

  -- 4) Hecho factual. Los escalares de descripcion llegan por
  --    agregaciones independientes por campo: son
  --    FACTUAL_SAP_AGGREGATED y no describen necesariamente la
  --    misma fila. Los elementos de stock_locations, si.
  select jsonb_build_object(
    'code',        g.material,
    'descripcion', g.descripcion,
    'unidad',      g.unidad,
    'material_antiguo', g.material_antiguo,
    'total_disponible', jsonb_build_object(
      'value',           g.total_disponible,
      'rule_reference',  'RN-030',
      'rule_verifiable', false
    ),
    'total_comprometido', jsonb_build_object(
      'value',           g.total_comprometido,
      'rule_reference',  'RN-030',
      'rule_verifiable', false
    ),
    'dado_de_baja', jsonb_build_object(
      'value',           g.dado_de_baja,
      'rule_reference',  'RN-034',
      'rule_verifiable', false
    ),
    'stock_locations', g.stock_locations
  )
  into v_material
  from (
    select
      f.material,
      max(f.texto_breve_material)  as descripcion,
      max(f.unidad_medida_base)    as unidad,
      max(f.material_antiguo)      as material_antiguo,
      sum(coalesce(f.stock_libre_utilizacion, 0)
        + coalesce(f.stock_consignacion, 0))  as total_disponible,
      sum(coalesce(f.stock_proyectos, 0))     as total_comprometido,
      bool_or(public.es_material_baja(
        public.normalizar_texto(f.texto_breve_material))) as dado_de_baja,
      jsonb_agg(
        jsonb_build_object(
          'centro',       f.centro,
          'almacen',      f.almacen,
          'ubicacion',    f.ubicacion,
          'ambito',       f.ambito_ubicacion,
          'disponible',   coalesce(f.stock_libre_utilizacion, 0)
                        + coalesce(f.stock_consignacion, 0),
          'comprometido', coalesce(f.stock_proyectos, 0)
        )
        order by f.centro, f.almacen, f.id
      ) as stock_locations
    from public.inventario_materiales f
    where f.version_id = v_version_id
      and f.material = v_codigo
    group by f.material
  ) g;

  return jsonb_build_object(
    'contract_version', '1',
    'call_status',      'OK',
    'inventory',        v_inventory,
    'coverage',         v_coverage,
    'results', jsonb_build_array(
      jsonb_build_object(
        'requested_code', p_material_code,
        'outcome',        'MATCHED',
        'absence',        null,
        'material',       v_material,
        'match', jsonb_build_object(
          'match_origin', v_match_origin
        ),
        'attribution', jsonb_build_object(
          'capability',       'get_material_availability',
          'source',           'materiales',
          'source_version', jsonb_build_object(
            'version_number', v_inventory -> 'version_number',
            'loaded_at',      v_inventory -> 'loaded_at'
          ),
          'contract_version', '1',
          'read_at',          v_read_at,
          'match_origin',     v_match_origin
        )
      )
    )
  );
end;
$function$;

comment on function public.elsa_v1_lookup_material_by_code is
  'Contrato Materiales-ELSA V1: identificacion autoritativa por codigo exacto. Nunca degrada a similitud.';


-- ============================================================
-- PERMISOS
--
-- Minimo privilegio para superficie nueva: solo authenticated.
--
-- En PostgreSQL toda funcion nueva concede EXECUTE a PUBLIC por
-- defecto, asi que el REVOKE es obligatorio y no cosmetico
-- (misma razon que los REVOKE de 019_metricas.sql).
--
-- Esto NO endurece nada existente: son objetos que no existian.
-- Los permisos amplios de las funciones historicas siguen como
-- estan y se revisan en PENDIENTE-021, fuera de M1-C.
--
-- service_role NO recibe EXECUTE: ELSA consume con la identidad
-- del usuario, no con una credencial administrativa.
-- ============================================================

revoke all on function public.elsa_v1_get_contract_descriptor() from public;
revoke all on function public.elsa_v1_get_contract_descriptor() from anon;
grant execute on function public.elsa_v1_get_contract_descriptor() to authenticated;

revoke all on function public.elsa_v1_get_inventory_status(text) from public;
revoke all on function public.elsa_v1_get_inventory_status(text) from anon;
grant execute on function public.elsa_v1_get_inventory_status(text) to authenticated;

revoke all on function public.elsa_v1_lookup_material_by_code(text, text) from public;
revoke all on function public.elsa_v1_lookup_material_by_code(text, text) from anon;
grant execute on function public.elsa_v1_lookup_material_by_code(text, text) to authenticated;

-- Internas: no se conceden a ningun rol de cliente.
revoke all on function public._elsa_v1_inventory(uuid) from public;
revoke all on function public._elsa_v1_inventory(uuid) from anon;
revoke all on function public._elsa_v1_coverage() from public;
revoke all on function public._elsa_v1_coverage() from anon;

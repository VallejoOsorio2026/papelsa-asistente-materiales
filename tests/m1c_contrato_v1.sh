#!/usr/bin/env bash
# ============================================================
# tests/m1c_contrato_v1.sh
# Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
# ============================================================
# Pruebas contractuales del PROVEEDOR para el contrato
# Materiales-ELSA V1 (M1-C), sobre sql/037_contrato_elsa_v1.sql.
#
# Dos niveles, el segundo opcional sobre el primero:
#
#   1. Estatico. Sin argumentos. Solo lee sql/. Siempre corre.
#      Comprueba lo que se lee del texto de la migracion: que la
#      version es cadena, que el descriptor declara transporte,
#      que la busqueda textual NO queda habilitada, que los
#      permisos son minimos, y -lo que mas importa- que el
#      lookup exacto no contiene ningun mecanismo de similitud.
#
#   2. Funcional. Con M1C_TEST_DB apuntando a una base LOCAL y
#      DESECHABLE por socket Unix. Aplica la migracion sobre un
#      esqueleto minimo con datos sinteticos y comprueba el
#      comportamiento real.
#
# Uso:
#   tests/m1c_contrato_v1.sh
#   M1C_TEST_DB="host=/ruta/socket dbname=m1c user=postgres" \
#     tests/m1c_contrato_v1.sh
#
# NUNCA apuntar M1C_TEST_DB a Supabase: el guion crea roles,
# tablas y funciones. Rechaza lo que no sea socket Unix.
# ============================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"

if [ ! -f "sql/037_contrato_elsa_v1.sql" ]; then
  echo "ERROR: no existe sql/037_contrato_elsa_v1.sql" >&2; exit 2
fi

if [ -n "${M1C_TEST_DB:-}" ] && [[ "$M1C_TEST_DB" != *"host=/"* ]]; then
  echo "ERROR: M1C_TEST_DB debe ser una conexion por socket Unix (host=/...)." >&2
  echo "       Nunca apuntes este guion a Supabase." >&2
  exit 2
fi

python3 - <<'PYEOF'
import os, re, subprocess, sys, tempfile

RUTA = "sql/037_contrato_elsa_v1.sql"
sql = open(RUTA, encoding="utf-8").read()

fallos = 0
def ok(cond, msg):
    global fallos
    print(("  ok    " if cond else "  FALLO ") + msg)
    if not cond:
        fallos += 1

def cuerpo(nombre):
    m = re.search(
        r"CREATE OR REPLACE FUNCTION public\." + re.escape(nombre)
        + r"\b(.*?)\$function\$(.*?)\$function\$;", sql, re.S | re.I)
    return m.group(2) if m else None

print()
print("NIVEL 1 - ESTATICO")
print()
print("Operaciones contractuales")
for f in ("elsa_v1_lookup_material_by_code",
          "elsa_v1_get_inventory_status",
          "elsa_v1_get_contract_descriptor"):
    ok(cuerpo(f) is not None, f"{f}: definida")
for f in ("_elsa_v1_inventory", "_elsa_v1_coverage"):
    ok(cuerpo(f) is not None, f"{f}: interna definida")

print()
print("Version del contrato")
ok("'contract_version', '1'" in sql,
   "contract_version se emite como CADENA '1'")
ok(not re.search(r"'contract_version',\s*1\b", sql),
   "contract_version NUNCA se emite como entero")
ok("'1.0'" not in sql, "no aparece la version inventada '1.0'")

print()
print("Descriptor: forma")
desc = cuerpo("elsa_v1_get_contract_descriptor") or ""
ok("'contract_version', '1'" in desc, "declara contract_version '1'")
ok("'inventory.extracted_at'" in desc,
   "declara inventory.extracted_at como no transportado")
ok(desc.count("'unsupported_fields'") == 1, "unsupported_fields aparece una vez")
# Solo extracted_at: los campos de coverage SI los transporta el
# contrato, y llegan nulos por falta de metadata. Eso es un caso,
# no una capacidad ausente, y no va en el descriptor.
ok("coverage.observed_scope" not in desc,
   "unsupported_fields no incluye campos de coverage")

print()
print("Descriptor: campos NO autorizados")
ok(not re.search(r"'transport',\s", desc),
   "NO existe un campo superior 'transport'")
ok("'available'" not in desc, "NINGUNA operacion declara 'available'")

print()
print("Descriptor: operaciones ofrecidas")
nombres = re.findall(r"'name',\s*'([a-z_]+)'", desc)
ok(nombres == ["lookup_material_by_code",
               "get_inventory_status",
               "get_contract_descriptor"],
   f"ofrece exactamente las tres operaciones disponibles (encontradas: {nombres})")
ok("'search_materials_by_text'" not in
   re.sub(r"--[^\n]*", "", desc),
   "search_materials_by_text NO figura como operacion ofrecida")

print()
print("Descriptor: enlace de transporte")
for op in ("lookup_material_by_code", "get_inventory_status",
           "get_contract_descriptor"):
    ok(f"'/rest/v1/rpc/elsa_v1_{op}'" in desc,
       f"{op}: enlace a la ruta HTTPS/PostgREST concreta")
ok("'rpc:elsa_v1" not in desc,
   "no se usa la notacion 'rpc:<nombre>', que no es una ruta")
ok("'deprecated',        false" in desc or "'deprecated', false" in desc,
   "las operaciones declaran deprecated false")

print()
print("Busqueda textual NO habilitada")
ok(not re.search(r"FUNCTION public\.elsa_v1_search", sql, re.I),
   "no existe RPC de busqueda textual: no se habilita por simetria")

print()
print("Invariante del lookup exacto")
look = cuerpo("elsa_v1_lookup_material_by_code") or ""
ok("im.material = p_material_code" in look,
   "compara el codigo por igualdad literal de cadena")
ok("im.material_antiguo = p_material_code" in look,
   "compara el codigo antiguo por igualdad literal")
for prohibido, etiqueta in (
        (r"\blike\b",        "LIKE"),
        (r"\bilike\b",       "ILIKE"),
        (r"similarity\s*\(", "similarity()"),
        (r"\bsimilitud_palabras\b", "similitud_palabras()"),
        (r"\bparecido_palabra\b",   "parecido_palabra()"),
        (r"\bbuscar_materiales\b",  "buscar_materiales()"),
        (r"\bbuscar_agrupado\b",    "buscar_agrupado()"),
        (r"\bconsultar_materiales\b", "consultar_materiales()"),
        (r"\bconsultar_sin_existencias\b", "consultar_sin_existencias()"),
        (r"\bexpandir_consulta\b",  "expandir_consulta()"),
        (r"\bexpandir_jerga\b",     "expandir_jerga()"),
        (r"order\s+by\s+.*puntaje", "orden por puntaje"),
        (r"<->",             "operador de distancia"),
        (r"%\s*$",           "comodin"),
):
    ok(not re.search(prohibido, look, re.I | re.M),
       f"el lookup NO usa {etiqueta}")

print()
print("Representacion del codigo")
# normalizar_texto solo puede tocar la DESCRIPCION (regla de baja),
# nunca el codigo pedido.
for linea in look.splitlines():
    if "normalizar_texto" in linea:
        ok("texto_breve_material" in linea,
           "normalizar_texto solo se aplica a la descripcion, no al codigo")
ok(not re.search(r"(lower|upper|btrim|ltrim|rtrim|lpad|rpad)\s*\(\s*p_material_code",
                 look, re.I),
   "el codigo pedido no se transforma: sin caja, sin trim, sin padding")
ok(not re.search(r"p_material_code\s*::\s*(numeric|integer|bigint)", look, re.I),
   "el codigo pedido no se convierte a numero")
ok("'requested_code', p_material_code" in look,
   "el codigo se devuelve como eco literal de lo enviado")

print()
print("Semantica de ausencia")
ok("'NOT_RETURNED'" in look, "emite outcome NOT_RETURNED")
ok("'NOT_RETURNED_BY_SOURCE'" in look, "emite la unica causa de ausencia de V1")
ok("'authoritative', false" in look, "la ausencia NUNCA es autoritativa")
for reservado in ("NOT_IN_SAP", "NOT_IN_ACTIVE_SNAPSHOT", "OUTSIDE_DECLARED_COVERAGE"):
    ok(reservado not in sql,
       f"no activa el reservado {reservado}: M8 sigue abierto")

print()
print("Estados de la llamada como valores, no excepciones")
for estado in ("'OK'", "'REJECTED'", "'NO_ACTIVE_INVENTORY'"):
    ok(estado in look, f"el lookup puede emitir call_status {estado}")
ok(not re.search(r"raise\s+exception", look, re.I),
   "el lookup no lanza excepcion para los desenlaces normales")
ok(not re.search(r"raise\s+exception",
                 cuerpo("elsa_v1_get_inventory_status") or "", re.I),
   "get_inventory_status no lanza excepcion para los desenlaces normales")

print()
print("Vigencia y cobertura")
inv = cuerpo("_elsa_v1_inventory") or ""
for campo in ("version_number", "loaded_at", "row_count",
              "source_file_label", "extracted_at"):
    ok(f"'{campo}'" in inv, f"inventory emite siempre {campo}")
ok("'extracted_at',      null" in inv or "'extracted_at', null" in inv,
   "extracted_at va SIEMPRE en null: el contrato no lo transporta")
ok("vd.finalizado_en" in inv,
   "loaded_at proviene del fin de la carga, no de una fecha inventada")
ok("finalizado_en is not null" in inv,
   "no se emite un inventory con loaded_at nulo: seria defecto de contrato")
cov = cuerpo("_elsa_v1_coverage") or ""
ok("'state',          'UNKNOWN'" in cov or "'state', 'UNKNOWN'" in cov,
   "coverage es UNKNOWN mientras no exista metadata de ingestion")
ok("KNOWN_COMPLETE" not in cov, "UNKNOWN no se disfraza de completo")
ok("KNOWN_INCOMPLETE" not in cov, "UNKNOWN no se disfraza de incompleto")
ok("'observed_scope', null" in cov, "no declara ambito observado sin respaldo")
ok("ambito_ubicacion" not in cov,
   "la cobertura NO se deriva de los ambitos de las filas")

print()
print("Procedencia de los campos derivados")
for campo in ("total_disponible", "total_comprometido", "dado_de_baja"):
    m2 = re.search(r"'" + campo + r"',\s*jsonb_build_object\((.*?)\)\n", look, re.S)
    blo = m2.group(1) if m2 else ""
    ok("'rule_reference'" in blo, f"{campo} declara su rule_reference")
    ok("'rule_verifiable', false" in blo,
       f"{campo} declara rule_verifiable false: su regla no esta versionada")

print()
print("Atribucion")
for campo in ("'capability'", "'source'", "'source_version'",
              "'contract_version'", "'read_at'", "'match_origin'"):
    ok(campo in look, f"la atribucion incluye {campo}")
ok("'get_material_availability'" in look, "capability es la de ADR 0020")
ok("'materiales'" in look, "source es materiales")

print()
print("Vocabulario de coincidencia")
ok("'EXACT_MATERIAL_CODE'" in look, "emite EXACT_MATERIAL_CODE")
ok("'OLD_MATERIAL_CODE'" in look, "emite OLD_MATERIAL_CODE")
ok("OTHER_MATCH" not in look,
   "OTHER_MATCH es inadmisible en un lookup exacto y no se emite")

print()
print("Permisos: minimo privilegio, sin service_role")
for f, firma in (("elsa_v1_get_contract_descriptor", "()"),
                 ("elsa_v1_get_inventory_status", "(text)"),
                 ("elsa_v1_lookup_material_by_code", "(text, text)")):
    ok(f"revoke all on function public.{f}{firma} from public;" in sql,
       f"{f}: REVOKE a public (PostgreSQL concede EXECUTE por defecto)")
    ok(f"revoke all on function public.{f}{firma} from anon;" in sql,
       f"{f}: REVOKE a anon")
    ok(f"grant execute on function public.{f}{firma} to authenticated;" in sql,
       f"{f}: EXECUTE solo para authenticated")
ok("to service_role" not in sql,
   "ninguna funcion contractual concede EXECUTE a service_role")
ok("public.es_usuario_activo()" in sql,
   "reutiliza el control de identidad existente")

print()
print("Ausencia de secretos")
for patron, etiqueta in (
        (r"sb_secret", "clave secreta de Supabase"),
        (r"service_role_key", "service role key"),
        (r"eyJ[A-Za-z0-9_-]{10,}", "JWT embebido"),
        (r"postgres://", "cadena de conexion"),
        (r"postgresql://", "cadena de conexion"),
        (r"password\s*=", "contrasena"),
        (r"\.supabase\.co", "hostname del proyecto"),
):
    ok(not re.search(patron, sql, re.I), f"la migracion no contiene {etiqueta}")

# ---------------------------------------------------------------
conn = os.environ.get("M1C_TEST_DB", "")
if not conn:
    print()
    print("M1C_TEST_DB NO PROPORCIONADO: se omite el nivel 2 (funcional).")
    print("Para ejecutarlo contra una base LOCAL y desechable:")
    print('  M1C_TEST_DB="host=/ruta/socket dbname=m1c user=postgres" \\')
    print("    tests/m1c_contrato_v1.sh")
else:
    print()
    print("NIVEL 2 - FUNCIONAL")
    print()

    def psql(sqltxt):
        r = subprocess.run(["psql", "-tA", "-v", "ON_ERROR_STOP=1", conn, "-c", sqltxt],
                           capture_output=True, text=True)
        if r.returncode != 0:
            return None, r.stderr.strip()
        # psql imprime la etiqueta del SET de sesion antes del resultado, y
        # un valor NULL sale como linea vacia: no se puede usar strip() antes
        # de partir en lineas, o la etiqueta acabaria leyendose como el valor.
        lineas = [l for l in r.stdout.split("\n") if l != "SET"]
        while len(lineas) > 1 and lineas[-1] == "":
            lineas.pop()
        return (lineas[-1] if lineas else ""), None

    UID = "11111111-1111-1111-1111-111111111111"
    SESION = f"set m1c.uid='{UID}'; "

    def con_sesion(q):
        return psql(SESION + q)

    v, err = psql("select 1")
    ok(err is None, f"conexion a la base de prueba ({err or 'ok'})")

    if err is None:
        v, e = con_sesion(
            "select r->>'outcome' from jsonb_array_elements("
            "public.elsa_v1_lookup_material_by_code('1','10000001')->'results') r")
        ok(v == "MATCHED", "codigo exacto existente devuelve MATCHED")

        v, e = con_sesion(
            "select r->'match'->>'match_origin' from jsonb_array_elements("
            "public.elsa_v1_lookup_material_by_code('1','10000001')->'results') r")
        ok(v == "EXACT_MATERIAL_CODE", "coincidencia por codigo actual")

        v, e = con_sesion(
            "select r->'match'->>'match_origin' from jsonb_array_elements("
            "public.elsa_v1_lookup_material_by_code('1','000123')->'results') r")
        ok(v == "OLD_MATERIAL_CODE", "coincidencia por codigo antiguo")

        v, e = con_sesion(
            "select r->>'outcome' from jsonb_array_elements("
            "public.elsa_v1_lookup_material_by_code('1','123')->'results') r")
        ok(v == "NOT_RETURNED",
           "'123' NO equivale a '000123': los ceros no se quitan")

        v, e = con_sesion(
            "select r->>'outcome' from jsonb_array_elements("
            "public.elsa_v1_lookup_material_by_code('1','99')->'results') r")
        ok(v == "NOT_RETURNED",
           "'99' NO equivale a '00099': no hay padding")

        v, e = con_sesion(
            "select r->>'outcome' from jsonb_array_elements("
            "public.elsa_v1_lookup_material_by_code("
            "'1','RETENEDOR 110X142X15')->'results') r")
        ok(v == "NOT_RETURNED",
           "el texto exacto de una descripcion NO devuelve candidato: sin fallback textual")

        v, e = con_sesion(
            "select r->>'outcome' from jsonb_array_elements("
            "public.elsa_v1_lookup_material_by_code('1','10000002')->'results') r")
        ok(v == "NOT_RETURNED",
           "un codigo parecido NO cae a similitud: sin fallback fuzzy")

        v, e = con_sesion(
            "select r->'absence'->>'authoritative' from jsonb_array_elements("
            "public.elsa_v1_lookup_material_by_code('1','10000002')->'results') r")
        ok(v == "false", "la ausencia devuelta no es autoritativa")

        v, e = con_sesion(
            "select jsonb_array_length(public.elsa_v1_lookup_material_by_code("
            "'1','10000001')->'results'->0->'material'->'stock_locations')")
        ok(v == "2", "multiubicacion: una entrada por fila del material")

        v, e = con_sesion(
            "select public.elsa_v1_get_inventory_status('1')->'inventory'->>'extracted_at'")
        ok(v == "", "extracted_at llega nulo")

        v, e = con_sesion(
            "select public.elsa_v1_get_inventory_status('1')->'coverage'->>'state'")
        ok(v == "UNKNOWN", "coverage es UNKNOWN")

        v, e = con_sesion(
            "select jsonb_typeof(public.elsa_v1_get_inventory_status('1')->'contract_version')")
        ok(v == "string", "contract_version es de tipo string")

        v, e = psql("select public.elsa_v1_lookup_material_by_code('1','10000001')->>'call_status'")
        ok(v == "REJECTED", "sin identidad valida responde REJECTED, no excepcion")

        v, e = psql("select public.elsa_v1_get_contract_descriptor()->>'contract_version'")
        ok(v == "1", "el descriptor devuelve contract_version 1")

        v, e = psql("select jsonb_typeof(public.elsa_v1_get_contract_descriptor()"
                    "->'contract_version')")
        ok(v == "string", "contract_version del descriptor es de tipo string")

        # Las claves de nivel superior, sobre el JSON real y no sobre el texto.
        v, e = psql("select string_agg(k, ',' order by k) from jsonb_object_keys("
                    "public.elsa_v1_get_contract_descriptor()) k")
        ok(v == "contract_version,operations,unsupported_fields",
           f"el descriptor tiene exactamente tres claves superiores (tiene: {v})")
        ok(v is not None and "transport" not in (v or "").split(","),
           "el JSON real NO trae un campo superior 'transport'")

        v, e = psql("select string_agg(o->>'name', ',') from jsonb_array_elements("
                    "public.elsa_v1_get_contract_descriptor()->'operations') o")
        ok(v == "lookup_material_by_code,get_inventory_status,get_contract_descriptor",
           f"operations enumera solo las tres disponibles (tiene: {v})")

        v, e = psql("select count(*) from jsonb_array_elements("
                    "public.elsa_v1_get_contract_descriptor()->'operations') o "
                    "where o ? 'available'")
        ok(v == "0", "ninguna operacion del JSON real trae 'available'")

        v, e = psql("select count(*) from jsonb_array_elements("
                    "public.elsa_v1_get_contract_descriptor()->'operations') o "
                    "where o->>'name' = 'search_materials_by_text'")
        ok(v == "0", "search_materials_by_text no aparece en el JSON real")

        v, e = psql("select string_agg(o->>'transport_binding', ',') from "
                    "jsonb_array_elements(public.elsa_v1_get_contract_descriptor()"
                    "->'operations') o")
        ok(v == "/rest/v1/rpc/elsa_v1_lookup_material_by_code,"
                "/rest/v1/rpc/elsa_v1_get_inventory_status,"
                "/rest/v1/rpc/elsa_v1_get_contract_descriptor",
           "los enlaces son rutas /rest/v1/rpc/... concretas")

        v, e = psql("select public.elsa_v1_get_contract_descriptor()"
                    "->>'unsupported_fields'")
        ok(v == '["inventory.extracted_at"]',
           f"unsupported_fields contiene solo inventory.extracted_at (tiene: {v})")

print()
if fallos:
    print(f"RESULTADO: {fallos} FALLO(S)")
    sys.exit(1)
print("RESULTADO: todo ok")
PYEOF

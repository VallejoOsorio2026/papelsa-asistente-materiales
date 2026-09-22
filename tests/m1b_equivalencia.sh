#!/usr/bin/env bash
# ============================================================
# tests/m1b_equivalencia.sh
# Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
# ============================================================
# Comprueba que sql/030..036 reproducen la base viva (M1-B).
#
# Tres niveles, cada uno opcional sobre el anterior:
#
#   1. Estatico. Sin argumentos. Solo lee sql/. Siempre corre.
#
#   2. Evidencia. Con los dos TXT de introspeccion como
#      argumentos. Los TXT NO estan en el repositorio: se pasan
#      por ruta y se verifica su SHA-256 antes de usarlos.
#      Los cuerpos de funcion se comparan byte a byte.
#
#   3. Replay. Ademas de la evidencia, M1B_REPLAY_DB con una
#      conexion psql a una base LOCAL y VACIA, por socket Unix.
#      Reconstruye en el orden de sql/README.md y compara el
#      catalogo resultante con la evidencia.
#
# Uso:
#   tests/m1b_equivalencia.sh
#   tests/m1b_equivalencia.sh VIVA.txt COMPLEMENTARIA.txt
#   M1B_REPLAY_DB="host=/ruta/socket port=5432 dbname=m1b user=postgres" \
#     tests/m1b_equivalencia.sh VIVA.txt COMPLEMENTARIA.txt
#
# Nunca apuntar M1B_REPLAY_DB a Supabase: el guion crea roles,
# esquemas y tablas. Rechaza conexiones que no sean por socket.
# ============================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"

SHA_VIVA="BB4C4AB07CCD9E05D81906AA844E9C152E818A20E94E3B62B46737FC01E951E3"
SHA_COMP="2D422FFACE75EB761D20F343800D16F16B4B7EA924CFF5CF553F8CFFCE1930EE"

if [ $# -ne 0 ] && [ $# -ne 2 ]; then
  echo "ERROR: se esperan 0 o 2 argumentos (evidencia viva y complementaria)." >&2
  exit 2
fi

if [ $# -eq 2 ]; then
  for par in "$1:$SHA_VIVA" "$2:$SHA_COMP"; do
    f="${par%:*}"; esperado="${par##*:}"
    if [ ! -f "$f" ]; then
      echo "ERROR: no existe el archivo de evidencia: $f" >&2; exit 2
    fi
    real="$(sha256sum "$f" | cut -d' ' -f1 | tr 'a-f' 'A-F')"
    if [ "$real" != "$esperado" ]; then
      echo "ERROR: SHA-256 de $f no coincide (esperado $esperado)." >&2; exit 2
    fi
  done
fi

python3 - "$@" <<'PYEOF'
import os, re, subprocess, sys

args = sys.argv[1:]
fallos = []
def ok(cond, msg):
    print(('  ok    ' if cond else '  FALLO ') + msg)
    if not cond:
        fallos.append(msg)

def leer(p):
    with open(p, encoding='utf-8') as f:
        return f.read()

NUEVOS = ['030_material_baja', '031_jerga_planta', '032_busquedas_sin_resultado',
          '033_perfiles_destinatarios', '034_solicitudes_materiales',
          '035_funciones_consulta', '036_solicitud_materiales_vivo']
sql = {n: leer(f'sql/{n}.sql') for n in NUEVOS}
todo = '\n'.join(sql.values())

FUNCIONES = {
  'consultar_materiales':
    ('035_funciones_consulta', 'p_consulta text, p_limite integer DEFAULT 5, p_desde integer DEFAULT 0',
     'jsonb', 'plpgsql', 'STABLE SECURITY DEFINER', "'public', 'extensions'", 'text, integer, integer'),
  'consultar_sin_existencias':
    ('035_funciones_consulta', 'p_consulta text, p_limite integer DEFAULT 5',
     'jsonb', 'plpgsql', 'STABLE SECURITY DEFINER', "'public', 'extensions'", 'text, integer'),
  'es_material_baja':
    ('030_material_baja', 'p_texto text', 'boolean', 'sql', 'IMMUTABLE', "'public'", 'text'),
  'mi_historial':
    ('035_funciones_consulta', 'p_limite integer DEFAULT 20',
     'jsonb', 'sql', 'STABLE SECURITY DEFINER', "'public'", 'integer'),
  'registrar_solicitud':
    ('035_funciones_consulta', 'p_mensaje text, p_items jsonb, p_ms integer DEFAULT NULL::integer',
     'uuid', 'plpgsql', 'SECURITY DEFINER', "'public'", 'text, jsonb, integer'),
  'enviar_solicitud_materiales':
    ('036_solicitud_materiales_vivo', 'p_solicitante text, p_orden text, p_materiales jsonb',
     'jsonb', 'plpgsql', 'SECURITY DEFINER', "'public'", 'text, text, jsonb'),
}
ROLES = ['public', 'anon', 'authenticated', 'service_role']

def def_versionada(nombre):
    m = re.search(r'(CREATE OR REPLACE FUNCTION public\.' + nombre + r'\(.*?\n\$function\$);',
                  todo, re.S)
    return m.group(1) if m else None

# ------------------------------------------------------------
print('1. Estatico')
# ------------------------------------------------------------
for n, (arch, firma, ret, leng, vol, sp, ident) in FUNCIONES.items():
    d = def_versionada(n)
    ok(d is not None and d in sql[arch], f'{n}: definida en {arch}')
    if d is None:
        continue
    cab = d.split('AS $function$')[0]
    ok(f'public.{n}({firma})\n RETURNS {ret}\n LANGUAGE {leng}\n {vol}\n SET search_path TO {sp}\n' in cab,
       f'{n}: firma, retorno, lenguaje, volatilidad, SECURITY, search_path')
    for r in ROLES:
        ok(f'grant execute on function public.{n}({ident}) to {r};' in sql[arch],
           f'{n}: GRANT EXECUTE a {r}')

creaciones = re.findall(r'create (?:or replace )?function\s+(?:public\.)?(\w+)', todo, re.I)
ok(sorted(creaciones) == sorted(FUNCIONES), '6 funciones, sin sobrecargas ni extras')
for n in FUNCIONES:
    en_otros = [f for f in os.listdir('sql') if f.endswith('.sql') and f[:-4] not in NUEVOS
                and re.search(r'create\s+(or\s+replace\s+)?function\s+(public\.)?' + n + r'\s*\(',
                              leer('sql/' + f), re.I)]
    esperado = ['024_solicitudes_materiales.sql'] if n == 'enviar_solicitud_materiales' else []
    ok(en_otros == esperado, f'{n}: sin otra definicion fuera de M1-B {esperado or ""}')

TABLAS = {'jerga_planta': ('031_jerga_planta', 11, 2, 3),
          'busquedas_sin_resultado': ('032_busquedas_sin_resultado', 15, 1, 3),
          'solicitudes_materiales': ('034_solicitudes_materiales', 19, 3, 3)}
tot_col = tot_idx = tot_pol = 0
for t, (arch, ncol, nidx, npol) in TABLAS.items():
    s = sql[arch]
    m = re.search(r'create table public\.' + t + r' \((.*?)\n\);', s, re.S)
    ok(m is not None, f'{t}: CREATE TABLE en {arch}')
    cols = [l for l in m.group(1).split('\n')
            if l.strip() and not l.strip().startswith(('constraint', 'check', 'foreign'))] if m else []
    ok(len(cols) == ncol, f'{t}: {len(cols)} columnas (esperadas {ncol})')
    idx = re.findall(r'create index (\w+) on public\.' + t, s)
    ok(len(idx) == nidx, f'{t}: {len(idx)} indices ademas de PK/UNIQUE (esperados {nidx})')
    pol = re.findall(r'create policy (\w+) on public\.' + t, s)
    ok(len(pol) == npol, f'{t}: {len(pol)} politicas (esperadas {npol})')
    ok(f'alter table public.{t} enable row level security;' in s, f'{t}: RLS activado')
    ok('force row level security' not in s.lower(), f'{t}: sin FORCE RLS (como produccion)')
    for r in ROLES[1:]:
        ok(f'grant all on table public.{t} to {r};' in s, f'{t}: GRANT ALL a {r}')
    tot_col += len(cols); tot_idx += len(idx); tot_pol += len(pol)
    fuera = [f for f in os.listdir('sql') if f.endswith('.sql') and f[:-4] != arch
             and re.search(r'create\s+table\s+(if\s+not\s+exists\s+)?(public\.)?' + t + r'\b',
                           leer('sql/' + f), re.I)]
    ok(fuera == [], f'{t}: creada solo en {arch}')
ok(tot_col == 45, f'45 columnas en las 3 tablas ({tot_col})')
ok(tot_pol == 9, f'9 politicas ({tot_pol})')
# 10 indices vivos = 6 explicitos + 3 de PK + uq_jerga, que nace de su UNIQUE
ok(tot_idx == 6, f'6 indices explicitos + 3 PK + 1 UNIQUE = 10 ({tot_idx})')

for patron in [r'create\s+trigger', r'create\s+sequence', r'\bserial\b', r'generated\s+.*identity',
               r'^\s*revoke\b', r'drop\s+table', r'drop\s+schema', r'^\s*truncate\b',
               r'^\s*delete\s+from', r'^\s*update\s+public', r'^\s*insert\s+into',
               r'owner\s+to', r'\bcascade\b', r'alter\s+default\s+privileges']:
    hallado = [n for n, s in sql.items()
               if re.search(patron, re.sub(r'\$function\$.*?\$function\$', '', s, flags=re.S),
                            re.I | re.M)]
    ok(hallado == [], f'sin "{patron}" fuera de cuerpos de funcion {hallado or ""}')

p = sql['033_perfiles_destinatarios']
ok("add column area text default 'mantenimiento'::text;" in p, 'perfiles.area: text, nullable, default mantenimiento')
ok('add column recibe_solicitudes boolean not null default false;' in p,
   'perfiles.recibe_solicitudes: boolean not null default false')
ok('create index idx_perfiles_destinatarios on public.perfiles\n  using btree (area) where (recibe_solicitudes = true);' in p,
   'idx_perfiles_destinatarios')
ok('create table' not in p and 'add constraint' not in p, '033 no recrea perfiles ni inventa restricciones')

# PENDIENTE-020: si alguien "corrige" uno de los dos lados, esto falla.
s34, s36 = sql['034_solicitudes_materiales'], sql['036_solicitud_materiales_vivo']
ok("comment on column public.solicitudes_materiales.orden_trabajo is\n  'Siete digitos exactos, sin letras ni simbolos.';" in s34,
   'PENDIENTE-020: comentario conserva "Siete digitos"')
CHK = "check (orden_trabajo is null or orden_trabajo ~ '^[0-9]{8}$'::text) not valid;"
ok(CHK in s34 and CHK in s36, 'PENDIENTE-020: CHECK de 8 digitos NOT VALID en 034 y 036')
ok("v_orden !~ '^[0-9]{8}$'" in s36 and 'exactamente 8 digitos' in s36,
   'enviar_solicitud_materiales: valida 8 digitos')
ok('with check (true);' in s34, 'solicitudes_mat_actualizacion conserva WITH CHECK true')

readme = leer('sql/README.md')
orden = re.findall(r'^\| (\d{3}) \| (\w+) \|', readme, re.M)
pos = {f'{a}_{b}': i for i, (a, b) in enumerate(orden)}
for n in NUEVOS:
    ok(n in pos, f'README: {n} en la tabla de orden')
for antes, despues in [('033_perfiles_destinatarios', '023_roles_solicitantes'),
                       ('033_perfiles_destinatarios', '034_solicitudes_materiales'),
                       ('030_material_baja', '013_agrupacion'),
                       ('031_jerga_planta', '014_sinonimos'), ('031_jerga_planta', '020_jerga'),
                       ('032_busquedas_sin_resultado', '015_busquedas_fallidas'),
                       ('032_busquedas_sin_resultado', '019_metricas'),
                       ('032_busquedas_sin_resultado', '022_ver_mas'),
                       ('034_solicitudes_materiales', '024_solicitudes_materiales'),
                       ('024_solicitudes_materiales', '036_solicitud_materiales_vivo'),
                       ('013_agrupacion', '035_funciones_consulta'),
                       ('021_feedback_motivo', '035_funciones_consulta')]:
    ok(pos.get(antes, 99) < pos.get(despues, -1), f'README: {antes} antes de {despues}')

consumidores = {'js/search.js': ['consultar_materiales', 'consultar_sin_existencias'],
                'js/feedback.js': ['registrar_solicitud', 'mi_historial']}
for f, ns in consumidores.items():
    js = leer(f)
    for n in ns:
        ok(re.search(r"rpc\(\s*['\"]" + n + r"['\"]", js) is not None, f'{f} sigue llamando a {n}')

if not args:
    print('\nEVIDENCIA NO PROPORCIONADA: se omiten los niveles 2 y 3.')
    print('Para compararlos: tests/m1b_equivalencia.sh VIVA.txt COMPLEMENTARIA.txt')
    sys.exit(1 if fallos else 0)

# ------------------------------------------------------------
print('\n2. Evidencia')
# ------------------------------------------------------------
viva, comp = leer(args[0]), leer(args[1])

def registros(texto, seccion):
    m = re.search(r'=+\n' + re.escape(seccion) + r'.*?\n=+\n(.*?)(?:\n=+\n|\Z)', texto, re.S)
    if not m:
        return []
    out = []
    for bloque in re.split(r'\n?--- REGISTRO \d+ ---\n', m.group(1))[1:]:
        campos, clave = {}, None
        for linea in bloque.split('\n'):
            if re.fullmatch(r'[a-z_]+:', linea):
                clave = linea[:-1]; campos[clave] = []
            elif clave:
                campos[clave].append(linea)
        out.append({k: '\n'.join(v).strip('\n') for k, v in campos.items()})
    return out

evid_fun = registros(viva, '2. FUNCIONES') + registros(comp, '4. ENVIAR_SOLICITUD_MATERIALES')
ok(len(evid_fun) == 6, f'6 funciones en evidencia ({len(evid_fun)})')
ACL = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
for r in evid_fun:
    n = r['nombre']
    ok(def_versionada(n) == r['definicion'], f'{n}: definicion identica byte a byte a pg_get_functiondef')
    ok(r['acl'] == ACL, f'{n}: ACL vivo = PUBLIC, anon, authenticated, service_role (+ owner)')
    ok(r['propietario'] == 'postgres', f'{n}: propietario postgres')

cols = registros(viva, '6. TABLAS — COLUMNAS')
cons = registros(viva, '7. TABLAS — RESTRICCIONES')
idxs = registros(viva, '8. TABLAS — INDICES')
pols = registros(viva, '10. TABLAS — RLS')
tabs = registros(viva, '5. TABLAS — RESUMEN')
ok((len(tabs), len(cols), len(cons), len(idxs), len(pols)) == (3, 45, 15, 10, 9),
   f'evidencia: 3 tablas, 45 columnas, 15 restricciones, 10 indices, 9 politicas '
   f'({len(tabs)}, {len(cols)}, {len(cons)}, {len(idxs)}, {len(pols)})')
ok('9. TABLAS — TRIGGERS' in viva and re.search(r'TRIGGERS\n=+\n<SIN REGISTROS>', viva) is not None,
   'evidencia: 0 triggers')
ok(re.search(r'SECUENCIAS ASOCIADAS\n=+\n<SIN REGISTROS>', viva) is not None, 'evidencia: 0 secuencias')

db = os.environ.get('M1B_REPLAY_DB')
if not db:
    print('\nM1B_REPLAY_DB no definida: se omite el nivel 3 (replay).')
    sys.exit(1 if fallos else 0)

# ------------------------------------------------------------
print('\n3. Replay local')
# ------------------------------------------------------------
if not re.search(r'host=/', db) or re.search(r'supabase|pooler|amazonaws', db, re.I):
    print('ERROR: M1B_REPLAY_DB debe ser una base local por socket Unix (host=/...).')
    sys.exit(2)

def psql(*a, entrada=None):
    return subprocess.run(['psql', db, '-X', '-q', '-v', 'ON_ERROR_STOP=1', *a],
                          input=entrada, capture_output=True, text=True)

# Separadores ASCII de unidad y registro: las definiciones
# llevan saltos de linea y tabuladores.
def consulta(q):
    r = psql('-At', '-F', '\x1f', '-R', '\x1e', '-c', q)
    if r.returncode:
        raise SystemExit('ERROR en consulta de replay: ' + r.stderr)
    return [l.split('\x1f') for l in r.stdout.rstrip('\n').split('\x1e') if l != '']

if consulta("select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace "
            "where n.nspname = 'public'")[0][0] != '0':
    print('ERROR: la base de replay no esta vacia. Usa una base desechable nueva.')
    sys.exit(2)

# Minimo de Supabase que la cadena da por hecho. Nada mas.
STUBS = r'''
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin; end if;
end $$;
create schema if not exists extensions;
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key);
create or replace function auth.uid() returns uuid language sql stable as
  $f$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $f$;
'''
r = psql('-c', STUBS)
ok(r.returncode == 0, 'stubs Supabase (roles, auth.uid, esquema extensions)')
nombre_db = consulta('select current_database()')[0][0]
psql('-c', f'alter database "{nombre_db}" set search_path = "$user", public, extensions')

# PENDIENTE-022: el 002 versionado tiene una cadena sin cerrar.
# Para poder medir M1-B se corrige SOLO en memoria; el archivo
# del repositorio no se toca.
def texto_archivo(nombre):
    ruta = f'sql/{nombre}.sql' if os.path.exists(f'sql/{nombre}.sql') else f'{nombre}.sql'
    if not os.path.exists(ruta):
        return None
    t = leer(ruta)
    if nombre == '002_schema':
        roto = "'PENDIENTE-017: blancos pendientes de aclarar. Se guardan como NULL.\n"
        if roto in t:
            print('  aviso 002_schema: cadena sin cerrar corregida solo en memoria (PENDIENTE-022)')
            t = t.replace(roto, roto[:-1] + "';\n")
    return t

PREVIOS_CONOCIDOS = {'025_correo'}  # PENDIENTE-022
for num, nom in orden:
    n = f'{num}_{nom}'
    t = texto_archivo(n)
    if t is None:
        print(f'  omit  {n}: no existe en el repositorio')
        continue
    r = psql('-f', '-', entrada=t)
    if r.returncode == 0:
        print(f'  ok    replay {n}')
    elif n in PREVIOS_CONOCIDOS:
        print(f'  aviso replay {n}: defecto previo a M1-B (PENDIENTE-022)')
    else:
        err = next((l for l in r.stderr.splitlines() if 'ERROR' in l), r.stderr.strip())
        ok(False, f'replay {n}: {err}')

def norm(x):
    return re.sub(r'\s+', ' ', x).strip()

T = "('busquedas_sin_resultado','jerga_planta','solicitudes_materiales')"
vivas = {(c['tabla'], c['columna']): (c['tipo'], c['not_null'], c['valor_default'], c['comentario'])
         for c in cols}
rep = {(a, b): (c, d, e, f) for a, b, c, d, e, f in consulta(f'''
  select c.relname, a.attname, format_type(a.atttypid, a.atttypmod),
         case when a.attnotnull then 'True' else 'False' end,
         coalesce(pg_get_expr(d.adbin, d.adrelid), '<NULL>'),
         coalesce(col_description(c.oid, a.attnum), '<NULL>')
  from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
  join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
  left join pg_attrdef d on d.adrelid = c.oid and d.adnum = a.attnum
  where c.relname in {T}''')}
ok(rep == vivas, f'45 columnas: tipo, NOT NULL, default y comentario identicos ({len(rep)})')
orden_vivo = [(c['tabla'], c['columna']) for c in cols]
orden_rep = [tuple(x) for x in consulta(f'''
  select c.relname, a.attname from pg_class c join pg_attribute a on a.attrelid = c.oid
  where c.relnamespace = 'public'::regnamespace and c.relname in {T} and a.attnum > 0
    and not a.attisdropped order by c.relname, a.attnum''')]
ok(orden_rep == orden_vivo, 'columnas en el mismo orden que produccion')

pg = int(consulta('show server_version_num')[0][0])
rep_cons = {(a, b): (c, d) for a, b, c, d in consulta(f'''
  select conrelid::regclass::text, conname, contype, pg_get_constraintdef(oid)
  from pg_constraint where conrelid::regclass::text in {T}''')}
viv_cons = {(c['tabla_origen'], c['nombre']): (c['tipo'], c['definicion']) for c in cons}
# PG16 y PG17 imprimen distinto los parentesis de un CHECK. Para
# no aceptar diferencias a ojo, se anade la definicion viva
# literal sobre la misma tabla, en una transaccion que se
# deshace, y se compara lo que imprime este mismo servidor.
def reimpresa(tabla, definicion):
    r = psql('-At', '-c', f'''begin;
      alter table public.{tabla} add constraint m1b_tmp {definicion};
      select pg_get_constraintdef(oid) from pg_constraint
        where conrelid = 'public.{tabla}'::regclass and conname = 'm1b_tmp';
      rollback;''')
    return r.stdout.strip() if r.returncode == 0 else None
for k, (tipo, d) in list(viv_cons.items()):
    if tipo == 'c' and rep_cons.get(k, (None, None))[1] != d:
        rd = reimpresa(k[0], d)
        if rd is not None and rep_cons.get(k) == (tipo, rd):
            print(f'  aviso {k[1]}: igual a la definicion viva reimpresa por PG{pg // 10000}')
            viv_cons[k] = (tipo, rd)
ok(rep_cons == viv_cons, f'15 restricciones identicas, incluido NOT VALID ({len(rep_cons)})')
if rep_cons != viv_cons:
    for k in sorted(set(rep_cons) | set(viv_cons)):
        if rep_cons.get(k) != viv_cons.get(k):
            print(f'        {k}: vivo={viv_cons.get(k)} replay={rep_cons.get(k)}')

rep_idx = {(a, b): c for a, b, c in consulta(f'''
  select tablename, indexname, indexdef from pg_indexes
  where schemaname = 'public' and tablename in {T}''')}
viv_idx = {(i['tabla'], i['nombre']): i['definicion'] for i in idxs}
ok(rep_idx == viv_idx, f'10 indices identicos ({len(rep_idx)})')

rep_pol = {(a, b): (c, d, e, norm(f), norm(g)) for a, b, c, d, e, f, g in consulta(f'''
  select tablename, policyname, permissive, roles::text, cmd,
         coalesce(qual, '<NULL>'), coalesce(with_check, '<NULL>')
  from pg_policies where schemaname = 'public' and tablename in {T}''')}
viv_pol = {(p['tabla'], p['nombre']): (p['permissive'], p['roles'], p['cmd'], norm(p['qual']),
                                       norm(p['with_check'])) for p in pols}
ok(rep_pol == viv_pol, f'9 politicas identicas: comando, roles, USING y WITH CHECK ({len(rep_pol)})')

rep_tab = {a: (b, c, d, e) for a, b, c, d, e in consulta(f'''
  select relname, case when relrowsecurity then 'True' else 'False' end,
         case when relforcerowsecurity then 'True' else 'False' end, relreplident,
         obj_description(oid, 'pg_class')
  from pg_class where relnamespace = 'public'::regnamespace and relname in {T}''')}
viv_tab = {t['tabla']: (t['rls_activo'], t['rls_forzado'], t['replica_identity'], t['comentario'])
           for t in tabs}
ok(rep_tab == viv_tab, 'RLS activo, sin FORCE, replica identity y comentario de tabla identicos')

# PG16 no tiene MAINTAIN (m): se compara el ACL vivo sin esa letra.
rep_acl = {a: b for a, b in consulta(f'''
  select relname, relacl::text from pg_class
  where relnamespace = 'public'::regnamespace and relname in {T}''')}
viv_acl = {t['tabla']: t['acl'] for t in tabs}
if pg < 170000:
    viv_acl = {k: v.replace('arwdDxtm', 'arwdDxt') for k, v in viv_acl.items()}
    print('  aviso ACL de tablas: servidor < 17, MAINTAIN (m) no verificable fisicamente')
ok(rep_acl == viv_acl, 'ACL de las 3 tablas identico al vivo')

ok(consulta(f"select count(*) from pg_trigger where not tgisinternal and tgrelid::regclass::text in {T}")
   == [['0']], '0 triggers en las 3 tablas')
ok(consulta(f"select count(*) from pg_depend d join pg_class s on s.oid = d.objid and s.relkind = 'S' "
            f"where d.refobjid::regclass::text in {T}") == [['0']], '0 secuencias asociadas')

rep_fun = {a: (b, c) for a, b, c in consulta('''
  select p.proname, pg_get_functiondef(p.oid), coalesce(p.proacl::text, '')
  from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in
  ('consultar_materiales','consultar_sin_existencias','es_material_baja','mi_historial',
   'registrar_solicitud','enviar_solicitud_materiales')''')}
ok(len(rep_fun) == 6, f'6 funciones en el replay, sin sobrecargas ({len(rep_fun)})')
for r in evid_fun:
    n = r['nombre']
    d, acl = rep_fun.get(n, ('', ''))
    ok(d.rstrip('\n') == r['definicion'], f'replay {n}: pg_get_functiondef identico al vivo')
    ok(acl == r['acl'], f'replay {n}: ACL identico al vivo')

compl = {c['columna']: c for c in registros(comp, '1. PERFILES — COLUMNAS')}
rep_perf = {a: (b, c, d, e) for a, b, c, d, e in consulta('''
  select a.attname, format_type(a.atttypid, a.atttypmod),
         case when a.attnotnull then 'True' else 'False' end,
         coalesce(pg_get_expr(d.adbin, d.adrelid), '<NULL>'), col_description(a.attrelid, a.attnum)
  from pg_attribute a left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
  where a.attrelid = 'public.perfiles'::regclass and a.attname in ('area','recibe_solicitudes')''')}
for n, c in compl.items():
    ok(rep_perf.get(n) == (c['tipo'], c['not_null'], c['valor_default'], c['comentario']),
       f'perfiles.{n}: tipo, NOT NULL, default y comentario identicos')
viv_pidx = [i['definicion'] for i in registros(comp, '3. PERFILES — INDICES')
            if i['nombre'] == 'idx_perfiles_destinatarios']
ok(consulta("select indexdef from pg_indexes where indexname = 'idx_perfiles_destinatarios'")
   == [[viv_pidx[0]]], 'idx_perfiles_destinatarios identico al vivo')

# Semantica minima de la contradicción 7/8, ejecutada de verdad.
r = psql('-c', '''
  insert into auth.users values ('00000000-0000-0000-0000-000000000001');
  insert into public.perfiles (id, correo, nombre, rol)
    values ('00000000-0000-0000-0000-000000000001', 'x@x', 'Prueba', 'admin');
  begin;
  insert into public.solicitudes_materiales (usuario_id, solicitante, rol_solicitante, orden_trabajo, materiales)
    values ('00000000-0000-0000-0000-000000000001', 'Prueba', 'admin', '12345678', '[]');
  rollback;''')
ok(r.returncode == 0, 'CHECK acepta orden de trabajo de 8 digitos')
r = psql('-c', '''insert into public.solicitudes_materiales
  (usuario_id, solicitante, rol_solicitante, orden_trabajo, materiales)
  values ('00000000-0000-0000-0000-000000000001', 'Prueba', 'admin', '1234567', '[]');''')
ok(r.returncode != 0 and 'orden_trabajo_check' in r.stderr, 'CHECK rechaza orden de trabajo de 7 digitos')
r = consulta("select public.es_material_baja('tornillo bloqueado'), public.es_material_baja('tornillo'), "
             "public.es_material_baja(null)")
ok(r == [['t', 'f', 'f']], 'es_material_baja: bloquead -> true, normal -> false, null -> false')

sys.exit(1 if fallos else 0)
PYEOF

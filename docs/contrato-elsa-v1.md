# Contrato Materiales–ELSA V1 — definición canónica del proveedor

**Versión:** `"1"` · **Estado:** implementado, pendiente de despliegue
**Transporte:** RPC de Supabase sobre HTTPS/PostgREST
**Implementación:** [`sql/037_contrato_elsa_v1.sql`](../sql/037_contrato_elsa_v1.sql)
**Pruebas del proveedor:** [`tests/m1c_contrato_v1.sh`](../tests/m1c_contrato_v1.sh)

Este documento es lo que **Materiales se compromete a cumplir**. La gobernanza
del contrato —quién puede romperlo y con qué constancia— vive en
[`contrato-elsa.md`](contrato-elsa.md).

El **diseño** del contrato está decidido en el repositorio de ELSA, en sus ADR
0021, 0024, 0027 y 0028. Este documento **no los reescribe ni los sustituye**:
describe cómo el proveedor los cumple.

---

## 1. Por qué existe una fachada

ELSA no consume el buscador de Materiales, y no es una preferencia de estilo.

El buscador responde **«¿qué se parece a este texto?»**. Para un ingeniero
buscando un repuesto por descripción, eso es exactamente lo que hace falta. Pero
`buscar_materiales` normaliza la consulta y **no** el valor almacenado, de modo
que un código que no coincide literalmente **cae en silencio a similitud sobre
la descripción**. Para una identificación autoritativa eso es un fallo grave y
además invisible: el sistema respondería con un material que nadie pidió, sin
avisar de que ya no está respondiendo a la pregunta original.

La fachada responde una pregunta distinta: **«¿qué es este código?»**. Y aporta
cinco cosas que ninguna superficie anterior daba:

1. acota la coincidencia a exacta por código;
2. adjunta la vigencia del inventario;
3. adjunta la cobertura del snapshot;
4. tipa la ausencia en lugar de devolver cero filas mudas;
5. declara su propia versión de contrato.

**No duplica el motor.** Reutiliza las reglas de negocio de Materiales —RN-030
para existencias, RN-033 para multiubicación, RN-034 para la señal de baja—
porque esa lógica es propiedad de Materiales.

## 2. Operaciones

| Operación | RPC | Disponible en Piloto 0.1 |
|---|---|---|
| `lookup_material_by_code` | `public.elsa_v1_lookup_material_by_code(text, text)` | **Sí** |
| `get_inventory_status` | `public.elsa_v1_get_inventory_status(text)` | **Sí** |
| `get_contract_descriptor` | `public.elsa_v1_get_contract_descriptor()` | **Sí** |
| `search_materials_by_text` | — | **No.** Declarada, sin implementar |

`search_materials_by_text` **no tiene RPC**. Está declarada en el descriptor con
`available: false` y `transport_binding: null`. Habilitarla solo por simetría
habría sido prometer algo que nadie cumple.

## 3. Descriptor

```json
{
  "contract_version": "1",
  "transport": "supabase_rpc_postgrest_https",
  "operations": [
    {"name": "lookup_material_by_code",  "transport_binding": "rpc:elsa_v1_lookup_material_by_code",  "available": true,  "deprecated": false},
    {"name": "get_inventory_status",     "transport_binding": "rpc:elsa_v1_get_inventory_status",     "available": true,  "deprecated": false},
    {"name": "get_contract_descriptor",  "transport_binding": "rpc:elsa_v1_get_contract_descriptor",  "available": true,  "deprecated": false},
    {"name": "search_materials_by_text", "transport_binding": null,                                   "available": false, "deprecated": false}
  ],
  "unsupported_fields": ["inventory.extracted_at"]
}
```

`contract_version` es una **cadena**, no un entero: permite cambios compatibles
sin renumerar.

El descriptor es el único canal por el que ELSA sabe qué versión habla esta
fachada. **La versión nunca se adivina:** si el descriptor no responde, el
consumidor declara la versión desconocida y se degrada.

`unsupported_fields` declara lo que el contrato **no transporta todavía**. Es un
canal distinto del `null` de una respuesta concreta: el descriptor declara la
**capacidad**, el `null` declara el **caso**.

## 4. Request

```json
{ "contract_version": "1", "material_code": "10000001" }
```

Dos campos. **Nada más.** Quedan prohibidos la pregunta del usuario, los
alcances de ELSA, el activo, el BOM, el historial y el identificador de usuario
en el cuerpo —ese viaja en el JWT, y solo ahí—. Materiales no participa en el
modelo de autorización de ELSA y no debe recibir contexto que no use.

`material_code` es **cadena decimal exacta**: sin añadir ceros, sin quitarlos y
sin relleno.

## 5. Respuesta — tres ejes ortogonales

```json
{
  "contract_version": "1",
  "call_status": "OK",
  "inventory": { },
  "coverage": { },
  "results": [
    { "requested_code": "…", "outcome": "MATCHED",
      "absence": null, "material": { }, "match": { }, "attribution": { } }
  ]
}
```

Tres ejes independientes, porque un material **puede encontrarse y la cobertura
seguir siendo desconocida** a la vez. Un enum plano obligaría a elegir entre dos
verdades simultáneas.

`results` es una **lista desde V1**, aunque V1 envíe un solo código: añadir lote
después será aditivo en el request y cero cambios en la respuesta.

### 5.1 `call_status`

| Valor | Cuándo | Emitido por esta fachada |
|---|---|---|
| `OK` | Respondió sobre una versión activa | Sí |
| `NO_ACTIVE_INVENTORY` | No hay versión activa. **No es una ausencia** | Sí |
| `REJECTED` | Sin sesión válida o perfil inactivo | Sí |
| `UNAVAILABLE` | Fallo técnico de transporte | **No.** Lo observa el consumidor, no el proveedor |

`UNAVAILABLE` no puede emitirlo esta fachada: si la RPC no responde, no hay
respuesta que llevarlo. Lo traduce el adaptador de ELSA.

### 5.2 `outcome`

`MATCHED` · `NOT_RETURNED`.

Se llama `NOT_RETURNED` y no `NOT_FOUND` a propósito: «no encontrado» sugiere que
se buscó en todas partes. **`NOT_RETURNED` dice exactamente lo ocurrido.**

### 5.3 `inventory`

```json
{ "version_number": 17, "loaded_at": "…", "row_count": 54494,
  "source_file_label": "…", "extracted_at": null }
```

| Campo | Origen |
|---|---|
| `version_number` | `versiones_datos.numero` |
| `loaded_at` | `versiones_datos.finalizado_en` — **el momento en que terminó la carga. Nada más** |
| `row_count` | `versiones_datos.filas_cargadas`. Recuento de carga, **nunca** medida de cobertura |
| `source_file_label` | `versiones_datos.archivo_nombre`. **Etiqueta opaca**; prohibido extraer de ella una fecha |
| `extracted_at` | **Siempre `null`** |

`extracted_at: null` significa **«este contrato no transporta la fecha de
extracción desde SAP»**. **No** significa que SAP carezca de ella: el esquema de
Materiales no la registra, que es una afirmación sobre Materiales, no sobre SAP.
`loaded_at` **no la sustituye**, ni siquiera como aproximación.

Si la versión activa no tuviera `finalizado_en`, la fachada responde
`NO_ACTIVE_INVENTORY` en vez de emitir un `inventory` con `loaded_at` nulo: un
bloque con campos obligatorios en nulo sería un defecto de contrato.

### 5.4 `coverage`

```json
{ "state": "UNKNOWN", "observed_scope": null, "expected_scope": null,
  "missing_scope": null, "scope_kind": null, "declared_at": null }
```

**`UNKNOWN` es el estado real hoy, y no es un error.** `observed_scope` debe
provenir de metadata de ingestión que Materiales pueda sostener
contractualmente, y esa metadata **no existe todavía**.

Dos prohibiciones que la implementación respeta:

- **la cobertura no se deriva de los valores de `ambito` de las filas.** Contar
  los ámbitos de los que llegó algo responde a una pregunta distinta de qué
  ámbito intentó cubrir la carga;
- **`UNKNOWN` no se disfraza de completo ni de incompleto.**

### 5.5 Ausencia

```json
{ "reason": "NOT_RETURNED_BY_SOURCE", "authoritative": false, "basis": "…" }
```

**Un solo valor, y es deliberado.** Es la única causa que Materiales puede
demostrar hoy sobre un código concreto. `authoritative` es **siempre falso**: en
V1 **no existe ningún valor que signifique inexistencia**.

`NOT_RETURNED` **no demuestra que el material no exista en SAP.**

### 5.6 `material`

`code` es `FACTUAL_SAP`. `descripcion`, `unidad` y `material_antiguo` son
`FACTUAL_SAP_AGGREGATED`: llegan por agregaciones independientes por campo y
**no se garantiza que procedan de la misma fila**. Está prohibido combinarlos
afirmando que describen una fila concreta.

`total_disponible`, `total_comprometido` y `dado_de_baja` son
`DERIVED_BY_MATERIALES` y llegan con su regla:

```json
{ "value": 6, "rule_reference": "RN-030", "rule_verifiable": false }
```

`rule_verifiable` es **falso** en V1: las reglas están publicadas en prosa, y la
prueba contractual que las demostraría no existe todavía.

`dado_de_baja` es una **señal no accionable**: acompaña al hecho como
advertencia, y no oculta, no filtra, no ordena y no degrada ningún estado.

`stock_locations` es una colección con **una entrada por fila** del material.
**Todos los atributos de un elemento proceden de la misma fila** y pueden
afirmarse juntos; los escalares agregados, no.

### 5.7 `match` y `attribution`

`match_origin` vale `EXACT_MATERIAL_CODE` u `OLD_MATERIAL_CODE`. **`OTHER_MATCH`
es inadmisible en un lookup exacto** y esta fachada no lo emite nunca.

`attribution` acompaña a todo hecho: `capability`, `source`, `source_version`,
`contract_version`, `read_at` y `match_origin`. `read_at` —cuándo preguntó ELSA—
y `loaded_at` —cuándo terminó la carga— son fechas distintas y no se confunden.

## 6. El invariante del lookup exacto

> Código exacto → coincidencia exacta.
> Sin coincidencia exacta → `NOT_RETURNED`. **Nunca un candidato parecido.**

La implementación **no puede** degradar, porque no consulta el buscador: hace
igualdad literal de cadena sobre `inventario_materiales`. No usa `LIKE`,
`ILIKE`, `similarity()`, comodines, umbrales ni orden por puntaje, y no aplica
`lower`, `trim`, `padding` ni conversión numérica al código pedido.

`normalizar_texto` aparece una sola vez, aplicada **a la descripción** para la
regla de baja, nunca al código.

Las pruebas lo comprueban en las dos direcciones: estáticamente sobre el texto
de la migración, y funcionalmente —el texto exacto de una descripción existente
devuelve `NOT_RETURNED`, y `'123'` no equivale a `'000123'`—.

## 7. Identidad y permisos

La fachada reutiliza `es_usuario_activo()`, el mismo control que ya gobierna
todo acceso: sesión válida (`auth.uid()`) más perfil activo.

- **Sin `service_role`.** ELSA consume con la identidad del usuario, no con una
  credencial administrativa.
- Sin secretos en código, documentación ni pruebas.
- Sin bypass de RLS.
- `EXECUTE` **solo para `authenticated`**, con `REVOKE` explícito a `public` y
  `anon` — obligatorio, porque PostgreSQL concede `EXECUTE` a `PUBLIC` por
  defecto en cada función nueva.

`get_contract_descriptor` no exige identidad: declara forma, no expone
inventario.

> Los permisos amplios de las funciones **históricas** no se tocaron. Su revisión
> es PENDIENTE-021 y no forma parte de este trabajo.

## 8. Compatibilidad

| Cambio | Clase |
|---|---|
| Añadir un campo opcional a la respuesta | Compatible |
| Añadir un parámetro opcional al request | Compatible |
| Rellenar un campo reservado que valía nulo | Compatible |
| Habilitar `search_materials_by_text` | Compatible: el descriptor ya la declara |
| Quitar o renombrar un campo | **Incompatible** |
| Cambiar el significado de un campo sin cambiar su nombre | **Incompatible, y el más peligroso**: invisible en un diff |
| Cambiar la representación esperada de `material_code` | **Incompatible** |
| Que el lookup exacto deje de garantizar su invariante | **Incompatible** |

Solo el **Contract Owner** puede aprobar un cambio incompatible, y solo con
constancia escrita.

## 9. Responsabilidad del proveedor

Materiales se compromete a:

1. mantener la semántica descrita aquí mientras `contract_version` sea `"1"`;
2. no cambiar el comportamiento del lookup exacto sin cambiar la versión;
3. mantener las pruebas contractuales del proveedor;
4. declarar en el descriptor lo que el contrato no transporta;
5. no presentar como dato de SAP lo que es cálculo de Materiales.

## 10. Límites conocidos de V1

| # | Límite |
|---|---|
| L1 | **La fachada no está desplegada.** Está versionada y probada en local; aplicarla a producción es una fase posterior y autorizada aparte |
| L2 | `coverage` es **siempre `UNKNOWN`**: no existe metadata de ingestión que respalde otra cosa |
| L3 | `rule_verifiable` es **siempre falso**: las reglas derivadas están publicadas en prosa, sin prueba que las demuestre |
| L4 | `extracted_at` **nunca se rellena** |
| L5 | `UNAVAILABLE` no lo emite el proveedor |
| L6 | Sin consulta por lote: el transporte V1 es unitario |
| L7 | La validación local se hizo en PostgreSQL 16; producción es PostgreSQL 17 |

## Ver también

- [`contrato-elsa.md`](contrato-elsa.md) — gobernanza y Contract Owner
- [`reglas-negocio.md`](reglas-negocio.md) — RN-030, RN-033, RN-034
- [`pendientes.md`](pendientes.md) — PENDIENTE-020, 021 y 022, **abiertos**
- ELSA, ADR 0021 · 0024 · 0027 · 0028 — decisiones normativas del contrato

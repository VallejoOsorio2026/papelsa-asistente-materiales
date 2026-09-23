# Contrato Materiales–ELSA

ELSA consulta el inventario de Materiales a través de un contrato versionado.
Este documento es la **fuente de verdad** de quién responde por ese contrato.

El diseño del contrato está decidido en el repositorio de ELSA, en su ADR 0021.
Aquí vive lo que ese ADR sitúa expresamente en este repositorio: la asignación
operativa del rol que lo gobierna.

## El rol

**`Contract Owner Materiales–ELSA`**

Es un **rol de gobernanza contractual**, permanente. Lo ocupa una persona
identificable, y el ocupante puede cambiar sin modificar el ADR que define el
rol.

### No es el rol `admin`

**Esta distinción es deliberada y no debe perderse.**

| | `admin` | `Contract Owner Materiales–ELSA` |
|---|---|---|
| Qué es | Rol técnico de autorización | Rol de gobernanza contractual |
| Dónde se aplica | Base de datos, mediante RLS | Decisiones sobre el contrato |
| Quién lo concede | Administración de la aplicación | Designación explícita, registrada aquí |
| Qué permite | Cargar inventario, gestionar usuarios y reglas, revisar métricas | Aprobar cambios del contrato con ELSA |

**Tener rol técnico `admin` NO convierte a nadie en Contract Owner.** Son
independientes: se puede tener uno sin el otro.

La razón no es formal. El contrato con ELSA existe porque una función de
consulta dejó de estar versionada sin que nadie lo aprobara. Si bastara con
tener `admin` para romper el contrato, esa situación podría repetirse sin
constancia escrita, que es justo lo que el rol previene.

## Ocupante actual

| | |
|---|---|
| **Nombre** | Juan Pablo Vallejo |
| **Contacto** | Directorio corporativo de PAPELSA |
| **Desde** | 2026-09-21 |

**No se publican correos en este repositorio.** Es público, y una dirección
corporativa expuesta aquí queda indexada de forma permanente.

## Continuidad: cómo se sustituye al ocupante

**Sustituir al ocupante es editar esta única sección.** Nada más.

No requiere, y no debe provocar:

- modificar ningún ADR, ni en este repositorio ni en el de ELSA;
- modificar código, esquema, RLS ni configuración;
- modificar el adaptador de ELSA ni ninguna prueba;
- cambio alguno de arquitectura.

El rol es permanente; el ocupante es un dato. Esa separación es lo que permite
que el proyecto cambie de manos sin tocar lo que sostiene el contrato.

## Qué puede hacer el Contract Owner

1. Versionar las reglas y artefactos contractuales Materiales–ELSA en este
   repositorio.
2. Aprobar cambios incompatibles del contrato, **dejando constancia escrita**.
3. Custodiar y mantener las pruebas contractuales del proveedor.
4. Coordinar deprecaciones y comunicar los cambios a los consumidores.
5. Asegurar que la semántica factual de los campos permanezca documentada.
6. Aprobar la retirada de versiones deprecadas cuando se cumplan los requisitos
   contractuales.

## Quién puede romper el contrato

**Solo el Contract Owner, y solo con constancia escrita.**

No lo rompen, y no cuentan como aprobación:

- sustituir una función directamente sobre la base de datos;
- cambiar la interfaz de Materiales;
- cambiar el adaptador en ELSA.

Un cambio incompatible sin constancia escrita **no es un cambio aprobado**: es
una ruptura del contrato.

## Qué vive aquí y qué vive en ELSA

| Repositorio | Contiene |
|---|---|
| **Materiales** *(este)* | La asignación del rol. Y, cuando existan: definición canónica versionada, `contract_version`, descriptor y pruebas contractuales del proveedor |
| **ELSA** | El contrato esperado como pruebas de conformidad, y el ADR que lo decide |

ELSA **referencia** esta asignación; **no la copia**, y **no registra el nombre
ni el contacto del ocupante**. Dos listas de responsables que puedan divergir
son peores que ninguna.

## Estado

**Actualizado el 2026-09-23 por M1-C.**

| Artefacto | Estado |
|---|---|
| Asignación del rol | **Existe.** Es este documento |
| Definición canónica del contrato V1 | **Existe:** [`contrato-elsa-v1.md`](contrato-elsa-v1.md) |
| `contract_version` | **Existe.** Vale `"1"`, y la emite la fachada |
| Descriptor | **Existe:** `elsa_v1_get_contract_descriptor()` |
| Pruebas contractuales del proveedor | **Existen:** [`tests/m1c_contrato_v1.sh`](../tests/m1c_contrato_v1.sh) |
| **Despliegue en producción** | **PENDIENTE.** La fachada está versionada y probada en local; **no se ha aplicado** al proyecto Supabase |

El texto de arriba decía que nada de esto existía, y describía correctamente el
estado hasta M1-B. **M1-C lo cambió**, con una excepción que conviene no
confundir: que el contrato esté escrito y probado no significa que esté vivo.
Aplicarlo a producción es una decisión posterior y explícita.

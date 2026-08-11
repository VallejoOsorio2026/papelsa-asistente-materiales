# Seguridad

## Principio

La seguridad **no** depende de que la página web sea desconocida, ni de ocultar botones,
ni de la visibilidad del repositorio. Depende de autenticación y de políticas de
seguridad a nivel de fila (RLS) aplicadas en la base de datos.

Prueba de aceptación: cualquier persona con la dirección de la aplicación y con todo
el código a la vista debe obtener **cero filas** sin una sesión válida.

## Qué es público y por qué no importa

| Elemento | Visible | Riesgo |
|---|---|---|
| Código HTML, CSS y JavaScript | Sí | Ninguno. No contiene lógica de seguridad |
| Dirección del proyecto de base de datos | Sí | Ninguno por sí sola |
| Clave publicable (`sb_publishable_...`) | Sí | Diseñada para exponerse. Sin sesión válida no lee nada |
| Documentación del repositorio | Sí | Controlado: no incluye códigos internos ni datos |

## Qué nunca puede publicarse

- Archivos Excel o CSV exportados de SAP
- Inventario, existencias o cualquier dato de materiales
- Clave secreta (`sb_secret_...`), que ignora todas las políticas de seguridad
- Contraseña de la base de datos, tokens o credenciales de SAP
- Datos de usuarios

## Decisión sobre la clave secreta

El piloto **no genera clave secreta**. Las operaciones administrativas (carga de
inventario, activación de versiones) se resuelven con el usuario administrador
autenticado más políticas que reconozcan su rol. Si en el futuro se requiriera, su
único lugar válido sería un entorno de servidor, nunca el navegador ni el repositorio.

## Control de acceso

| Situación | Acceso |
|---|---|
| Sin sesión | Ninguno. Cero filas |
| Sesión válida, perfil inactivo | Ninguno |
| Sesión válida, rol `ingeniero` | Consulta de inventario, sus propias solicitudes |
| Sesión válida, rol `admin` | Todo lo anterior más administración |

El registro público de usuarios permanece **desactivado**. Los usuarios se crean por
invitación del administrador.

## Revisión obligatoria antes de cada commit

1. ¿Hay algún archivo de datos? → No hacer commit
2. ¿Aparece alguna clave, contraseña o token? → No hacer commit
3. ¿Se incluyen códigos internos de centros o almacenes? → No hacer commit
4. ¿El contenido tiene sentido siendo público? → Si hay duda, no hacer commit

# Carpeta data

Esta carpeta **no contiene ni contendrá datos reales de SAP**.

Este repositorio es público. Colocar aquí un archivo exportado de SAP expondría el
catálogo de materiales de la organización de forma inmediata e irreversible: aunque
el archivo se borre después, permanece accesible en el historial de commits.

## Regla operativa

El archivo Excel de SAP no se arrastra jamás a una ventana del navegador que tenga
`github.com` en la barra de direcciones.

## Dónde viven los datos

Exclusivamente en la base de datos del proyecto, protegidos por autenticación y
políticas de seguridad a nivel de fila. Se cargan desde el navegador mediante el
importador de la aplicación, sin pasar nunca por este repositorio.

## Convención de archivos locales (fuera de este repositorio)

- `inventario_AAAA-MM-DD_completo.xlsx` — extracción íntegra. Archivo maestro
- `inventario_AAAA-MM-DD_carga.xlsx` — 21 columnas (ADR-005). El que usa el importador

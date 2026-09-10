-- ============================================================
-- 029_recorte_columnas.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- Ejecucion: UNA SOLA VEZ, sobre la base ya existente
-- ============================================================
-- ADR-023: el inventario pasa de 21 a 10 columnas de SAP.
-- Sustituye a ADR-005.
--
-- POR QUE ESTE ARCHIVO EXISTE
-- 002_schema.sql describe como debe quedar la tabla, pero ya
-- se ejecuto y la tabla tiene 65.883 filas. Un CREATE TABLE no
-- se puede repetir. Solo un ALTER modifica lo que ya existe.
-- Este guion es el puente entre lo que hay y lo que 002 dice.
--
-- La funcion cargar_lote_inventario NO va aqui: vive en
-- 008_importacion.sql y se actualiza alli. Duplicarla crearia
-- dos definiciones que pueden divergir en silencio.
--
-- QUE SE ELIMINA Y POR QUE
-- Once columnas que ninguna funcion, ninguna consulta y ninguna
-- pantalla leen. Se cargaban 65.883 veces por version para no
-- usarse nunca. XCentro sale por ADR-009, que ya declaraba que
-- el motor la ignora deliberadamente.
--
-- El motivo principal NO es el disco, que es modesto. Es el
-- peso de cada lote enviado desde el navegador: el JSON repite
-- el nombre de cada campo en cada fila. Con carga semanal daba
-- igual; con tres cargas diarias es la mitad del trafico.
--
-- REVERSIBILIDAD
-- Recuperar una columna cuesta un ALTER, una linea en el
-- importador y una carga. Como habra carga nueva en horas, el
-- coste de deshacer esto es de minutos.
--
-- OJO: DROP COLUMN es instantaneo pero NO libera disco. El
-- espacio se recupera solo, conforme las cargas nuevas escriben
-- filas sin estas columnas y ADR-002 purga las versiones
-- viejas. No ejecutar VACUUM FULL: bloquearia la tabla.
-- ============================================================

begin;

alter table public.inventario_materiales
  drop column if exists xcentro,
  drop column if exists maximo,
  drop column if exists minimo,
  drop column if exists planif_necesidades,
  drop column if exists grupo_compra,
  drop column if exists tipo_material,
  drop column if exists grupo_articulo,
  drop column if exists clase_valoracion,
  drop column if exists cat_val_stock_proyecto,
  drop column if exists caract_planif_nec,
  drop column if exists tam_lote_planif_nec;

comment on table public.inventario_materiales is
  'Inventario SAP. 10 columnas originales (ADR-023, sustituye a ADR-005) '
  'mas las auxiliares derivadas. Las originales NUNCA se modifican (RN-011).';

comment on column public.inventario_materiales.ubicacion is
  'PENDIENTE-017: un 17% de las filas llega vacia. Pendiente de confirmar '
  'si son vacios legitimos o supresion de repetidos en el reporte de SAP. '
  'Blanco se guarda como NULL: incompleto nunca es peor que incorrecto.';

commit;

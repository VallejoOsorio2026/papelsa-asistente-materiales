-- ============================================================
-- 014_sinonimos.sql
-- Proyecto: Asistente Inteligente de Materiales SAP - PAPELSA
-- ============================================================
-- Capa 4 de ADR-011: diccionario de abreviaturas.
--
-- Las descripciones de SAP estan abreviadas (TORN, VVA, ROD)
-- mientras que el ingeniero escribe la palabra completa. Ningun
-- algoritmo de similitud resuelve esto: no son errores de
-- escritura, son abreviaturas.
--
-- Construido a partir del vocabulario real del inventario:
-- las 300 palabras mas frecuentes en 65.883 filas.
--
-- RN-025: todo lo que entra aqui como global_validado es una
-- regla aprobada, no un patron observado.
--
-- Este archivo se AMPLIA cuando se confirmen nuevas
-- equivalencias. No se crean archivos nuevos.
-- ============================================================

insert into public.sinonimos (termino, equivalente, ambito) values

-- ---------- Tipos de material ----------
('tornillo',      'torn',    'global_validado'),
('rodamiento',    'rod',     'global_validado'),
('valvula',       'vva',     'global_validado'),
('manguera',      'mang',    'global_validado'),
('soldadura',     'sold',    'global_validado'),
('soldar',        'sold',    'global_validado'),
('bomba',         'bba',     'global_validado'),
('tarjeta',       'tarj',    'global_validado'),
('interruptor',   'int',     'global_validado'),
('impulsor',      'imp',     'global_validado'),
('motorreductor', 'motored', 'global_validado'),
('motoreductor',  'motored', 'global_validado'),

-- ---------- Caracteristicas ----------
('neumatico',   'neu',    'global_validado'),
('hidraulico',  'hid',    'global_validado'),
('transmision', 'transm', 'global_validado'),
('galvanizado', 'galv',   'global_validado'),
('trifasico',   'trif',   'global_validado'),
('sencillo',    'senc',   'global_validado'),
('sencilla',    'senc',   'global_validado'),
('superior',    'sup',    'global_validado'),
('inferior',    'inf',    'global_validado'),
('posicion',    'pos',    'global_validado'),
('reparacion',  'reparac','global_validado'),
('referencia',  'ref',    'global_validado'),
('calibre',     'cal',    'global_validado'),
('roscado',     'rsc',    'global_validado'),
('rosca',       'rsc',    'global_validado'),
('cuadrado',    'cuad',   'global_validado'),
('cuadrada',    'cuad',   'global_validado'),
('solenoide',   'soln',   'global_validado'),

-- ---------- Tipos de tornilleria ----------
-- BCC: bristol con cabeza · BSC: bristol sin cabeza
('bristol con cabeza', 'bcc', 'global_validado'),
('bristol sin cabeza', 'bsc', 'global_validado'),

-- ---------- Piezas ----------
('acople', 'manzana', 'global_validado'),
('anillo', 'ring',    'global_validado'),
('sello',  'seal',    'global_validado'),
('buje',   'bushing', 'global_validado'),
('brida',  'flange',  'global_validado'),
('brida',  'flanch',  'global_validado'),
('pasador','pin',     'global_validado'),
('juego',  'kit',     'global_validado'),
('juego',  'set',     'global_validado'),

-- ---------- Marcas ----------
('telemecanique', 'telem',   'global_validado'),
('siemens',       'siem',    'global_validado'),
('riel mecano',   'mecano',  'global_validado'),

-- ---------- Unidades y normas ----------
('revoluciones por minuto', 'rpm', 'global_validado'),
('voltaje continuo',        'vdc', 'global_validado'),
('amperios',                'amp', 'global_validado'),
('tonelada',                'ton', 'global_validado'),
('toneladas',               'ton', 'global_validado')

on conflict (termino, equivalente, ambito) do nothing;


-- ============================================================
-- VERIFICACION
-- ============================================================
select ambito, count(*) as cantidad
from public.sinonimos
group by ambito;

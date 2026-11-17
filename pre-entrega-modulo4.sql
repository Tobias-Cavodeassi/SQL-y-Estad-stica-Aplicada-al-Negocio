-- =====================================================================
-- Pre-entrega Módulo 4 - Consultas multicapa para análisis de negocio
-- Autor: Tobías Cavodeassi
-- Motor: PostgreSQL
-- Base de datos: retail_project (tablas clientes, productos y ventas
-- del módulo anterior)
-- =====================================================================


-- =====================================================================
-- 0. PREPARACIÓN (ejecutar antes de las consultas)
-- =====================================================================
-- La consulta 1 necesita una tabla categorias. En el módulo anterior la
-- categoría era un texto dentro de productos, así que acá se crea la tabla,
-- se cargan sus valores a partir de ese texto y se vincula cada producto
-- con su categoría mediante una clave foránea (id_categoria).
-- Además se agregan datos de ejemplo (2 clientes sin compras y algunas
-- ventas extra) para que las tres consultas devuelvan resultados útiles.
-- Esta sección se puede ejecutar más de una vez sin duplicar datos.

-- 0.1 Tabla categorias
CREATE TABLE IF NOT EXISTS categorias (
    id_categoria SERIAL      PRIMARY KEY,
    nombre       VARCHAR(50) NOT NULL,
    CONSTRAINT uq_categorias_nombre UNIQUE (nombre)
);

INSERT INTO categorias (nombre)
SELECT DISTINCT categoria
FROM productos
WHERE categoria IS NOT NULL
ON CONFLICT (nombre) DO NOTHING;

-- 0.2 Vínculo productos -> categorias
ALTER TABLE productos ADD COLUMN IF NOT EXISTS id_categoria INTEGER;

ALTER TABLE productos DROP CONSTRAINT IF EXISTS fk_productos_categorias;
ALTER TABLE productos
    ADD CONSTRAINT fk_productos_categorias
    FOREIGN KEY (id_categoria) REFERENCES categorias (id_categoria);

UPDATE productos AS p
SET id_categoria = cat.id_categoria
FROM categorias AS cat
WHERE cat.nombre = p.categoria
  AND p.id_categoria IS NULL;

-- 0.3 Datos de ejemplo adicionales (dentro de una transacción)
BEGIN;

-- Dos clientes registrados que todavía no compraron (los "escurridizos").
INSERT INTO clientes (nombre, apellido, email, edad, ciudad, fecha_registro) VALUES
    ('Valentina', 'Ruiz',  'valentina.ruiz@example.com', 31, 'Salta',   '2026-10-25'),
    ('Nicolás',   'Silva', 'nicolas.silva@example.com',  27, 'Tucumán', '2026-11-05')
ON CONFLICT (email) DO NOTHING;

-- Ventas adicionales con compras repetidas, para el ranking de la consulta 3.
-- Solo se insertan si no existen ya (mismo cliente, producto y fecha).
INSERT INTO ventas (id_cliente, id_producto, cantidad, precio_unitario, fecha_venta)
SELECT nv.id_cliente, nv.id_producto, nv.cantidad, nv.precio_unitario, nv.fecha_venta
FROM (VALUES
    ((SELECT id_cliente FROM clientes WHERE email = 'lucia.fernandez@example.com'),
     (SELECT id_producto FROM productos WHERE nombre = 'Auriculares Bluetooth'),
     1, 45000.00, TIMESTAMP '2026-10-20 11:00:00'),
    ((SELECT id_cliente FROM clientes WHERE email = 'martin.gomez@example.com'),
     (SELECT id_producto FROM productos WHERE nombre = 'Mouse Inalámbrico'),
     1, 18500.00, TIMESTAMP '2026-10-28 17:10:00'),
    ((SELECT id_cliente FROM clientes WHERE email = 'camila.rodriguez@example.com'),
     (SELECT id_producto FROM productos WHERE nombre = 'Cafetera Eléctrica'),
     1, 55000.00, TIMESTAMP '2026-11-09 13:45:00'),
    ((SELECT id_cliente FROM clientes WHERE email = 'lucia.fernandez@example.com'),
     (SELECT id_producto FROM productos WHERE nombre = 'Mouse Inalámbrico'),
     1, 18500.00, TIMESTAMP '2026-11-12 15:30:00'),
    ((SELECT id_cliente FROM clientes WHERE email = 'tomas.diaz@example.com'),
     (SELECT id_producto FROM productos WHERE nombre = 'Mochila Urbana'),
     1, 32000.00, TIMESTAMP '2026-11-14 10:20:00')
) AS nv (id_cliente, id_producto, cantidad, precio_unitario, fecha_venta)
WHERE NOT EXISTS (
    SELECT 1
    FROM ventas AS x
    WHERE x.id_cliente  = nv.id_cliente
      AND x.id_producto = nv.id_producto
      AND x.fecha_venta = nv.fecha_venta
);

COMMIT;


-- =====================================================================
-- CONSULTA 1: RENTABILIDAD POR CATEGORÍA
-- =====================================================================
-- Problema de negocio: ¿qué categorías de productos generan más ingresos?
-- Sirve para decidir en qué categorías conviene invertir en stock y
-- publicidad, y cuáles tienen un rendimiento bajo.
--
-- Lógica:
--   * Se unen 3 tablas: ventas (v) -> productos (p) -> categorias (cat).
--   * SUM(v.cantidad) da las unidades vendidas por categoría.
--   * SUM(v.cantidad * v.precio_unitario) da el ingreso total. Se usa el
--     precio_unitario de la venta (el precio al momento de vender), no el
--     precio actual del producto.
--   * Umbral definido: solo se muestran categorías con ingreso total mayor
--     a $100.000. Como la condición es sobre un resultado agregado (SUM),
--     va en HAVING y no en WHERE.
SELECT cat.nombre                         AS categoria,
       SUM(v.cantidad)                    AS unidades_vendidas,
       SUM(v.cantidad * v.precio_unitario) AS ingreso_total
FROM ventas AS v
JOIN productos  AS p   ON p.id_producto   = v.id_producto
JOIN categorias AS cat ON cat.id_categoria = p.id_categoria
GROUP BY cat.id_categoria, cat.nombre
HAVING SUM(v.cantidad * v.precio_unitario) > 100000
ORDER BY ingreso_total DESC;


-- =====================================================================
-- CONSULTA 2: CLIENTES SIN COMPRAS ("CLIENTES ESCURRIDIZOS")
-- =====================================================================
-- Problema de negocio: ¿qué clientes se registraron pero nunca compraron?
-- Es la lista objetivo para una campaña de activación (por ejemplo, un
-- cupón de primera compra).
--
-- Lógica:
--   * LEFT JOIN desde clientes (c) hacia ventas (v): trae a todos los
--     clientes, incluso a los que no tienen ninguna venta asociada.
--   * Para un cliente sin compras, todas las columnas de v vienen en NULL,
--     por eso COUNT(v.id_venta) da 0 (COUNT ignora los NULL).
--   * HAVING COUNT(v.id_venta) = 0 deja solo a los clientes sin compras.
--   * COALESCE reemplaza el NULL que devuelve SUM cuando no hay filas por
--     un 0, para que el reporte muestre $0 y no un campo vacío.
--   * Forma equivalente sin GROUP BY: agregar WHERE v.id_venta IS NULL.
SELECT c.id_cliente,
       c.nombre,
       c.apellido,
       c.email,
       c.fecha_registro,
       COUNT(v.id_venta)                                  AS cantidad_compras,
       COALESCE(SUM(v.cantidad * v.precio_unitario), 0)   AS monto_total_comprado
FROM clientes AS c
LEFT JOIN ventas AS v ON v.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre, c.apellido, c.email, c.fecha_registro
HAVING COUNT(v.id_venta) = 0
ORDER BY c.fecha_registro;


-- =====================================================================
-- CONSULTA 3: TOP DE COMPRAS POR CLIENTE
-- =====================================================================
-- Problema de negocio: ¿qué producto compra más seguido cada cliente y
-- cuándo fue su última compra? Permite personalizar recomendaciones y
-- detectar clientes que hace tiempo no vuelven a comprar.
--
-- Lógica (tres pasos con CTE):
--   1) compras_por_producto: une clientes (c), ventas (v) y productos (p)
--      y cuenta cuántas veces compró cada cliente cada producto (COUNT)
--      junto con la fecha de la última vez que lo compró (MAX).
--   2) top_por_cliente: se queda con una sola fila por cliente, la del
--      producto más comprado. DISTINCT ON toma la primera fila de cada
--      cliente según el ORDER BY; ante un empate gana la compra más reciente.
--   3) Consulta final: vuelve a unir con ventas para obtener la fecha de la
--      última transacción del cliente (de cualquier producto) con MAX, y
--      ordena el ranking por cantidad de veces comprado.
-- Los clientes sin compras no aparecen acá (ver consulta 2).
WITH compras_por_producto AS (
    SELECT c.id_cliente,
           c.nombre || ' ' || c.apellido AS cliente,
           p.nombre                      AS producto,
           COUNT(*)                      AS veces_comprado,
           MAX(v.fecha_venta)            AS ultima_compra_producto
    FROM clientes AS c
    JOIN ventas    AS v ON v.id_cliente  = c.id_cliente
    JOIN productos AS p ON p.id_producto = v.id_producto
    GROUP BY c.id_cliente, c.nombre, c.apellido, p.id_producto, p.nombre
),
top_por_cliente AS (
    SELECT DISTINCT ON (cp.id_cliente)
           cp.id_cliente,
           cp.cliente,
           cp.producto,
           cp.veces_comprado
    FROM compras_por_producto AS cp
    ORDER BY cp.id_cliente, cp.veces_comprado DESC, cp.ultima_compra_producto DESC
)
SELECT t.cliente,
       t.producto                AS producto_mas_comprado,
       t.veces_comprado,
       MAX(v.fecha_venta)        AS fecha_ultima_transaccion
FROM top_por_cliente AS t
JOIN ventas AS v ON v.id_cliente = t.id_cliente
GROUP BY t.id_cliente, t.cliente, t.producto, t.veces_comprado
ORDER BY t.veces_comprado DESC, t.cliente;

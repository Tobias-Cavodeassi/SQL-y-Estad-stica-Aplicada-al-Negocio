-- =====================================================================
-- Pre-entrega: Script de análisis avanzado con Window Functions
-- Autor: Tobías Cavodeassi
-- Motor: PostgreSQL
-- Base de datos: retail_project (tablas clientes, productos y ventas
-- del proyecto retail, más la tabla categorias del módulo 4)
-- =====================================================================
-- Objetivo: generar un reporte mensual por categoría con la venta total,
-- el ranking de la categoría en el mes, el acumulado histórico y una
-- comparación contra el promedio de la propia categoría.


-- =====================================================================
-- 0. PREPARACIÓN (ejecutar antes del análisis)
-- =====================================================================
-- Deja listo el dataset: asegura que exista la tabla categorias (creada
-- en el módulo 4) y agrega ventas de julio a septiembre de 2026, para que
-- el análisis tenga 5 meses de historia y no solo 2.
-- Esta sección se puede ejecutar más de una vez sin duplicar datos.

-- 0.1 Tabla categorias y vínculo con productos (igual que en el módulo 4)
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

-- 0.2 Ventas adicionales de julio a septiembre de 2026 (en una transacción).
-- Solo se insertan si no existen ya (mismo cliente, producto y fecha).
BEGIN;

INSERT INTO ventas (id_cliente, id_producto, cantidad, precio_unitario, fecha_venta)
SELECT c.id_cliente, p.id_producto, nv.cantidad, nv.precio_unitario, nv.fecha_venta
FROM (VALUES
    -- Julio
    ('camila.rodriguez@example.com', 'Set de Sábanas',        2, 28000.00, TIMESTAMP '2026-07-10 11:20:00'),
    ('martin.gomez@example.com',     'Mochila Urbana',        3, 32000.00, TIMESTAMP '2026-07-18 15:00:00'),
    ('julian.perez@example.com',     'Mouse Inalámbrico',     1, 18500.00, TIMESTAMP '2026-07-22 09:30:00'),
    -- Agosto
    ('lucia.fernandez@example.com',  'Teclado Mecánico',      1, 62000.00, TIMESTAMP '2026-08-05 12:00:00'),
    ('sofia.acosta@example.com',     'Cafetera Eléctrica',    1, 55000.00, TIMESTAMP '2026-08-14 17:45:00'),
    ('camila.rodriguez@example.com', 'Mochila Urbana',        1, 32000.00, TIMESTAMP '2026-08-20 10:10:00'),
    ('martin.gomez@example.com',     'Auriculares Bluetooth', 1, 45000.00, TIMESTAMP '2026-08-27 16:25:00'),
    -- Septiembre
    ('julian.perez@example.com',     'Set de Sábanas',        2, 28000.00, TIMESTAMP '2026-09-03 14:00:00'),
    ('sofia.acosta@example.com',     'Mouse Inalámbrico',     2, 18500.00, TIMESTAMP '2026-09-12 11:40:00'),
    ('lucia.fernandez@example.com',  'Cafetera Eléctrica',    1, 55000.00, TIMESTAMP '2026-09-25 13:15:00')
) AS nv (email, producto, cantidad, precio_unitario, fecha_venta)
JOIN clientes  AS c ON c.email  = nv.email
JOIN productos AS p ON p.nombre = nv.producto
WHERE NOT EXISTS (
    SELECT 1
    FROM ventas AS x
    WHERE x.id_cliente  = c.id_cliente
      AND x.id_producto = p.id_producto
      AND x.fecha_venta = nv.fecha_venta
);

COMMIT;


-- =====================================================================
-- ANÁLISIS AVANZADO: VENTAS MENSUALES POR CATEGORÍA
-- =====================================================================
-- Problema de negocio: ¿cómo evoluciona cada categoría mes a mes, cuál
-- lidera en cada período y qué meses rinden por encima o por debajo de lo
-- habitual para esa categoría? Ayuda a planificar stock, promociones y
-- objetivos de venta por categoría.
--
-- Todas las métricas están al mismo nivel de detalle: mes + categoría.
-- Nota: si una categoría no vendió nada en un mes, ese mes no genera fila
-- para ella (no cuenta ni en el ranking ni en su promedio).
WITH
-- ---------------------------------------------------------------------
-- CTE 1: ventas_mensuales
-- Agrupa las ventas por mes y categoría y suma el monto vendido.
--   * DATE_TRUNC('month', ...) lleva cada fecha al primer día de su mes,
--     así todas las ventas de un mes quedan con el mismo valor de "mes".
--   * El monto de cada venta es cantidad * precio_unitario (el precio al
--     momento de vender).
--   * Une 3 tablas: ventas (v), productos (p) y categorias (cat).
-- ---------------------------------------------------------------------
ventas_mensuales AS (
    SELECT DATE_TRUNC('month', v.fecha_venta)::date AS mes,
           cat.nombre                               AS categoria,
           SUM(v.cantidad * v.precio_unitario)      AS venta_total
    FROM ventas AS v
    JOIN productos  AS p   ON p.id_producto    = v.id_producto
    JOIN categorias AS cat ON cat.id_categoria = p.id_categoria
    GROUP BY DATE_TRUNC('month', v.fecha_venta)::date, cat.nombre
),

-- ---------------------------------------------------------------------
-- CTE 2: metricas_ventana
-- Agrega dos Window Functions sobre ventas_mensuales. Las funciones de
-- ventana no colapsan filas: cada mes/categoría conserva su fila.
--   * RANK() OVER (PARTITION BY mes ORDER BY venta_total DESC):
--     reinicia el ranking en cada mes y ordena las categorías de mayor
--     a menor venta. 1 = la categoría líder del mes (si hay empate,
--     comparten posición).
--   * SUM() OVER (PARTITION BY categoria ORDER BY mes ...): acumulado
--     (running total) de cada categoría. El ORDER BY dentro del OVER es
--     lo que hace que la suma crezca mes a mes; sin él devolvería el total
--     general en todas las filas. El marco ROWS BETWEEN UNBOUNDED
--     PRECEDING AND CURRENT ROW suma desde el primer mes hasta el actual.
-- ---------------------------------------------------------------------
metricas_ventana AS (
    SELECT vm.mes,
           vm.categoria,
           vm.venta_total,
           RANK() OVER (
               PARTITION BY vm.mes
               ORDER BY vm.venta_total DESC
           ) AS ranking_mes,
           SUM(vm.venta_total) OVER (
               PARTITION BY vm.categoria
               ORDER BY vm.mes
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS acumulado_categoria
    FROM ventas_mensuales AS vm
),

-- ---------------------------------------------------------------------
-- CTE 3: promedio_categoria
-- Calcula el promedio histórico de cada categoría como el promedio de sus
-- ventas mensuales. Así se compara un mes contra un promedio mensual
-- (misma granularidad) y no contra ventas diarias o sueltas.
-- ---------------------------------------------------------------------
promedio_categoria AS (
    SELECT vm.categoria,
           AVG(vm.venta_total) AS promedio_historico
    FROM ventas_mensuales AS vm
    GROUP BY vm.categoria
)

-- ---------------------------------------------------------------------
-- CONSULTA FINAL
-- Une las métricas de ventana con el promedio de cada categoría y agrega
-- la lógica de negocio con CASE WHEN:
--   * comparativa_promedio: "Por encima" si la venta del mes es mayor o
--     igual al promedio histórico de su categoría; si no, "Por debajo".
--   * evaluacion_mes: la misma comparación, expresada como "Exitoso" o
--     "Bajo el promedio".
-- Se ordena por mes y, dentro de cada mes, por ranking.
-- ---------------------------------------------------------------------
SELECT TO_CHAR(m.mes, 'YYYY-MM')                AS mes,
       m.categoria,
       m.venta_total,
       m.ranking_mes,
       m.acumulado_categoria,
       ROUND(pc.promedio_historico, 2)          AS promedio_historico,
       CASE
           WHEN m.venta_total >= pc.promedio_historico THEN 'Por encima'
           ELSE 'Por debajo'
       END                                      AS comparativa_promedio,
       CASE
           WHEN m.venta_total >= pc.promedio_historico THEN 'Exitoso'
           ELSE 'Bajo el promedio'
       END                                      AS evaluacion_mes
FROM metricas_ventana AS m
JOIN promedio_categoria AS pc ON pc.categoria = m.categoria
ORDER BY m.mes, m.ranking_mes;

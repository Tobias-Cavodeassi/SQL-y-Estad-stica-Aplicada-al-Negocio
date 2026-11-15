-- =====================================================================
-- Proyecto Retail - Pre-entrega 2
-- Tablas principales con restricciones y datos iniciales
-- Autor: Tobías Cavodeassi
-- Motor: PostgreSQL
-- =====================================================================


-- =====================================================================
-- 1. BASE DE DATOS
-- =====================================================================
-- CREATE DATABASE no puede ejecutarse dentro de una transacción.
-- Si la base ya existe, este comando da error y se puede ignorar.
CREATE DATABASE retail_project;

-- Conexión a la nueva base (comando propio de psql).
-- En pgAdmin o DBeaver: conectarse a retail_project y ejecutar desde la sección 2.
\c retail_project


-- =====================================================================
-- 2. DDL - ESTRUCTURA DE TABLAS
-- =====================================================================
-- Se eliminan las tablas (primero ventas, que depende de las otras dos)
-- para poder ejecutar el script desde cero las veces que haga falta.
DROP TABLE IF EXISTS ventas;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS clientes;

-- ---------------------------------------------------------------------
-- clientes
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
    id_cliente     SERIAL       PRIMARY KEY,
    nombre         VARCHAR(100) NOT NULL,
    apellido       VARCHAR(100) NOT NULL,
    email          VARCHAR(150) NOT NULL,
    edad           INTEGER      NOT NULL,
    ciudad         VARCHAR(100),
    fecha_registro DATE         NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT uq_clientes_email UNIQUE (email),
    CONSTRAINT chk_clientes_edad CHECK (edad BETWEEN 18 AND 120)
);

-- ---------------------------------------------------------------------
-- productos
-- ---------------------------------------------------------------------
CREATE TABLE productos (
    id_producto SERIAL         PRIMARY KEY,
    nombre      VARCHAR(150)   NOT NULL,
    categoria   VARCHAR(50)    NOT NULL,
    precio      DECIMAL(10, 2) NOT NULL,
    stock       INTEGER        NOT NULL DEFAULT 0,
    CONSTRAINT chk_productos_precio CHECK (precio > 0),
    CONSTRAINT chk_productos_stock  CHECK (stock >= 0)
);

-- ---------------------------------------------------------------------
-- ventas (se crea al final porque referencia a clientes y productos)
-- ---------------------------------------------------------------------
CREATE TABLE ventas (
    id_venta        SERIAL         PRIMARY KEY,
    id_cliente      INTEGER        NOT NULL,
    id_producto     INTEGER        NOT NULL,
    cantidad        INTEGER        NOT NULL,
    precio_unitario DECIMAL(10, 2) NOT NULL,
    fecha_venta     TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ventas_clientes  FOREIGN KEY (id_cliente)  REFERENCES clientes (id_cliente),
    CONSTRAINT fk_ventas_productos FOREIGN KEY (id_producto) REFERENCES productos (id_producto),
    CONSTRAINT chk_ventas_cantidad        CHECK (cantidad > 0),
    CONSTRAINT chk_ventas_precio_unitario CHECK (precio_unitario > 0)
);


-- =====================================================================
-- 3. DML - CARGA INICIAL DE DATOS (dentro de una transacción explícita)
-- =====================================================================
BEGIN;

INSERT INTO clientes (nombre, apellido, email, edad, ciudad, fecha_registro) VALUES
    ('Lucía',  'Fernández', 'lucia.fernandez@example.com', 29, 'Buenos Aires', '2026-01-15'),
    ('Martín', 'Gómez',     'martin.gomez@example.com',    34, 'Córdoba',      '2026-02-03'),
    ('Camila', 'Rodríguez', 'camila.rodriguez@example.com', 41, 'Rosario',     '2026-03-20'),
    ('Julián', 'Pérez',     'julian.perez@example.com',    25, 'Mendoza',      '2026-05-11'),
    ('Sofía',  'Acosta',    'sofia.acosta@example.com',    52, 'La Plata',     '2026-07-02'),
    ('Tomás',  'Díaz',      'tomas.diaz@example.com',      38, 'Buenos Aires', '2026-09-18');

INSERT INTO productos (nombre, categoria, precio, stock) VALUES
    ('Auriculares Bluetooth', 'Electrónica', 45000.00, 50),
    ('Teclado Mecánico',      'Electrónica', 62000.00, 30),
    ('Mouse Inalámbrico',     'Electrónica', 18500.00, 80),
    ('Cafetera Eléctrica',    'Hogar',       55000.00, 25),
    ('Set de Sábanas',        'Hogar',       28000.00, 40),
    ('Mochila Urbana',        'Accesorios',  32000.00, 60);

-- id_cliente e id_producto corresponden a los SERIAL generados arriba (1 a 6).
-- precio_unitario guarda el precio al momento de la venta.
INSERT INTO ventas (id_cliente, id_producto, cantidad, precio_unitario, fecha_venta) VALUES
    (1, 1, 1, 45000.00, '2026-10-02 10:15:00'),
    (2, 3, 2, 18500.00, '2026-10-05 16:40:00'),
    (3, 4, 1, 55000.00, '2026-10-09 12:05:00'),
    (4, 2, 1, 62000.00, '2026-10-14 18:30:00'),
    (5, 5, 3, 28000.00, '2026-10-21 09:50:00'),
    (6, 6, 2, 32000.00, '2026-11-03 14:20:00'),
    (6, 3, 1, 18500.00, '2026-11-10 10:00:00');  -- venta de prueba (id_venta = 7), se elimina más abajo

COMMIT;


-- =====================================================================
-- 4. DML - MANTENIMIENTO
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4.1 UPDATE masivo: aumento del 10 % a los productos de la categoría 'Electrónica'
-- ---------------------------------------------------------------------
-- Verificación previa: filas que se van a modificar.
SELECT id_producto, nombre, categoria, precio
FROM productos
WHERE categoria = 'Electrónica';

UPDATE productos
SET precio = ROUND(precio * 1.10, 2)
WHERE categoria = 'Electrónica';

-- Verificación posterior.
SELECT id_producto, nombre, categoria, precio
FROM productos
WHERE categoria = 'Electrónica';

-- ---------------------------------------------------------------------
-- 4.2 DELETE de un registro de prueba: la venta con id_venta = 7
-- ---------------------------------------------------------------------
-- Verificación previa: fila que se va a eliminar.
SELECT id_venta, id_cliente, id_producto, cantidad, fecha_venta
FROM ventas
WHERE id_venta = 7;

DELETE FROM ventas
WHERE id_venta = 7;

-- Verificación posterior: debe devolver 0 filas.
SELECT id_venta
FROM ventas
WHERE id_venta = 7;


-- =====================================================================
-- 5. VERIFICACIÓN FINAL
-- =====================================================================
SELECT 'clientes'  AS tabla, COUNT(*) AS registros FROM clientes
UNION ALL
SELECT 'productos' AS tabla, COUNT(*) AS registros FROM productos
UNION ALL
SELECT 'ventas'    AS tabla, COUNT(*) AS registros FROM ventas;

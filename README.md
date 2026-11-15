# Proyecto Retail: tablas principales con restricciones y datos iniciales

Pre-entrega 2 de SQL. El archivo `retail_project.sql` crea la base `retail_project` en PostgreSQL, define las tablas `clientes`, `productos` y `ventas` con sus restricciones de integridad, carga datos iniciales dentro de una transacción y ejecuta un `UPDATE` y un `DELETE` de mantenimiento.

## Requisitos

- PostgreSQL 12 o superior.
- Cliente `psql`, pgAdmin o DBeaver.
- El archivo está guardado en UTF-8 (tiene tildes en los datos).

## Cómo ejecutarlo

**Opción A: con `psql` (recomendada).** Desde la carpeta del repositorio:

```bash
psql -U postgres -f retail_project.sql
```

El script crea la base `retail_project`, se conecta a ella (`\c retail_project`) y ejecuta todo lo demás.

**Opción B: con pgAdmin o DBeaver.**

1. Crear una base de datos llamada `retail_project` y abrir el editor de consultas conectado a ella.
2. Pegar el contenido de `retail_project.sql` **desde la sección 2 (DDL)** en adelante. Las líneas `CREATE DATABASE` y `\c` de la sección 1 son comandos de la base `postgres` / de `psql` y no se ejecutan desde estas herramientas.

El script se puede volver a ejecutar desde la sección 2: elimina las tablas (empezando por `ventas`) y las recrea desde cero.

## Estructura

| Tabla | Clave primaria | Restricciones |
| --- | --- | --- |
| `clientes` | `id_cliente` (SERIAL) | `email` UNIQUE y NOT NULL; `CHECK (edad BETWEEN 18 AND 120)` |
| `productos` | `id_producto` (SERIAL) | `CHECK (precio > 0)`; `CHECK (stock >= 0)`; `precio` es DECIMAL(10,2) |
| `ventas` | `id_venta` (SERIAL) | FK `id_cliente` → `clientes`; FK `id_producto` → `productos`; `CHECK (cantidad > 0)`; `CHECK (precio_unitario > 0)` |

`ventas` se crea al final porque sus claves foráneas necesitan que `clientes` y `productos` ya existan.

## Contenido del script

1. **Base de datos:** `CREATE DATABASE retail_project`.
2. **DDL:** creación de las tres tablas, con 5 restricciones `CHECK` en total.
3. **Carga inicial:** `BEGIN; ... COMMIT;` con 6 clientes, 6 productos y 7 ventas (la séptima es una venta de prueba).
4. **Mantenimiento:**
   - `UPDATE` que sube un 10 % el precio de los productos de la categoría `Electrónica` (`WHERE categoria = 'Electrónica'`).
   - `DELETE` de la venta de prueba (`WHERE id_venta = 7`).
   - Cada operación va precedida de un `SELECT` que muestra las filas afectadas y seguida de otro que confirma el resultado.
5. **Verificación final:** conteo de registros por tabla (6 clientes, 6 productos y 6 ventas).

# Pre-entrega Módulo 4: consultas multicapa para análisis de negocio

El archivo `pre-entrega-modulo4.sql` contiene 3 consultas en PostgreSQL que combinan varias tablas con `JOIN`, `GROUP BY` y `HAVING` para responder preguntas de negocio sobre el proyecto retail.

## Requisitos

- PostgreSQL con la base `retail_project` del módulo anterior (tablas `clientes`, `productos` y `ventas`, con sus datos cargados).
- pgAdmin, DBeaver o `psql`.

## Cómo ejecutarlo

1. Conectarse a la base `retail_project` y abrir el editor de consultas.
2. Ejecutar el archivo `pre-entrega-modulo4.sql`. La **sección 0 (preparación)** crea la tabla `categorias`, vincula cada producto con su categoría y agrega datos de ejemplo. Se puede ejecutar más de una vez sin duplicar datos.
3. Ejecutar cada consulta por separado (seleccionándola y presionando F5 en pgAdmin) para ver su resultado.

Con `psql`: `psql -U postgres -d retail_project -f pre-entrega-modulo4.sql`

## Consultas

| # | Consulta | Problema de negocio | Técnicas |
| --- | --- | --- | --- |
| 1 | Rentabilidad por categoría | ¿Qué categorías generan más ingresos? Solo se muestran las que superan $100.000. | 3 tablas con `JOIN`, `SUM`, `GROUP BY`, `HAVING` |
| 2 | Clientes sin compras | ¿Qué clientes se registraron pero nunca compraron? Sirve para campañas de activación. | `LEFT JOIN`, `COUNT`, `COALESCE`, `HAVING` |
| 3 | Top de compras por cliente | ¿Qué producto compra más cada cliente y cuándo fue su última compra? | 3 tablas con `JOIN`, CTE, `DISTINCT ON`, `COUNT`, `MAX`, `GROUP BY` |

Todas las consultas usan alias de tabla (`v`, `p`, `cat`, `c`) y llevan un comentario que explica la lógica aplicada.

## Resultados esperados

- **Consulta 1:** Electrónica (7 unidades, $226.000) y Hogar (5 unidades, $194.000). Accesorios queda fuera por no superar el umbral.
- **Consulta 2:** Valentina Ruiz y Nicolás Silva, con 0 compras y $0 comprado.
- **Consulta 3:** una fila por cada uno de los 6 clientes con compras, ordenadas por cantidad de veces que compraron su producto más frecuente.

# Pre-entrega: análisis avanzado con Window Functions

El archivo `preentrega_analisis_avanzado.sql` contiene una consulta en PostgreSQL que arma un reporte mensual de ventas por categoría, combinando CTEs, Window Functions y lógica condicional con `CASE WHEN`.

## Requisitos

- PostgreSQL con la base `retail_project` (tablas `clientes`, `productos` y `ventas` del proyecto retail, con sus datos cargados).
- pgAdmin, DBeaver o `psql`.

## Cómo ejecutarlo

1. Conectarse a la base `retail_project` y abrir el editor de consultas.
2. Ejecutar la **sección 0 (preparación)** del archivo. Crea la tabla `categorias` si no existe, la vincula con `productos` y agrega ventas de julio a septiembre de 2026 para tener 5 meses de historia. Se puede ejecutar más de una vez sin duplicar datos.
3. Ejecutar la consulta de análisis (desde `WITH ventas_mensuales AS (...` hasta el `ORDER BY` final) seleccionándola y presionando F5 en pgAdmin.

Con `psql`: `psql -U postgres -d retail_project -f preentrega_analisis_avanzado.sql`

## Estructura de la consulta

| CTE / bloque | Qué hace |
| --- | --- |
| `ventas_mensuales` | Une `ventas`, `productos` y `categorias`, normaliza la fecha con `DATE_TRUNC('month', ...)` y suma la venta por mes y categoría. |
| `metricas_ventana` | Calcula el ranking de categorías por mes con `RANK() OVER (PARTITION BY mes ...)` y el acumulado por categoría con `SUM() OVER (PARTITION BY categoria ORDER BY mes ...)`. |
| `promedio_categoria` | Calcula el promedio histórico de ventas mensuales de cada categoría, al mismo nivel de detalle (mes/categoría). |
| `SELECT` final | Une todo y agrega dos columnas con `CASE WHEN` que comparan la venta del mes contra el promedio de su categoría. |

## Columnas del reporte

| Columna | Descripción |
| --- | --- |
| `mes` | Mes de la venta (formato `YYYY-MM`). |
| `categoria` | Nombre de la categoría del producto. |
| `venta_total` | Venta total del mes para esa categoría. |
| `ranking_mes` | Posición de la categoría en ese mes según sus ventas (1 = líder). |
| `acumulado_categoria` | Ventas acumuladas de la categoría desde el primer mes hasta el actual. |
| `promedio_historico` | Promedio de ventas mensuales de la categoría. |
| `comparativa_promedio` | "Por encima" o "Por debajo" del promedio de su categoría. |
| `evaluacion_mes` | "Exitoso" o "Bajo el promedio" según la misma comparación. |

Un mes con venta igual al promedio cuenta como "Por encima" / "Exitoso". Si una categoría no vendió nada en un mes, ese mes no genera fila para ella.

## Ejemplo de resultado

Con los datos de ejemplo, los primeros meses del reporte son:

| mes | categoria | venta_total | ranking_mes | acumulado_categoria | comparativa_promedio |
| --- | --- | --- | --- | --- | --- |
| 2026-07 | Accesorios | 96000.00 | 1 | 96000.00 | Por encima |
| 2026-07 | Hogar | 56000.00 | 2 | 56000.00 | Por debajo |
| 2026-07 | Electrónica | 18500.00 | 3 | 18500.00 | Por debajo |
| 2026-08 | Electrónica | 107000.00 | 1 | 125500.00 | Por encima |

Los valores pueden variar si la base tiene datos distintos a los de ejemplo.

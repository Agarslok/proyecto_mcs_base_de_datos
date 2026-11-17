# Entregable 5 — Optimización y transacciones

Medimos las consultas 7 y 9 con `EXPLAIN ANALYZE`, probamos índices y dejamos el cierre de una venta como una sola transacción.

## Orden

Con la base del entregable 4 ya cargada:

1. `sql/04_optimizacion_f5.sql`
2. `sql/05_transacciones_f5.sql`

## Archivos

| Archivo | Qué es |
|---------|--------|
| `E5_optimizacion_transacciones.pdf` | Hipótesis, índices que dejamos, cierre con `COMMIT` y `ROLLBACK`, y el aislamiento que usamos: `READ COMMITTED` con `FOR UPDATE`. |
| `sql/04_optimizacion_f5.sql` | Medición y creación de índices. |
| `sql/05_transacciones_f5.sql` | Cierre de la oferta 61 y rechazo de la oferta 1. |
| `time.txt` | Tiempos de planificación y de ejecución. |
| `evidencia/` | Plan de la consulta 7 antes de los índices, plan de la 9 reescrita, `COMMIT` de la oferta 61 y rechazo de la oferta 1. |

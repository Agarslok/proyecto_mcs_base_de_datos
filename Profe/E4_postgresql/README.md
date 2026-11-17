# Entregable 4 — Implementación en PostgreSQL

Creamos la base `inmobiliaria_mcs`, cargamos datos de prueba y escribimos las diez consultas que responden las preguntas del entregable 1.

## Orden en el que corrimos los scripts

En pgAdmin, sobre una base vacía:

1. `sql/00_crear_base_f4.sql` en la base `postgres`
2. `sql/01_ddl_f4.sql` en `inmobiliaria_mcs`
3. `sql/02_carga_f4.sql`
4. `sql/03_consultas_f4.sql`

## Archivos

| Ruta | Qué es |
|------|--------|
| `E4_consultas_vs_preguntas.pdf` | Cada consulta junto a la pregunta que responde, con las capturas de pgAdmin. |
| `sql/` | Scripts del listado anterior. |
| `backup/inmobiliaria_mcs_f4.sql` | Respaldo en texto de la base ya cargada. |
| `evidencia/` | Capturas: base creada, DDL, carga, consultas 1, 6 y 9, conteos y respaldo. |

Los planes de ejecución y el cierre transaccional están en `../E5_optimizacion_transacciones/`.

# Sistema de gestión y trazabilidad comercial para una inmobiliaria (MCS)

Universidad Externado de Colombia · Bases de Datos 2026-2
Integrantes: Harold Burgos, Sofía Camelo y Juan Triana

Base de datos relacional en PostgreSQL (`inmobiliaria_mcs`, 24 tablas en BCNF) que integra
propiedades, propietarios, publicaciones, campañas, prospectos, visitas, ofertas y cierres,
con un componente documental en MongoDB (`inmobiliaria_mcs_mongo.seguimiento_eventos`) para
el historial omnicanal de seguimiento.

## Contenido de la carpeta

| Carpeta / archivo | Qué contiene |
|---|---|
| `informe/Informe_Tecnico_Final_Inmobiliaria_MCS.docx` y `.pdf` | Informe técnico final (incluye el checklist de la rúbrica en el Anexo A) |
| `CHECKLIST_RUBRICA.md` | Verificación de cada criterio de la rúbrica y cada producto exigido por la guía |
| `diagramas/` | Modelo conceptual ER/EER v2.3 y modelo relacional BD_MCS v1.3 (`.drawio`, `.json` y `.png`) |
| `sql/00_crear_base_f4.sql` | `CREATE DATABASE inmobiliaria_mcs` (se ejecuta sobre la base `postgres`) |
| `sql/01_ddl_f4.sql` | 24 tablas con PK, FK, UNIQUE, CHECK, DEFAULT, columna generada, funciones y triggers |
| `sql/02_carga_f4.sql` | Datos sintéticos (≥ 50 filas en las tablas de proceso) y ajustes de consistencia |
| `sql/03_consultas_f4.sql` | 3 vistas, función y trigger de cierre, y las 10 consultas de las preguntas de información |
| `sql/04_optimizacion_f5.sql` | EXPLAIN ANALYZE antes y después con los datos del curso |
| `sql/05_transacciones_f5.sql` | Transacción de cierre (COMMIT y ROLLBACK), función con bloqueo y controles de consistencia |
| `sql/06_optimizacion_escala_f5.sql` | Validación de la hipótesis sobre una copia ampliada (100.000 propiedades) y decisión final de índices |
| `sql/07_concurrencia_demo.py` | Escenario de concurrencia con dos sesiones reales (sin bloqueo, con bloqueo y SERIALIZABLE) |
| `mongodb/seguimiento_eventos_seed.json` | 36 eventos de seguimiento (seed v2, validado contra PostgreSQL) |
| `mongodb/01_setup_y_carga_f6.js`, `02_crud_f6.js`, `03_agregaciones_f6.js` | Carga e índices, CRUD y agregaciones en mongosh |
| `mongodb/04_mongodb_python_f6.ipynb` | Notebook ejecutado: validación contra PostgreSQL, índices con `explain()`, CRUD, agregaciones, consulta híbrida y gráfico |
| `mongodb/export/`, `mongodb/figuras/` | Exportación de la colección y gráfico de eventos por canal |
| `mongodb/historico/` | Seed original (v1) y lista de las 29 referencias y 6 fechas corregidas |
| `backup/inmobiliaria_mcs_final.backup` | Backup completo (pg_dump formato custom, PostgreSQL 18) |
| `backup/inmobiliaria_mcs_final.sql` | El mismo backup en texto plano (portable a otras versiones) |
| `evidencia_ejecucion.txt` | Salida completa de los scripts 00 a 06 sobre una base vacía (0 errores) |
| `evidencia/f5_*.txt` | Planes de ejecución (curso y escala), medianas, transacción y concurrencia |
| `evidencia/capturas/` | Capturas de pgAdmin, Compass y del notebook (ver la nota al final) |

## Cómo reproducir la solución

**Opción A · restaurar el backup** (pg_restore 18 o superior):

```
createdb -U postgres inmobiliaria_mcs
pg_restore -U postgres -d inmobiliaria_mcs backup/inmobiliaria_mcs_final.backup
```

o, en cualquier versión, `psql -U postgres -d inmobiliaria_mcs -f backup/inmobiliaria_mcs_final.sql`.

**Opción B · desde los scripts** (pgAdmin 4 o psql, desde la carpeta raíz):

1. `sql/00_crear_base_f4.sql` sobre la base `postgres`.
2. En orden, sobre `inmobiliaria_mcs`: `01_ddl_f4.sql`, `02_carga_f4.sql`, `03_consultas_f4.sql`,
   `04_optimizacion_f5.sql`, `05_transacciones_f5.sql`, `06_optimizacion_escala_f5.sql`.
3. Demostración de concurrencia: `pip install "psycopg[binary]"`, definir `PGPASSWORD` y
   ejecutar `python sql/07_concurrencia_demo.py` (trabaja sobre una copia temporal de la base).

**MongoDB:** con MongoDB en `localhost:27017`, ejecutar `mongosh --file mongodb/01_setup_y_carga_f6.js`
(o importar el seed con Compass) y luego `02_crud_f6.js` y `03_agregaciones_f6.js`. El notebook
`mongodb/04_mongodb_python_f6.ipynb` hace todo el flujo y además valida contra PostgreSQL
(`pip install pandas pymongo "psycopg[binary]" matplotlib jupyter`; Kernel > Restart & Run All).

## Nota sobre las capturas

Las capturas de `evidencia/capturas/` corresponden a la versión final de la base:

- `f4_conteos_tablas.png`: conteos finales (74 solicitudes, 19 cierres).
- `f4_consulta06_campanas.png` y `f4_consulta09_rank.png`: consultas 6 y 9 sobre la base final (Meta Ads 23, web 20, WhatsApp 12; 33 propiedades sin cierre).
- `f5_explain_7_antes.png` (y `_fin`) y `f5_explain_9_despues.png`: planes de `sql/04` con los datos del curso, en el orden del script (consulta 7 sin índices; consulta 9 con los ocho candidatos).
- `f5_transaccion_commit_61.png` y `_02.png`: COMMIT del cierre de la oferta 61 y verificación (propiedad 22 vendida, solicitud ganada).
- `f5_explain_e1_escala_antes.png` y `_despues.png`: plan de E1 sobre la copia ampliada de `sql/06` (51,7 ms con Seq Scan; 0,11 ms con los índices conservados).
- `f6_agregacion_a1_notebook.png`, `f6_agregacion_top_solicitudes.png` y su `.json`: agregaciones A1 y A2 con el seed v2, ejecutadas desde el notebook (Compass no es necesario para reproducirlas).

Las demás capturas (creación y carga de la base, DDL, consulta 1, backup de la fase 4, ROLLBACK de la oferta 1 y colección y agregación A1 en Compass) las tomó el equipo durante las fases 4 a 6 y coinciden con la versión final.

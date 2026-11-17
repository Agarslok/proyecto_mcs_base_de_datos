# Entregable 4 — Consultas, objetos de BD y backup

**Base:** `inmobiliaria_mcs` (PostgreSQL, pgAdmin 4)  
**Modelo:** BD_MCS v1.3  
**Scripts (en este orden, Query Tool sobre `inmobiliaria_mcs` salvo el 00):**

| Orden | Archivo | Qué hace |
|-------|---------|----------|
| 0 | `codigo/sql/00_crear_base_f4.sql` | `CREATE DATABASE` (correr sobre `postgres`) |
| 1 | `codigo/sql/01_ddl_f4.sql` | Tablas, PK/FK, CHECK, función, triggers |
| 2 | `codigo/sql/02_carga_f4.sql` | Datos sintéticos; ≥50 filas transaccionales |
| 3 | `codigo/sql/03_consultas_f4.sql` | Vistas, función/trigger (idempotente) y las 10 consultas |

Catálogos con pocas filas a propósito: tipos, canales, roles y ciudades son dominios cerrados. Las tablas de proceso (`personas`, `propiedades`, `publicaciones`, `solicitudes_propiedad`, `visitas`, `ofertas`) superan las 50 filas.

---

## Consulta ↔ pregunta de información

| # | Pregunta E1 | Objeto / consulta en `03_consultas_f4.sql` | Técnica |
|---|-------------|--------------------------------------------|---------|
| 1 | Propiedades disponibles, precio, ubicación y estado | `v_inventario_disponible` | JOIN de 6 tablas; `publicada = TRUE` |
| 2 | Prospectos por propiedad | Segunda `SELECT` | JOIN solicitud–persona–propiedad (R6) |
| 3 | Más oportunidades **activas** | Tercera `SELECT` | `GROUP BY` + `HAVING COUNT(*) >= 2` |
| 4 | Estado de seguimiento de cada prospecto | `v_pipeline_activo` | JOIN + filtro de estados abiertos |
| 5 | Visitas / seguimiento por oportunidad | Quinta `SELECT` | JOIN visitas (R7, R8); no copia `propiedad_id` |
| 6 | Campañas y canales con más prospectos | Sexta `SELECT` | `GROUP BY` campaña/canal; R10 deja fuera `campana_id` NULL |
| 7 | Prospectos, visitas y negociaciones por inmueble | Séptima `SELECT` | **CTE** `metricas` |
| 8 | Llegaron a negociación/cierre vs no avanzaron | Octava `SELECT` | **Subconsulta** `EXISTS` + `LEFT JOIN` |
| 9 | Más tiempo en comercialización sin cierre | Novena `SELECT` | CTE + **`RANK() OVER`** |
| 10 | Resultado económico de cerradas | `v_resultado_cierres` | JOIN transacción; `comision_valor` generado (R16) |

La última `SELECT` del script solo cuenta filas; no responde una pregunta E1.

---

## Función y trigger (reglas de dominio)

| Objeto | Regla | Efecto |
|--------|-------|--------|
| `registrar_cierre(...)` | R12 | Inserta la transacción en una sola llamada. |
| `trg_validar_y_aplicar_transaccion` | R12, R11 | Rechaza el cierre si la oferta no está `aceptada`. Marca la solicitud `ganada` y la propiedad `vendida` o `no_disponible`. |
| `trg_solicitud_no_es_dueno` | R2, R6 | El propietario no puede ser prospecto de **la misma** propiedad. |
| `trg_solicitud_motivo_descarte` | pipeline | `motivo_descarte` obligatorio si `estado = 'descartada'`. |
| `trg_oferta_aceptada_en_negociacion` | R11 | Oferta aceptada: propiedad `disponible` → `en_negociacion`. |
| `trg_*_actualizado` | auditoría | Mantiene `actualizado_en`. |

Definidos en `01_ddl_f4.sql`. `03_consultas_f4.sql` vuelve a crear la función de cierre y el trigger R12 para que el script de consultas contenga los objetos que pide la guía.

Prueba manual (no va en la carga; cambia datos):

```sql
-- Debe fallar: oferta no aceptada
SELECT registrar_cierre(1, 4, 100000000, 3.0, CURRENT_DATE);
```

---

## Backup

En pgAdmin 4: clic derecho en `inmobiliaria_mcs` → **Backup** → Format `Plain` o `Custom` → guardar en `codigo/backup/`.

Equivalente por consola (PostgreSQL 18, ajustar usuario):

```text
"C:\Program Files\PostgreSQL\18\bin\pg_dump.exe" -U postgres -d inmobiliaria_mcs -F p -f codigo/backup/inmobiliaria_mcs_f4.sql
```

El archivo de respaldo no se versiona aquí hasta ejecutarlo en la máquina donde vive pgAdmin: el dump es un producto de esa ejecución, no del diseño.

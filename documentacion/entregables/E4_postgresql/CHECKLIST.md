# Entregable 4 — Implementación PostgreSQL

## Qué pide el curso

- Script DDL completo.
- Script de carga de datos.
- Script de consultas SQL, vistas, función/procedimiento y trigger.
- Backup de la base de datos.
- Breve documento consulta ↔ pregunta de información.

## Qué ya tenemos

| Requisito | Dónde está |
|-----------|------------|
| Crear base | ✅ `codigo/sql/00_crear_base_f4.sql` |
| DDL completo | ✅ `codigo/sql/01_ddl_f4.sql` |
| Carga (≥50 filas transaccionales) | ✅ `codigo/sql/02_carga_f4.sql` |
| Consultas, vistas, función, trigger | ✅ `codigo/sql/03_consultas_f4.sql` |
| Mapa consulta ↔ pregunta | ✅ `documentacion/04_consultas_vs_preguntas_f4.md` |
| Backup | ✅ `codigo/backup/inmobiliaria_mcs_f4.sql` |
| Evidencia ejecución | ✅ `documentacion/evidencia/f4_*.png`, `Carga_03.png`, `f0_bd_creada.png` |

## Rúbrica SQL (cubierta en `03_consultas_f4.sql`)

| Técnica | Estado |
|---------|--------|
| 10 consultas | ✅ |
| JOIN múltiples | ✅ |
| GROUP BY + HAVING | ✅ |
| Subconsulta | ✅ |
| CTE | ✅ |
| Vistas | ✅ (`v_inventario_disponible`, etc.) |
| Función | ✅ `registrar_cierre` |
| Trigger | ✅ `trg_validar_y_aplicar_transaccion` (+ otros en DDL) |

## Qué falta en **esta carpeta**

| Ítem | Estado |
|------|--------|
| Copia de los scripts `00`–`03` (o enlace claro en README de entrega) | ☐ |
| Copia del backup | ☐ |
| Copia del documento `04_consultas_vs_preguntas` como PDF si aplica | ☐ |
| Subcarpeta `evidencia/` con capturas f4 | ☐ |

## Orden de ejecución (para repetir en sustentación)

`00` (sobre `postgres`) → `01` → `02` → `03` (todos sobre `inmobiliaria_mcs`).
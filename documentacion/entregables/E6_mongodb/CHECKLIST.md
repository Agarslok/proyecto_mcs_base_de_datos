# Entregable 6 — Implementación NoSQL (MongoDB)

## Qué pide el curso (`entregables.txt`)

- Exportación o script de creación/carga de la colección.
- Breve justificación del componente en NoSQL.

La guía amplía (sección 6.1): diseño de colección, **CRUD**, **índices**, **≥2 agregaciones**.

## Qué ya tenemos

| Requisito | Dónde está |
|-----------|------------|
| Justificación y diseño del documento | ✅ `documentacion/07_mongodb_nosql_f6.md` |
| Script carga + índices | ✅ `codigo/mongodb/01_setup_y_carga_f6.js` |
| CRUD demostrado | ✅ `codigo/mongodb/02_crud_f6.js` |
| 2 agregaciones (A1 canales, A2 top solicitudes) | ✅ `codigo/mongodb/03_agregaciones_f6.js` |
| Datos (36 eventos) | ✅ `codigo/mongodb/seguimiento_eventos_seed.json` |
| Evidencia Compass | ✅ `documentacion/evidencia/f6_*.png` |
| Resultados JSON agregaciones | ✅ `f6_agregacion_*_resultado.json` |

## Qué falta en **esta carpeta**

| Ítem | Estado |
|------|--------|
| Copia de `01`–`03`, seed y `07_mongodb_nosql_f6.md` | ☐ |
| Subcarpeta `evidencia/` con capturas f6 | ☐ |
| Export BSON/JSON de colección completa (opcional; el seed es la fuente canónica) | ⚠ no obligatorio si entregan script + seed |

## Coherencia con PostgreSQL

Solo referencias enteras (`solicitud_id`, `persona_id`, `propiedad_id`); no replica tablas relacionales.
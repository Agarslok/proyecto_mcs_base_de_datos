# Entregable 3 — Modelo relacional y normalización

## Qué pide el curso

- Diagrama del modelo relacional normalizado.
- Tabla de claves primarias y foráneas.
- Dependencias funcionales identificadas.
- Evidencia resumida 1FN → 2FN → 3FN → BCNF.

## Qué ya tenemos

| Requisito | Dónde está |
|-----------|------------|
| Diagrama relacional | ✅ `codigo/modelos/modelo_relacional_2.0.drawio` (BD_MCS v1.3) |
| PNG figura | ✅ `documentacion/evidencia/f3_diagrama_relacional.png` |
| PK/FK por tabla | ✅ `documentacion/03_modelo_relacional_normalizacion_f3.md` §3.2 |
| Dependencias funcionales | ✅ mismo doc, §4 |
| Proceso 1FN–BCNF + `comision_valor` | ✅ mismo doc, §5–6 |
| Implementación real (24 tablas) | ✅ `codigo/sql/01_ddl_f4.sql` |

## Qué falta en **esta carpeta**

| Ítem | Estado |
|------|--------|
| Paquete E3 (diagrama + tablas PK/FK exportadas) | ☐ |
| Tabla PK/FK en Excel si el informe final lo exige como anexo | ⚠ hoy está en Markdown |

## Verificación

Las **24 tablas** del diagrama coinciden con el DDL. No hace falta cambiar el modelo para cerrar E3; solo empaquetar.
# Carpetas de entregables — MCS Bases de datos 2026-2

Requisitos del curso: [`entregables.txt`](entregables.txt).

Cada carpeta **`E1` … `E7`** contiene **copias listas para entregar** (Markdown, SQL, JSON, PNG, PDF anexo). El trabajo maestro en el repo sigue en `documentacion/`, `codigo/` y `documentacion/evidencia/`; aquí está el paquete por fase.

| Carpeta | Estado del empaquetado |
|---------|-------------------------|
| [E1_formulacion](E1_formulacion/LEEME.md) | ✅ Documento + PDF propuesta |
| [E2_modelo_conceptual](E2_modelo_conceptual/LEEME.md) | ✅ Texto + diagrama + draw.io |
| [E3_modelo_relacional](E3_modelo_relacional/LEEME.md) | ✅ Diagrama + texto + **evidencia 1FN–BCNF (MD + JSON)** + PK/FK JSON |
| [E4_postgresql](E4_postgresql/LEEME.md) | ✅ SQL 00–03 + backup + mapa consultas + evidencia |
| [E5_optimizacion_transacciones](E5_optimizacion_transacciones/LEEME.md) | ✅ SQL 04–05 + informe f5 + time.txt + evidencia |
| [E6_mongodb](E6_mongodb/LEEME.md) | ✅ Scripts, seed, justificación, evidencia |
| [E7_informe_final](E7_informe_final/LEEME.md) | ✅ Borrador integrado; falta **PDF final** |

## E3 — normalización (cómo presentarlo)

- **Prosa para el informe:** `E3_modelo_relacional/E3_evidencia_normalizacion_resumida.md`
- **Anexo estructurado:** `E3_evidencia_normalizacion.json`, `E3_claves_pk_fk.json`, `E3_dependencias_funcionales.json`
- **Detalle completo:** `E3_modelo_relacional_normalizacion.md`

No hace falta otra herramienta: los JSON son legibles y demuestran trazabilidad; el sustento semántico está en el `.md` resumido y en el DDL de E4.
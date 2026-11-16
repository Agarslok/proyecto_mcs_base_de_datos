# Entregable 7 — Entrega técnica final

## Qué pide el curso (`entregables.txt`)

Informe técnico que **integre** todo e incluya como mínimo:

| Sección del informe | Fuente en el repo | En informe PDF |
|---------------------|-------------------|----------------|
| Contexto, problema, propósito, alcance | E1 `01_formulacion_problema.md` | ☐ armar |
| Requerimientos y reglas de negocio | E1 + E2 | ☐ |
| Modelo conceptual ER/EER | E2 figura + `02_modelo_conceptual.md` | ☐ figura f2 |
| Modelo relacional y normalización | E3 figura + `03_..._f3.md` | ☐ figura f3 |
| Diccionario de datos | `02_modelo_conceptual.md` §5 o extraer tabla | ☐ |
| Implementación PostgreSQL y restricciones | E4 DDL + texto E3 | ☐ |
| Consultas SQL y resultados relevantes | E4 + capturas f4 | ☐ |
| Optimización y planes EXPLAIN | E5 + `time.txt` + f5 | ☐ |
| Transacciones y concurrencia | E5 + texto en `05_..._f5.md` | ☐ |
| Componente MongoDB | E6 + f6 | ☐ |
| Conclusiones, limitaciones | `06_informe_final_base_f6.md` §10 | ☐ |
| Declaración uso de IA | `06_informe_final_base_f6.md` §11 | ☐ |

Repositorio debe incluir: scripts SQL, carga, backup, MongoDB, informe final.

## Qué ya tenemos (repo GitHub)

| Ítem | Estado |
|------|--------|
| Scripts SQL, backup, MongoDB | ✅ en `codigo/` |
| Documentación por fase | ✅ `documentacion/*.md` |
| Guía equipo | ✅ `08_guia_para_el_equipo.md` |
| Borrador maestro informe | ✅ `06_informe_final_base_f6.md` |
| Evidencias visuales | ✅ `documentacion/evidencia/` |
| Repo publicado | ✅ GitHub `proyecto_mcs_base_de_datos` |

## Qué falta en **esta carpeta** (E7)

| Ítem | Estado |
|------|--------|
| **`Informe_tecnico_MCS.pdf`** (o Word) integrado | ☐ **principal pendiente** |
| Índice, numeración de figuras, pies de foto | ☐ |
| Anexos (diccionario Excel, si lo piden) | ⚠ opcional |
| Empaquetado “entrega zip” con carpeta `entregables/E1`…`E6` llena | ☐ al final |

## Orden sugerido para cerrar E7

1. Completar copias en `E1`–`E6`.
2. Pegar secciones de `06_informe_final_base_f6.md` en Word.
3. Insertar figuras desde `evidencia/`.
4. Exportar PDF aquí: `E7_informe_final/Informe_tecnico_MCS.pdf`.
# Leer primero — entrega Proyecto MCS (Bases de datos 2026-2)

**Docente:** Martha Quevedo  
**Equipo:** Harold Burgos, Sofía Camelo, Juan Triana  
**Proyecto:** Sistema de gestión y trazabilidad comercial para una inmobiliaria (MCS)  
**Motor relacional:** PostgreSQL, base `inmobiliaria_mcs`  
**Motor documental:** MongoDB, base `inmobiliaria_mcs_mongo`, colección `seguimiento_eventos`

---

## Cómo está organizado el paquete

| Ubicación | Para quién | Qué contiene |
|---------|------------|--------------|
| **Esta carpeta** (`documentacion/entregables/` en GitHub) **o la carpeta hermana `Profe/`** en un ZIP local | Evaluación | Entregables E1–E7: PDF, SQL, MongoDB, evidencia e informe final. **Empiece aquí.** |
| **Resto del repositorio** (`codigo/`, `documentacion/md/`, guías de sustentación) | Trabajo del equipo | Borradores y scripts maestros; no es obligatorio para calificar. |

`Link Repositorio.txt` y `Grupo.txt` están en esta misma carpeta de entregables.

**Grupo de tres:** constancia en `Grupo.txt` (autorización docente).

---

## Qué abrir primero

1. Este archivo (`LEER_PARA_LA_PROFE.md`).
2. **`E7_informe_final/Informe_tecnico_MCS.pdf`**.
3. Carpetas E1–E6 según la rúbrica; en cada una hay un `README.md`.

Ver tablas detalladas y orden de ejecución SQL/Mongo en la copia canónica junto al ZIP: `Profe/LEER_PARA_LA_PROFE.md` (mismo contenido extendido).

---

## Entregables por fase

| Carpeta | Producto principal |
|---------|-------------------|
| **E1_formulacion** | `E1_formulacion_MCS.pdf` |
| **E2_modelo_conceptual** | `E2_modelo_conceptual.pdf` + diagrama |
| **E3_modelo_relacional** | PDFs de modelo y normalización + JSON |
| **E4_postgresql** | `E4_consultas_vs_preguntas.pdf`, `sql/`, backup, evidencia |
| **E5_optimizacion_transacciones** | PDF, `sql/04`–`05`, `time.txt`, evidencia |
| **E6_mongodb** | PDF, `scripts/`, evidencia |
| **E7_informe_final** | `Informe_tecnico_MCS.pdf` |

**PostgreSQL:** `E4/sql` 00→03; luego `E5/sql` 04→05. **MongoDB:** scripts en `E6_mongodb/scripts/` en orden 01, 02, 03.

---

*En disco local del equipo: `proyecto/Profe/` = copia para entregar; `proyecto/Equipo/` = repositorio de trabajo.*
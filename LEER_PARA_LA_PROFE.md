# Leer primero — entrega Proyecto MCS (Bases de datos 2026-2)

**Docente:** Martha Quevedo  
**Equipo:** Harold Burgos, Sofía Camelo, Juan Triana  
**Proyecto:** Sistema de gestión y trazabilidad comercial para una inmobiliaria (MCS)  
**Motor relacional:** PostgreSQL, base `inmobiliaria_mcs`  
**Motor documental:** MongoDB, base `inmobiliaria_mcs_mongo`, colección `seguimiento_eventos`

---

## Cómo está organizado el paquete

En la raíz del proyecto hay **dos carpetas** con distinto propósito:

| Carpeta | Para quién | Qué contiene |
|---------|------------|--------------|
| **`Profe/`** | Evaluación y revisión | Entregables E1 a E7 listos: PDF, SQL, scripts MongoDB, capturas, diagramas y el **informe técnico final**. **Empiece aquí.** |
| **`Equipo/`** | Trabajo interno del grupo | Repositorio de desarrollo: `codigo/` (scripts maestros), borradores en `documentacion/md/`, guías de sustentación, presentación y copias intermedias. No es obligatorio abrirla para calificar; sirve para reproducir y profundizar. |

Si recibe un **ZIP**, conviene que la carpeta principal sea **`Profe`** (o que el ZIP incluya `Profe/` en la raíz junto con una copia de `Link Repositorio.txt`).

Repositorio público (mismo contenido de entregables): ver `Profe/Link Repositorio.txt`.

**Grupo de tres:** el enunciado indica máximo dos integrantes. La docente autorizó este grupo de tres; constancia en `Profe/Grupo.txt`.

---

## Qué abrir primero (ruta rápida)

1. **Este archivo** (`LEER_PARA_LA_PROFE.md`).
2. **`E7_informe_final/Informe_tecnico_MCS.pdf`** — informe técnico final que integra todas las fases (contexto, modelos, implementación, consultas, optimización, transacciones, MongoDB, conclusiones y declaración de uso de IA).
3. Las carpetas **E1** … **E6** según la rúbrica o si desea contrastar un entregable puntual con el informe.
4. En cada carpeta **E1–E6** hay un **`README.md`** breve: qué pide el curso y qué archivo es cada cosa.

---

## Entregables por fase (carpeta `Profe/`)

| Carpeta | Producto principal | Otros archivos relevantes |
|---------|-------------------|-------------------------|
| **E1_formulacion** | `E1_formulacion_MCS.pdf` (2 páginas) | `BD_propuesta.pdf` (anexo opcional) |
| **E2_modelo_conceptual** | `E2_modelo_conceptual.pdf` | `f2_diagrama_conceptual.png`, `modelo_conceptual_2.1.drawio` |
| **E3_modelo_relacional** | `E3_modelo_relacional_normalizacion.pdf`, `E3_evidencia_normalizacion.pdf` | `f3_diagrama_relacional.png`, JSON de claves, dependencias y normalización, `modelo_relacional_2.0.drawio` |
| **E4_postgresql** | `E4_consultas_vs_preguntas.pdf` | `sql/00`–`03`, `backup/inmobiliaria_mcs_f4.sql`, carpeta `evidencia/` |
| **E5_optimizacion_transacciones** | `E5_optimizacion_transacciones.pdf` | `sql/04`–`05`, `time.txt`, capturas EXPLAIN y transacciones |
| **E6_mongodb** | `E6_mongodb_nosql.pdf` | `scripts/` (carga, CRUD, agregaciones, seed JSON), carpeta `evidencia/` |
| **E7_informe_final** | `Informe_tecnico_MCS.pdf` | `README.md` (referencia a figuras en E2–E6) |

### Orden de ejecución SQL (reproducibilidad)

**PostgreSQL (E4):** en pgAdmin, base vacía → `E4_postgresql/sql/00_crear_base_f4.sql` (en `postgres`) → `01_ddl` → `02_carga` → `03_consultas` sobre `inmobiliaria_mcs`.

**Optimización y transacciones (E5):** con la base ya cargada → `E5_optimizacion_transacciones/sql/04_optimizacion_f5.sql` y luego `05_transacciones_f5.sql`.

**MongoDB (E6):** crear la base `inmobiliaria_mcs_mongo` y ejecutar los scripts en `E6_mongodb/scripts/` (01 carga e índices, 02 CRUD, 03 agregaciones).

---

## Qué NO hace falta revisar para la nota

Dentro de **`Equipo/`** pueden aparecer:

- Varias copias de los mismos SQL en `codigo/` y en `documentacion/entregables/` (son equivalentes a los de `Profe/`).
- Archivos `.md` de borrador en `documentacion/md/`.
- `GUIA_SUSTENTACION.md`, `PRESENTACION.md` y la carpeta `documentacion/presentacion/` (apoyo para la sustentación oral, no sustituyen el informe).
- Capturas viejas en `Equipo/documentacion/evidencia/` (por ejemplo pruebas de la oferta 16); **las que valen para la entrega están en `Profe/E4_.../evidencia` y `Profe/E5_.../evidencia`.**

---

## Cumplimiento del enunciado (resumen)

| Requisito del curso | Dónde lo ve la docente |
|--------------------|-------------------------|
| Formulación, reglas, preguntas | E1 PDF + informe §2–3 |
| Modelo ER/EER y justificación | E2 PDF + figuras en informe |
| Modelo relacional, normalización | E3 PDF + JSON + informe §5–6 |
| DDL, carga (≥50 filas), consultas, vistas, función, trigger, backup | E4 `sql/`, backup, PDF y evidencia |
| EXPLAIN, hipótesis, transacción, aislamiento | E5 PDF, `time.txt`, sql 04–05, evidencia |
| MongoDB: carga, CRUD, índices, 2 agregaciones | E6 PDF, `scripts/`, evidencia |
| Informe técnico final integrado | `E7_informe_final/Informe_tecnico_MCS.pdf` |

La evidencia de optimización y las transacciones descritas en el informe corresponde a la **carga del curso** (`time.txt`, scripts 04–05 y capturas en E5), no a experimentos con archivos que no forman parte de este paquete.

---

## Contacto del equipo

Integrantes: Harold Burgos, Sofía Camelo, Juan Triana.  
Para sustentación: cada integrante debe poder explicar reglas de negocio, SQL, planes de ejecución, el cierre transaccional (oferta 61 / rechazo oferta 1) y el porqué del componente MongoDB.

---

*Última organización del paquete: carpeta `Profe/` = entrega; carpeta `Equipo/` = trabajo del grupo.*
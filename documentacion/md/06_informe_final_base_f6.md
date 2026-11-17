# Base para el informe técnico final — Proyecto MCS Inmobiliaria

**Uso:** Este archivo es el **borrador maestro** del Entregable 7. Copiar secciones al Word/PDF final, insertar figuras desde `documentacion/evidencia/` y actualizar el estado conforme avancen las fases.

**Equipo:** Harold Burgos, Sofía Camelo, Juan Triana  
**Base relacional:** `inmobiliaria_mcs` (PostgreSQL 18, pgAdmin 4)  
**Modelos:** conceptual v2.3 · relacional BD_MCS v1.3  
**Periodo:** 2026-2 — Bases de datos, Universidad Externado

---

## Índice sugerido del informe (PDF/Word)

1. Introducción y equipo  
2. Formulación del problema (E1)  
3. Modelo conceptual ER/EER (E2)  
4. Modelo relacional y normalización (E3)  
5. Implementación PostgreSQL (E4)  
6. Consultas SQL y programación en BD (E4)  
7. Optimización y planes de ejecución (E5)  
8. Transacciones, ACID y concurrencia (E5)  
9. Componente MongoDB (E6)  
10. Conclusiones, limitaciones y trabajo futuro  
11. Declaración de uso de inteligencia artificial (si aplica)  
12. Anexos (diagramas, diccionario, scripts, backup, `time.txt`)

---

## Tabla por fase — qué hay en el repo y qué llevar al informe

| Fase | Ya en repo | Qué agregar al informe (además del `.md`) | Estado evidencia |
|------|------------|-------------------------------------------|------------------|
| **0** | `00_alcance_y_convenciones.md` | Nombre BD `inmobiliaria_mcs`, integrantes, motor pgAdmin. Grupo de 3 autorizado por la profesora. | ✅ `f0_bd_creada.png` |
| **1** | `01_formulacion_problema.md` | Narrativa: contexto, problema, propósito, alcance; reglas R1–R16; 10 preguntas. Opcional: `BD_propuesta.pdf`. | ✅ Texto |
| **2** | `02_modelo_conceptual.md` + `modelo_conceptual_2.1.drawio` | Figura ER/EER; cardinalidades; R6: la solicitud es prospecto + propiedad, el dueño va en `propiedad_propietarios`. | ✅ `f2_diagrama_conceptual.png` |
| **3** | `03_modelo_relacional_normalizacion_f3.md` + `modelo_relacional_2.0.drawio` | Figura relacional v1.3 (24 tablas); PK/FK; 1FN→BCNF; `comision_valor` generada. | ✅ `f3_diagrama_relacional.png` |
| **4** | `00–03` SQL + `04_consultas_vs_preguntas_f4.md` | Orden de ejecución; consultas 1, 6 y 9; conteos ≥50; backup `codigo/backup/inmobiliaria_mcs_f4.sql`. | ✅ `f4_*` y `Carga_03.png` |
| **5** | `05_optimizacion_transacciones_f5.md` + `results/time.txt` + SQL `04–05` | EXPLAIN consulta 7 (antes) y 9 reescrita (después); COMMIT oferta 61; ROLLBACK oferta 1. Las capturas de la oferta 16 quedaron viejas. | ✅ `f5_*` + `time.txt` |
| **6** | `07_mongodb_nosql_f6.md` + `codigo/mongodb/*.js` + `seguimiento_eventos_seed.json` | Justificación; **36** eventos; 2 índices; CRUD `02`; agregaciones A1/A2. | ✅ `f6_mongo_compass_coleccion.png`, `f6_agregacion_canales.png`, `f6_agregacion_top_solicitudes.png` |

---

## Capturas de pantalla — guía detallada

Instrucciones completas en [`evidencia/README.md`](evidencia/README.md). Resumen por obligación de la rúbrica:

### PostgreSQL (pgAdmin)

| # | Momento | Qué encuadrar en la captura |
|---|---------|----------------------------|
| 1 | Tras Fase 0–4 | Base `inmobiliaria_mcs` visible en el árbol de bases. |
| 2 | Tras `01_ddl_f4.sql` | Pestaña Messages: `COMMIT` sin `ERROR`. |
| 3 | Tras `03_consultas_f4.sql` | Grid del `UNION ALL` de conteos (personas ≥55, solicitudes 65, etc.). |
| 4 | Consultas representativas | Al menos **pregunta 1**, **6** y **9** (JOIN/agregación/ventana). |
| 5 | Backup E4 | Propiedades del archivo `inmobiliaria_mcs_f4.sql` o ventana Backup completada. |
| 6 | Fase 5 optimización | Fragmento de `EXPLAIN ANALYZE` con **Planning Time** y **Execution Time** (consulta 7 u 9). |
| 7 | Fase 5 transacciones | Bloque 2: `nueva_transaccion_id` + filas propiedad/solicitud tras COMMIT (oferta 61, propiedad 22). |
| 8 | Fase 5 transacciones | Bloque 3: los dos `NOTICE` (R12 + atomicidad oferta 1). |

### MongoDB (Compass o mongosh)

| # | Momento | Qué encuadrar |
|---|---------|----------------|
| 9 | Tras carga f6 | Lista de documentos en `seguimiento_eventos` (campos `solicitud_id`, `canal`, `contenido`). |
| 10 | Agregaciones f6 | Salida pipeline “eventos por canal” y “solicitudes con más interacciones”. |

**En el informe:** debajo de cada figura, pie de foto del tipo: *Figura 3. Inventario disponible (pregunta E1-1), base inmobiliaria_mcs.*

---

## Evidencia ya recopilada (copiar al anexo sin rehacer)

### Optimización (`results/time.txt`)

| Consulta | Ejecución | Nota |
|----------|-----------|------|
| 7 antes | 0.298 ms | Seq Scan dominante |
| 7 después índices | 0.428 ms | Sin mejora con N pequeño |
| 9 antes | 0.352 ms | NOT IN |
| 9 después índices | 0.264 ms | décimas de ms; ruido a este volumen |
| 9 reescrita NOT EXISTS | 0.422 ms | Hash Anti Join; mejor planificación |

Texto listo para informe: ver §1 de `05_optimizacion_transacciones_f5.md`.

### Transacciones (ejecutadas por el equipo)

**Bloque 2 — COMMIT correcto (oferta 61, solicitud 64, propiedad 22):**

- `registrar_cierre(16, …)` con `valor_final` distinto de `valor_ofertado` es válido.
- Antes del cierre, el listado de “aceptadas sin transacción” podía mostrar `estado_comercial = vendida` si **otra** oferta de la misma propiedad ya cerró (múltiples ofertas aceptadas en datos demo).

**Bloque 3 — ROLLBACK / atomicidad:**

```text
NOTICE: ROLLBACK implícito OK: R12: la transacción exige oferta aceptada (oferta_id=1, estado=pendiente)
NOTICE: Atomicidad: no quedó fila en transacciones para oferta 1
```

### Backup

- Archivo presente: `codigo/backup/inmobiliaria_mcs_f4.sql` (mencionar en § implementación).

---

## Texto base por sección (ensamblar informe)

### §1 Introducción (párrafo tipo)

Sistema de gestión y trazabilidad comercial para una inmobiliaria (MCS): propiedades, prospectos, campañas, visitas, ofertas y cierres. Solución **relacional** en PostgreSQL; fragmento **documental** en MongoDB para seguimiento omnicanal semiestructurado. Trazabilidad reglas E1 → modelo → SQL → consultas.

### §2 Formulación

**Fuente:** `01_formulacion_problema.md`.  
Incluir tablas de reglas y preguntas. **No omitir** corrección R6 (prospecto ≠ propietario en solicitudes).

### §3 Modelo conceptual

**Fuente:** `02_modelo_conceptual.md` + figura PNG.  
Diez entidades de proceso + catálogos; N:M en puentes; especialización construcción/terreno.

### §4 Relacional y normalización

**Fuente:** `03_modelo_relacional_normalizacion_f3.md` + figura PNG.  
24 tablas, BCNF, contrato DDL (IDENTITY, `comision_valor` GENERATED).

### §5–6 Implementación y consultas

**Fuente:** `04_consultas_vs_preguntas_f4.md`.  
Tabla 10 consultas ↔ preguntas; vistas `v_inventario_disponible`, `v_pipeline_activo`, `v_resultado_cierres`; función `registrar_cierre`; triggers R6/R11/R12.

**Reproducibilidad (párrafo):** ejecutar en orden `00` → `01` → `02` → `03` sobre pgAdmin; restaurar desde backup si es necesario.

### §7–8 Optimización y transacciones

**Fuente:** `05_optimizacion_transacciones_f5.md` + anexo `results/time.txt`.  
Hipótesis, índices `idx_*`, conclusión honesta sobre volumen académico vs producción. ACID y `cerrar_venta_con_bloqueo`.

### §9 MongoDB

**Fuente:** `07_mongodb_nosql_f6.md`.  

- Colección `seguimiento_eventos` en `inmobiliaria_mcs_mongo`.  
- **36 documentos** en seed (canales whatsapp, llamada, email, nota_interna, feria).  
- Complementa preguntas E1 **4, 5 y 6** (seguimiento omnicanal y canales).  
- No duplica tablas PostgreSQL; solo IDs enteros de referencia.

**Párrafo tipo para el informe:**  
*El modelo relacional conserva visitas estructuradas; MongoDB almacena el histórico de touchpoints con esquema flexible en `contenido` y `metadata`, coherente con la limitación declarada en E2 (WhatsApp/llamadas fuera del núcleo relacional).*

### §10 Conclusiones sugeridas

- Trazabilidad comercial integrada E1–E6.  
- Diseño normalizado con reglas en triggers.  
- Limitaciones: un teléfono por persona; varias ofertas aceptadas por propiedad en datos sintéticos; empleados fuera de `personas`.  
- Futuro: integración APIs (Meta, WhatsApp), réplicas, más volumen para validar índices.

### §11 Declaración IA (plantilla)

> En la elaboración de modelos, scripts SQL, documentación y revisión de normalización se utilizó asistencia de IA generativa (Cursor). El equipo validó reglas de negocio, ejecutó scripts en pgAdmin y asume la sustentación individual del dominio.

*(Ajustar si la profesora exige otro formato.)*

---

## Anexos checklist

- [x] Diagrama conceptual PNG (`evidencia/f2_diagrama_conceptual.png`)  
- [x] Diagrama relacional PNG (`evidencia/f3_diagrama_relacional.png`)  
- [x] Diccionario de datos (sección 5 de `02_modelo_conceptual.md`)  
- [x] `results/time.txt`  
- [x] Scripts en `codigo/sql/` y `codigo/mongodb/`  
- [x] Backup `inmobiliaria_mcs_f4.sql`  
- [x] Capturas MongoDB en `documentacion/evidencia/f6_*.png`  
- [ ] Volver a capturar el COMMIT de la oferta 61. `f5_transaccion_commit_16.png` y `_02.png` muestran un segundo cierre de la propiedad 3 y no van en el informe. Recortar el panel izquierdo de pgAdmin en las que muestren otras bases.  
- [ ] Informe técnico en Word o PDF (ensamblar desde este archivo)  

---

## Trazabilidad rápida (tabla para anexo)

| Regla | Implementación |
|-------|----------------|
| R2 | `propiedad_propietarios` |
| R6 | `solicitudes_propiedad(persona_id, propiedad_id)` + trigger `trg_solicitud_no_es_dueno` |
| R10 | `campana_id` NULL |
| R11 | `estado_comercial` + trigger oferta aceptada |
| R12 | `transacciones` + `registrar_cierre` + trigger validación |
| R16 | `comision_valor` GENERATED |

| Pregunta E1 | Consulta (03) / vista |
|-------------|------------------------|
| 1 | `v_inventario_disponible` |
| 5 | JOIN `visitas` |
| 6 | GROUP BY campaña |
| 9 | CTE + `RANK()` (versión D en 04 para producción) |
| 10 | `v_resultado_cierres` |

---

## Fase 6 — MongoDB (actualizar tras ejecutar scripts)

| Ítem | Ubicación | Estado |
|------|-----------|--------|
| Justificación NoSQL | `07_mongodb_nosql_f6.md` | ✅ Documentado |
| Carga / índices | `codigo/mongodb/01_setup_y_carga_f6.js` | ✅ En repo |
| CRUD | `codigo/mongodb/02_crud_f6.js` | ✅ En repo |
| Agregaciones (×2) | `codigo/mongodb/03_agregaciones_f6.js` | ✅ En repo |
| Export JSON opcional | `codigo/mongodb/seguimiento_eventos_seed.json` | ✅ En repo |
| Capturas informe | `evidencia/f6_*.png` | ✅ Colección (36 docs), A1 canales, A2 top solicitudes |
| Resultados JSON | `evidencia/f6_agregacion_*_resultado.json` | ✅ Coinciden con el seed (A1: 14/7/7/6/2) |

**Ejecutar (mongosh o Compass):** ver instrucciones al inicio de `07_mongodb_nosql_f6.md`.

*Última actualización: diagramas PNG, capturas de pgAdmin y evidencia MongoDB revisados contra el DDL y el seed. Pendiente: informe técnico en Word o PDF.*
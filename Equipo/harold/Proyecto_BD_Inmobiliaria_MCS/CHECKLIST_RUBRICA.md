# Checklist de la rúbrica · Proyecto MCS Inmobiliaria

Verificado contra la guía «Proyecto Final Bases de Datos 2026-2» y contra la ejecución real de
los scripts (PostgreSQL 18.6 y MongoDB 8.0). ✅ = cumple con evidencia · ⚠️ = acción pendiente del equipo.

## 1. Rúbrica de la entrega técnica

| Criterio (peso) | Qué se evalúa | Evidencia en la entrega | Estado |
|---|---|---|---|
| Formulación del problema (8 %) | Claridad, pertinencia, alcance, reglas, preguntas | Informe §2–§3: contexto, problema, propósito, alcance y fuera de alcance; 12 reglas + 4 de apoyo; 10 preguntas | ✅ |
| Modelo conceptual ER/EER (12 %) | Coherencia, entidades, relaciones, cardinalidades, justificación | Informe §5, Figura 1; 10 entidades de proceso + 9 catálogos; tablas de construcciones EER y de cardinalidad/participación; `diagramas/modelo_conceptual_2.1.drawio` | ✅ |
| Modelo relacional y normalización (18 %) | Transformación, PK/FK, DF, 1FN–BCNF, integridad | Informe §6, Figura 2; reglas de transformación; PK/CC/FK de las 24 tablas; DF por grupo; tabla 1FN→BCNF sin descomposiciones innecesarias; acciones referenciales y dominios | ✅ |
| Implementación PostgreSQL (12 %) | DDL, restricciones, calidad de datos, carga reproducible | `sql/01–02`; 24 PK, 30 FK, 18 UNIQUE, 30 CHECK, columna GENERATED; tablas de proceso ≥ 50 filas; `evidencia_ejecucion.txt` con 0 errores desde base vacía; backup restaurado y verificado | ✅ |
| SQL y programación en BD (20 %) | Correctitud, variedad, nivel analítico, vistas, CTE/subconsultas, ventanas, objetos programables | `sql/03`: 10 consultas; JOIN de hasta 6 tablas; GROUP BY + HAVING (P3, P6); subconsultas EXISTS (P8); CTE (P7, P9); RANK() OVER (P9); 3 vistas; 7 funciones; 7 triggers | ✅ |
| Optimización y transacciones (12 %) | EXPLAIN/ANALYZE, evidencia de mejora, índices justificados, ACID, concurrencia | `sql/04` (escala del curso) y `sql/06` (100.000 propiedades): E1 51 ms → 0,07 ms; reescritura de P7 −46 %; 3 índices conservados y 5 eliminados con razón; transacción COMMIT/ROLLBACK; doble venta demostrada y evitada (`sql/07`); nivel de aislamiento justificado | ✅ |
| MongoDB (10 %) | Pertinencia del modelo documental | Historial omnicanal semiestructurado; incrustar vs referenciar justificado; 2 índices con explain (COLLSCAN 36 docs → IXSCAN 3); CRUD; 2 agregaciones + consulta híbrida con PostgreSQL; seed validado (29 + 6 inconsistencias corregidas) | ✅ |
| Documentación, trazabilidad y reproducibilidad (8 %) | Informe, diccionario, scripts, organización | Informe APA con tabla de contenido, 25 tablas y 6 figuras numeradas y citadas (diagramas en horizontal y fondo claro; plan de E1, COMMIT de la oferta 61 y agregación A1); diccionario de 130 columnas generado del catálogo; §4 de evolución del diseño; `README.md`; scripts numerados | ✅ |

## 2. Productos exigidos por etapa

| Entregable | Producto | Dónde | Estado |
|---|---|---|---|
| E1 | Título, contexto, problema, propósito, alcance | Informe §2 | ✅ |
| E1 | 8–12 reglas de negocio | Informe §3.1 (R1–R12 + R13–R16) | ✅ |
| E1 | 6–10 preguntas de información | Informe §3.2 (P1–P10) | ✅ |
| E2 | Diagrama ER/EER completo | Figura 1 · `diagramas/modelo_conceptual_2.1.*` | ✅ |
| E2 | Reglas actualizadas, diccionario preliminar, justificación de cardinalidades y EER | Informe §3.1, §5.3, §5.4, §7 | ✅ |
| E3 | Diagrama relacional normalizado | Figura 2 · `diagramas/modelo_relacional_2.0.*` | ✅ |
| E3 | Tabla de PK y FK · DF · evidencia 1FN→BCNF | Informe §6.3, §6.4, §6.5 | ✅ |
| E4 | Script DDL · script de carga | `sql/01_ddl_f4.sql` · `sql/02_carga_f4.sql` | ✅ |
| E4 | Consultas, vistas, función y trigger | `sql/03_consultas_f4.sql` | ✅ |
| E4 | Backup | `backup/inmobiliaria_mcs_final.backup` y `.sql` | ✅ |
| E4 | Documento consulta ↔ pregunta | Informe §9.1 (Tabla 15) | ✅ |
| E5 | Planes antes y después | `evidencia/f5_planes_escala_curso_time.txt`, `evidencia/f5_optimizacion_escala.txt` | ✅ |
| E5 | Hipótesis, cambio aplicado y conclusión | Informe §10.1–§10.3 | ✅ |
| E5 | Script o evidencia de la transacción | `sql/05_transacciones_f5.sql` · `evidencia/f5_transacciones_salida.txt` | ✅ |
| E5 | Escenario de concurrencia y nivel de aislamiento | Informe §10.5 · `sql/07_concurrencia_demo.py` · `evidencia/f5_concurrencia_salida.txt` | ✅ |
| E6 | Script de creación/carga o exportación de la colección | `mongodb/01_setup_y_carga_f6.js`, seed, notebook, `mongodb/export/` | ✅ |
| E6 | Justificación de por qué va en NoSQL | Informe §11.1–§11.2 | ✅ |
| E7 | Informe con todos los apartados mínimos | Informe §2–§13 | ✅ |
| E7 | Carpeta con scripts, datos/carga, backup, MongoDB e informe | Esta carpeta | ✅ |

## 3. Pendientes del equipo antes de entregar

- ✅ Nombre de la docente en la portada (Martha Quevedo).
- ✅ Declaración de uso de IA (§13) con el texto final del equipo; Anexo A en «Cumple».
- ✅ Figuras 1 y 2 en horizontal, fondo claro y en dos partes cada una; diccionario con UNIQUE del par en las tablas puente.
- ✅ Capturas actualizadas con la versión final: COMMIT de la oferta 61 y su verificación, conteos finales (74 solicitudes, 19 cierres), consultas 6 y 9, planes de `sql/04` y de E1 a escala, agregaciones A1 y A2 con el seed v2.
- ⚠️ Instalar MongoDB (o usar Compass) en el equipo con el que se hará la sustentación.

## 4. Preparación para la sustentación (10 minutos por grupo)

| Pueden pedir | Qué mostrar |
|---|---|
| Explicar una regla y dónde quedó | R6: `solicitudes_propiedad(persona_id, propiedad_id)` + `trg_solicitud_no_es_dueno` |
| Justificar una cardinalidad, clave o normalización | ofertas–transacciones 1:0..1 (`UNIQUE oferta_id`); `comision_valor` GENERATED |
| Modificar en vivo una consulta | P6 filtrando por canal; P3 cambiando el umbral del HAVING |
| Interpretar un plan y la pertinencia de un índice | E1 de `sql/06`: Seq Scan de 125.000 filas → Bitmap Index Scan (Figura 3 y `evidencia/capturas/f5_explain_e1_escala_*.png`) |
| Justificar la transacción o el aislamiento | Escenarios A/B/C de `sql/07` (doble venta vs bloqueo vs 40001) |
| Por qué una parte va en MongoDB | Campos distintos por canal; consulta híbrida visitas + eventos |

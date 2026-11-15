# Entregable 5 — Optimización y transacciones

**Base:** `inmobiliaria_mcs`  
**Scripts:** `codigo/sql/04_optimizacion_f5.sql`, `codigo/sql/05_transacciones_f5.sql`  
**Consultas base:** preguntas 7 y 9 de `03_consultas_f4.sql`

---

## 1. Qué debes ejecutar en pgAdmin

| Paso | Archivo | Nota |
|------|---------|------|
| 1 | `04_optimizacion_f5.sql` | Ejecutar **por bloques**: primero A1 y A2 (EXPLAIN), luego el bloque B (índices), luego C1, C2 y D |
| 2 | `05_transacciones_f5.sql` | Bloques 1–4 y 6; el 2 comentado lo descomentas con un `oferta_id` real |

Mediciones tomadas en PostgreSQL sobre `inmobiliaria_mcs` (carga E4: ~52 propiedades, 65 solicitudes, 88 visitas, 61 ofertas). Planes completos en [`results/time.txt`](../results/time.txt) (bloques A1, A2, C1, C2, D de `04_optimizacion_f5.sql`).

### Registro de tiempos y plan

| Consulta | Fase | Planning Time | Execution Time | Nodo principal (raíz / cost driver) |
|----------|------|---------------|----------------|-------------------------------------|
| 7 | Antes (A1) | 2.540 ms | **0.298 ms** | `GroupAggregate` → cadena `Hash Right Join`; **Seq Scan** en `visitas`, `ofertas`, `solicitudes_propiedad`, `propiedades` |
| 7 | Después índices (C1) | 1.175 ms | 0.428 ms | Misma estructura; el optimizador mantiene **Seq Scan** (tablas &lt; 1 página) |
| 9 | Antes (A2) | 1.705 ms | **0.352 ms** | `Incremental Sort` → `WindowAgg` → `HashAggregate`; anti-filtro **NOT IN** vía **Hash Join** (SubPlan hashed) + **Seq Scan** |
| 9 | Después índices (C2) | 1.929 ms | **0.264 ms** | Sigue **NOT IN** / SubPlan; coste estimado baja (≈ 52 → 32 en la raíz); ejecución **~25 % más rápida** que A2 |
| 9 reescrita NOT EXISTS (D) | Después | **0.642 ms** | 0.422 ms | **Hash Anti Join** + `HashAggregate` en CTE `cerradas`; **Index Scan** `pk_ciudades` con **Memoize**; `MIN` con `FILTER (WHERE publicada)` |

**Lectura honesta para el informe:** con este volumen, todas las ejecuciones están por debajo de **0,5 ms**. No hay órdenes de magnitud de mejora: el valor de los índices es **selectividad y escala** (miles de filas en solicitudes/visitas), no microsegundos en la demo. La consulta 7 **no ganó** tiempo tras indexar porque el motor prefiere **Seq Scan** cuando cada tabla cabe en pocas páginas de buffer.

### Conclusión de optimización (texto listo para informe)

1. **Consulta 7:** La hipótesis (índices en `propiedad_id` / `solicitud_id`) es válida en producción, pero con ~50–90 filas el plan sigue siendo **Hash Join + Seq Scan**. Los índices del script 04 formalizan FKs y habilitan **Index Scan** cuando crezca el inventario.
2. **Consulta 9:** Los índices en la cadena oferta → transacción redujeron la ejecución de **0,352 ms a 0,264 ms** (consulta original). La reescritura **NOT EXISTS** (D) mejora legibilidad del plan (**Hash Anti Join**) y baja el tiempo de planificación; usar D como consulta oficial de la pregunta 9.
3. **Evidencia:** citar `results/time.txt` y esta tabla en el Entregable 5 / informe final.

---

## 2. Optimización — consultas elegidas

### 2.1 Consulta 7 (pregunta E1 #7)

Agrega por **propiedad** solicitudes, visitas y ofertas con tres `LEFT JOIN`. Es la consulta analítica más costosa del portafolio: toca casi todo el pipeline comercial.

**Hipótesis:** sin índice en `solicitudes_propiedad(propiedad_id)`, `visitas(solicitud_id)` y `ofertas(solicitud_id)`, el optimizador recurre a **Hash Join** sobre **Sequential Scan** de tablas hijas. Con ~50–100 filas el tiempo puede ser similar al de microsegundos; con miles de solicitudes, los **Index Scan** o **Bitmap Index Scan** reducen lecturas en buffer.

**Cambio aplicado:** índices `idx_sol_propiedad_id`, `idx_visitas_solicitud_id`, `idx_ofertas_solicitud_id` (ver script 04, sección B).

**Conclusión medida:** ejecución antes 0.298 ms → después 0.428 ms (mismo plan; el segundo run puede ser ligeramente más lento por ruido de caché). El árbol sigue en **Seq Scan**; la justificación queda en **escala y selectividad**, no en milisegundos en la muestra del curso.

### 2.2 Consulta 9 (pregunta E1 #9)

Identifica propiedades **sin cierre** y calcula antigüedad con `MIN(fecha_publicacion)` y `RANK()`.

**Hipótesis:** el filtro `NOT IN (subconsulta de cierres)` obliga a materializar el conjunto de `propiedad_id` cerrados y comparar contra todas las propiedades. Índices en la cadena `ofertas(solicitud_id)` → `transacciones(oferta_id)` aceleran la subconsulta; el índice parcial `idx_publicaciones_propiedad_pub` favorece el `MIN(fecha_publicacion)` solo en avisos activos.

**Cambio aplicado:** mismos índices + **reescritura** a `NOT EXISTS` / CTE `cerradas` (sección D del script 04), alineada al contrato de la pregunta 9 (solo publicaciones con `publicada = TRUE` en el `MIN` mediante `FILTER`).

**Conclusión medida:** con índices, la 9 original pasa de 0.352 ms a **0.264 ms**; la reescritura (D) mejora sobre todo **planificación** (0.642 ms vs 1.7 ms) y el tipo de join (**Hash Anti Join**). Adoptar la versión D como consulta oficial de la pregunta 9 en el informe final.

---

## 3. Índices creados (resumen)

| Índice | Tabla | Justificación |
|--------|-------|----------------|
| `idx_sol_propiedad_id` | solicitudes_propiedad | JOIN pregunta 7; filtro por inmueble |
| `idx_sol_campana_id` | solicitudes_propiedad (parcial) | Pregunta 6; R10 |
| `idx_sol_estado_activo` | solicitudes_propiedad (parcial) | Pregunta 3; pipeline activo |
| `idx_visitas_solicitud_id` | visitas | JOIN visitas → solicitud |
| `idx_ofertas_solicitud_id` | ofertas | JOIN ofertas → solicitud |
| `idx_ofertas_estado` | ofertas | Trigger y cierres por oferta aceptada |
| `idx_transacciones_oferta_id` | transacciones | Anti-join / EXISTS de cierres |
| `idx_publicaciones_propiedad_pub` | publicaciones (parcial) | Pregunta 1 y 9; precio vigente |

Los índices **permanecen** en la base después de ejecutar 04; son parte de la implementación optimizada para sustentación y informe final.

---

## 4. Transacciones y ACID

### 4.1 Operación atómica del dominio

El cierre comercial (R12) no es un solo `INSERT`: el trigger `fn_validar_y_aplicar_transaccion`:

1. valida `estado_oferta = 'aceptada'`;
2. actualiza `solicitudes_propiedad` a `ganada`;
3. actualiza `propiedades.estado_comercial` a `vendida` o `no_disponible`.

Eso debe ocurrir en **una transacción**. La función `registrar_cierre` envuelve el `INSERT`; el trigger corre en la misma transacción del cliente (`BEGIN` … `COMMIT`).

**Evidencia:** script `05_transacciones_f5.sql`, bloques 2 (COMMIT exitoso) y 3 (`DO` con excepción y ausencia de fila huérfana).

### 4.2 Función `cerrar_venta_con_bloqueo`

Añade `FOR UPDATE` sobre la solicitud y la propiedad antes de llamar a `registrar_cierre`, para serializar dos asesores que intentan cerrar sobre el **mismo inmueble** al mismo tiempo.

### 4.3 Escenario de concurrencia

**Situación:** dos sesiones intentan registrar cierre para dos ofertas aceptadas distintas pero sobre la **misma** `propiedad_id` (caso límite de negocio).

**Sin bloqueo:** ambas transacciones pueden hacer `COMMIT`; `estado_comercial` queda con el último trigger que escribió (decisión ambigua, no corrupción de PK).

**Con `cerrar_venta_con_bloqueo`:** la segunda sesión **espera** el lock de fila; tras el `COMMIT` de la primera, la segunda continúa con el estado ya actualizado.

**Anomalía evitada:** condición de carrera en atributo derivado del proceso (estado comercial), análoga a actualizar inventario tras dos ventas simultáneas.

### 4.4 Nivel de aislamiento

| Escenario | Nivel recomendado | Motivo |
|-----------|-------------------|--------|
| Cierre OLTP (`registrar_cierre`, pgAdmin operativo) | **READ COMMITTED** (default) | Balance estándar en PostgreSQL; locks explícitos en propiedad |
| Reportes `EXPLAIN` / consultas 7 y 9 | **READ COMMITTED** | Lectura consistente por statement; datos de curso pequeños |
| Informe financiero que exige mismos conteos en toda la sesión | **REPEATABLE READ** | Snapshot estable; no necesario para la demo MCS |

PostgreSQL no implementa **READ UNCOMMITTED** de forma útil para suciedad de lectura; el default del curso es adecuado.

### 4.5 Propiedades ACID (mapa)

| ACID | Evidencia en MCS |
|------|------------------|
| **A** Atomicidad | `ROLLBACK` si oferta no aceptada; trigger + insert en una transacción |
| **C** Consistencia | CHECK, FK, triggers R6/R11/R12, `comision_valor` generado |
| **I** Aislamiento | READ COMMITTED + `FOR UPDATE` en cierre |
| **D** Durabilidad | `COMMIT` → WAL de PostgreSQL |

---

## 5. Productos del entregable 5

- Planes **antes/después** (secciones A y C de `04_optimizacion_f5.sql`).
- Hipótesis, índices y conclusión (este documento + tabla de tiempos rellenada).
- Script de transacción, demo de fallo y función de bloqueo (`05_transacciones_f5.sql`).
- Escenario de concurrencia y justificación de aislamiento (secciones 4.3–4.4).

---

## 6. Para el informe final

1. Adjuntar o referenciar [`results/time.txt`](../results/time.txt) (planes A1, A2, C1, C2, D).
2. Copiar la **tabla de la sección 1** y el párrafo “Conclusión de optimización” a la sección de optimización del informe.
3. Describir el cierre como transacción multi-paso (oferta → transacción → estados).
4. Opcional: en sustentación, abrir dos Query Tools y demostrar espera por lock (bloque 5 del script 05).
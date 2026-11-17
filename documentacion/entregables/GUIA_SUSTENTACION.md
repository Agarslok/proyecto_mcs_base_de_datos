# Guía de sustentación individual — Proyecto MCS

**Objetivo:** Si la profesora pide algo de esta lista, saber **dónde mirar** en el repo y **cómo responder** en voz alta.

**Archivos de apoyo:** modelos en `E2`/`E3`, SQL en `E4`/`E5`, Mongo en `E6`, reglas en `E1/E1_formulacion_MCS.md`.

---

## 1. Explicar una regla de negocio y mostrarla en el modelo

### Ejemplo listo (R6 — prospecto ≠ dueño)

**Regla:** Una oportunidad comercial relaciona **un prospecto** con **una propiedad**; el **dueño** del inmueble es otro rol y vive aparte.

| Capa | Dónde se ve |
|------|-------------|
| E1 | `R6` en formulación |
| Conceptual (E2) | Entidad `solicitudes_propiedad` une `personas` + `propiedades`; dueños en `propiedad_propietarios` |
| Relacional (E3) | `solicitudes_propiedad(persona_id, propiedad_id)`; puente `propiedad_propietarios` |
| Implementación (E4) | FK en `01_ddl_f4.sql`; trigger `trg_solicitud_no_es_dueno` impide que el dueño sea prospecto de la **misma** propiedad |

**Frase para decir:**  
*"R6 dice que el interesado no se modela como propietario. Por eso la solicitud tiene `persona_id` de prospecto y los dueños están en `propiedad_propietarios`. El trigger evita violar R6 en datos."*

### Ejercicio para practicar (R12)

1. Lee **R12** en `E1_formulacion_MCS.md` (solo se cierra con oferta aceptada).
2. Abre `E4_postgresql/sql/01_ddl_f4.sql` y busca `fn_validar_y_aplicar_transaccion`.
3. Dibuja en una servilleta: `ofertas` → `transacciones` → updates en `solicitudes` y `propiedades`.
4. Ensaya 60 segundos: regla + tabla + trigger.

**Autocomprobación:** ¿Qué pasa si inserto en `transacciones` con oferta `pendiente`? → Exception R12, sin fila (lo viste en `f5_transaccion_rollback_do.png`).

---

## 2. Justificar cardinalidad, clave o normalización

### Ejemplo A — Cardinalidad

**Relación:** `solicitudes_propiedad` **1:N** `visitas`.

- Una solicitud puede tener cero o muchas visitas.
- Cada visita **debe** tener exactamente una `solicitud_id` (FK obligatoria).

**Por qué no N:M:** una visita no mezcla dos solicitudes distintas en el negocio.

### Ejemplo B — Normalización (1FN)

**Problema evitado:** columna `canales = "Meta; web"` en `propiedades`.

**Solución:** tabla puente `publicacion_canales` (muchas filas, una fila por par publicación-canal).

**Frase:** *"Eso es 1FN: un valor atómico por celda; listas pasan a filas con FK."*

Evidencia corta: `E3_modelo_relacional/E3_evidencia_normalizacion_resumida.md`.

### Ejercicio

1. Abre `E2_modelo_conceptual/f2_diagrama_conceptual.png`.
2. Elige la relación **campanas ↔ propiedades**.
3. Responde: ¿1:N, N:M? ¿Qué tabla puente en E3? (`campana_propiedades`).
4. Elige una **PK**: ¿por qué `solicitud_id` es IDENTITY y no el par (persona, propiedad)? → Una persona puede tener **varias** solicitudes sobre la misma propiedad en el tiempo / distintas oportunidades.

---

## 3. Modificar en vivo una consulta SQL (o variante de una pregunta)

### Ejemplo (partir de pregunta 6 — campañas)

**Pregunta E1 #6:** campañas y canales con más prospectos.

**Variante que podrían pedir:** *"Solo campañas **activas** en Bogotá."*

Idea (no memorices literal; entiende los JOIN):

```sql
SELECT ca.nombre_campana, cm.nombre AS canal, COUNT(s.solicitud_id) AS oportunidades
FROM campanas ca
JOIN canales_marketing cm ON cm.canal_id = ca.canal_id
JOIN solicitudes_propiedad s ON s.campana_id = ca.campana_id
JOIN propiedades p ON p.propiedad_id = s.propiedad_id
JOIN ciudades c ON c.ciudad_id = p.ciudad_id
WHERE ca.estado = 'activa'
  AND c.nombre = 'Bogota'
GROUP BY ca.campana_id, ca.nombre_campana, cm.nombre
ORDER BY oportunidades DESC;
```

**Cómo pensar en vivo:** misma consulta base en `E4/sql/03_consultas_f4.sql` (bloque pregunta 6) + `WHERE` + un JOIN más a `propiedades`/`ciudades`.

### Ejercicio

**Enunciado:** Pregunta **#1** — inventario disponible — pero solo inmuebles en **Medellín** con precio **menor a 500 millones**.

1. Localiza en `03_consultas_f4.sql` la consulta de pregunta 1 (`v_inventario_disponible`).
2. Escribe: `SELECT * FROM v_inventario_disponible WHERE ciudad = 'Medellin' AND precio < 500000000 ORDER BY precio;`
3. Prueba en pgAdmin (F5 sobre el SELECT solo).
4. Variante más difícil: mismo filtro pero usando **JOIN** sin la vista (abre la definición de la vista en el mismo archivo y copia el cuerpo + WHERE).

**Autocomprobación:** Si olvidas nombres de columna, en pgAdmin: clic derecho en la vista → View/Properties o lee el `CREATE VIEW` en el script.

---

## 4. Interpretar un plan EXPLAIN y pertinencia de un índice

### Ejemplo (consulta 7, bloque A1 en `04_optimizacion_f5.sql`)

**Fragmento típico del plan:**

```text
Seq Scan on visitas v
Hash Right Join ...
Execution Time: 0.466 ms
```

**Qué decir:**

- **Seq Scan:** leyó la tabla `visitas` entera (pocas filas → barato).
- **Hash Join:** construye tablas hash para unir `propiedades`, `solicitudes`, `visitas`, `ofertas`.
- **Índice `idx_visitas_solicitud_id`:** útil cuando `visitas` tenga miles de filas y el JOIN sea por `solicitud_id`; con ~88 filas el optimizador puede seguir prefiriendo Seq Scan.

**Hipótesis del script 04:** índices en FKs de unión (`propiedad_id`, `solicitud_id`) preparan **escala**, no microsegundos en la demo.

### Ejercicio

1. En pgAdmin, ejecuta solo el bloque **A1** de `E5/sql/04_optimizacion_f5.sql`.
2. En el plan, subraya **un** nodo Seq Scan y **un** Join.
3. Responde en voz alta: *"¿Qué tabla escanea? ¿Por qué el índice idx_ofertas_solicitud_id podría ayudar en producción?"*
4. Compara con `E5/time.txt`: consulta 9 bajó algo tras índices; consulta 7 a veces no (tablas pequeñas).

---

## 5. Justificar transacción y nivel de aislamiento

### Ejemplo (cierre comercial)

**Operación atómica:** insertar `transacciones` + marcar solicitud `ganada` + propiedad `vendida`.

**Código:**

- `BEGIN; … registrar_cierre(16, …); … COMMIT;` en `05_transacciones_f5.sql`
- `registrar_cierre` → INSERT → trigger `trg_validar_y_aplicar_transaccion`

**ACID en una frase cada uno:**

| Propiedad | En MCS |
|-----------|--------|
| Atomicidad | Si la oferta no está aceptada, falla todo; no queda INSERT a medias (bloque DO, oferta 1) |
| Consistencia | FK + triggers R11/R12 mantienen estados coherentes |
| Aislamiento | Default `READ COMMITTED` (`SHOW transaction_isolation`); concurrencia extra con `FOR UPDATE` en `cerrar_venta_con_bloqueo` |
| Durabilidad | Tras `COMMIT`, el cierre persiste |

**Por qué READ COMMITTED aquí:** operación OLTP corta; bloqueo de fila en propiedad evita dos cierres conflictivos sobre el mismo inmueble sin subir a SERIALIZABLE en toda la base.

### Ejercicio

1. Lee el bloque 3 de `05_transacciones_f5.sql` (DO $$).
2. Explica: ¿hay `ROLLBACK` explícito? (No; la excepción aborta el subbloque y no inserta.)
3. Escenario oral: *"Dos asesores cierran dos ofertas de la misma propiedad a la vez"* → ¿qué función usar? → `cerrar_venta_con_bloqueo`.

---

## 6. Por qué una parte fue a MongoDB

### Ejemplo (seguimiento omnicanal)

**Qué no cupe bien solo en PostgreSQL:** mensajes de WhatsApp, notas internas con campos variables (`duracion_seg`, `sentimiento`, adjuntos, texto libre en `contenido` / `metadata`).

**Qué sí queda en Postgres:** visitas estructuradas (`visitas`: fecha, duración, calificación).

**Mongo:** colección `seguimiento_eventos` en `inmobiliaria_mcs_mongo`:

- Mismo `solicitud_id`, `persona_id`, `propiedad_id` (enteros, referencia lógica al SQL).
- Esquema flexible sin migración cada vez que cambia un canal.

**No se replica:** tablas `personas`, `propiedades`, etc.

**Agregaciones:** A1 eventos por canal; A2 top oportunidades — complementan preguntas 4–6 de marketing/seguimiento.

### Ejercicio

1. Abre un documento de `E6/scripts/seguimiento_eventos_seed.json` (línea de WhatsApp y una de `nota_interna`).
2. Pregunta: *"¿Por qué no una columna `mensaje_whatsapp` en `visitas`?"*  
   Respuesta: no todas las interacciones son visitas; campos distintos por canal; 1FN y rigidez del DDL.
3. Corre mentalmente: `mongosh --file 01_setup_y_carga_f6.js` → 36 docs → A1 cuenta whatsapp=14.

---

## Rutina de estudio (30 min por persona)

| Día | Tarea |
|-----|--------|
| 1 | R6 + R12 en modelo y DDL; ejercicio 1 |
| 2 | Una cardinalidad + un fragmento 1FN; ejercicio 2 |
| 3 | Modificar consulta 1 y 6 en pgAdmin; ejercicio 3 |
| 4 | Leer un plan EXPLAIN de captura f5; ejercicio 4 |
| 5 | Explicar COMMIT oferta 61 y NOTICE oferta 1; ejercicio 5 |
| 6 | Mongo: seed + A1; ejercicio 6 |

**Repaso rápido:** `E1` reglas → `E3` normalización resumida → `E4` consulta 9 con `RANK` → `E5` transacción → `E6` justificación.

---

## Mapa “si me preguntan X, abro Y”

| Pregunta de la profesora | Abrir primero |
|--------------------------|---------------|
| Regla de negocio | `E1_formulacion_MCS.md` tabla R* |
| Cardinalidad / FK | `E2` PNG o `E3_claves_pk_fk.json` |
| Normalización | `E3_evidencia_normalizacion_resumida.md` |
| SQL en vivo | `E4/sql/03_consultas_f4.sql` |
| EXPLAIN / índice | `E5/sql/04_optimizacion_f5.sql` + `time.txt` |
| Transacción | `E5/sql/05_transacciones_f5.sql` + trigger en `01_ddl_f4.sql` |
| Mongo | `E6_mongodb_nosql.md` + seed JSON |
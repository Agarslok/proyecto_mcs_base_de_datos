# Guía para el equipo — qué se hizo y cómo repetirlo

**Proyecto:** sistema de gestión y trazabilidad comercial de una inmobiliaria (MCS)  
**Equipo:** Harold Burgos, Sofía Camelo, Juan Triana  
**Para quién es este archivo:** para que cualquiera del grupo pueda explicar el trabajo, volver a ejecutar los scripts y saber qué prueba cada captura.

La profesora autorizó el grupo de tres. Las figuras de los modelos ya están exportadas. El informe en Word o PDF se arma después, a partir de los `.md` de `documentacion/` y de las imágenes en `documentacion/evidencia/`.

---

## 1. La idea en pocas frases

La inmobiliaria tenía la información repartida (propiedades, campañas, interesados, visitas, ofertas). El proyecto deja eso en una base **relacional** en PostgreSQL y un pedazo **documental** en MongoDB.

- **PostgreSQL** (`inmobiliaria_mcs`) guarda lo estructurado: inmuebles, personas, campañas, solicitudes, visitas, ofertas y el cierre (la transacción).
- **MongoDB** (`inmobiliaria_mcs_mongo`, colección `seguimiento_eventos`) guarda el historial suelto de WhatsApp, llamadas, correos, notas internas y ferias. No copia las tablas de PostgreSQL: solo guarda los mismos números de `solicitud_id`, `persona_id` y `propiedad_id` para poder cruzar después.

Una **solicitud** es “este prospecto está interesado en esta propiedad”. El dueño del inmueble no es el prospecto. Eso es la regla R6.

---

## 2. Dónde está cada cosa

| Carpeta o archivo | Qué es |
|---|---|
| `documentacion/01_formulacion_problema.md` | Problema, reglas R1–R16 y las 10 preguntas que la base debe responder |
| `documentacion/02_modelo_conceptual.md` | Entidades, cardinalidades y diccionario. El dibujo está en `codigo/modelos/modelo_conceptual_2.1.drawio` (versión 2.3) |
| `documentacion/03_modelo_relacional_normalizacion_f3.md` | Paso a tablas, llaves y normalización hasta BCNF. Dibujo: `codigo/modelos/modelo_relacional_2.0.drawio` (BD_MCS v1.3) |
| `documentacion/04_consultas_vs_preguntas_f4.md` | Qué consulta SQL responde cada pregunta |
| `documentacion/05_optimizacion_transacciones_f5.md` | Índices, tiempos y la transacción de cierre |
| `documentacion/07_mongodb_nosql_f6.md` | Por qué MongoDB y cómo correr los scripts |
| `documentacion/06_informe_final_base_f6.md` | Borrador para copiar al informe final. El nombre dice “f6”, pero es la base del entregable 7 |
| `codigo/sql/` | Scripts de PostgreSQL, en el orden `00` → `05` |
| `codigo/backup/inmobiliaria_mcs_f4.sql` | Respaldo de la base |
| `codigo/mongodb/` | Carga, CRUD y agregaciones |
| `documentacion/evidencia/` | Capturas que van al informe |
| `results/time.txt` | Planes `EXPLAIN ANALYZE` copiados en texto |

---

## 3. Cómo reconstruir la base en pgAdmin

Conéctate al servidor **PostgreSQL 18**.

1. Clic derecho en la base **postgres** → **Query Tool**. Abre `codigo/sql/00_crear_base_f4.sql` y ejecútalo (F5). Crea `inmobiliaria_mcs`. Si la base ya existe, el `CREATE` falla: es normal, sigue con el paso 2.
2. Clic derecho en **inmobiliaria_mcs** → **Query Tool**. De aquí en adelante todos los scripts van sobre esta base.
3. Ejecuta entero `01_ddl_f4.sql`. **Borra las tablas y las vuelve a crear.** Al final Messages debe decir que la consulta terminó bien (el script hace `BEGIN` … `COMMIT`).
4. Ejecuta entero `02_carga_f4.sql`. Carga datos de prueba, no clientes reales. Messages debe mostrar `COMMIT`.
5. Ejecuta entero `03_consultas_f4.sql`. Crea las vistas, la función de cierre y el trigger, y corre las 10 consultas. El último resultado es la tabla de conteos.
6. `04_optimizacion_f5.sql` no se ejecuta de un solo golpe. Primero el bloque **A1** (plan de la consulta 7, antes de índices), luego el bloque **B** (crea índices), luego el bloque **D** (plan de la consulta 9 ya reescrita).
7. `05_transacciones_f5.sql` tampoco entero. El bloque del `BEGIN` … `COMMIT` con la oferta **16** se corre **una sola vez**. Si se repite, falla, porque esa oferta ya quedó cerrada.

En el Explorador de Windows las capturas se guardaron en `documentacion/evidencia/`.

---

## 4. Qué hace cada script de PostgreSQL

### `00_crear_base_f4.sql`

Solo crea la base vacía, con codificación UTF-8. No crea tablas.

### `01_ddl_f4.sql`

Es el modelo relacional v1.3 convertido en tablas. Incluye:

- claves primarias y foráneas;
- `NOT NULL`, `UNIQUE`, `CHECK` y valores por defecto donde hacen falta;
- `comision_valor` como columna **calculada** (`GENERATED`): la comisión no se digita, sale de `valor_final * comision_porcentaje` (regla R16);
- triggers que cuidan reglas de negocio:
  - **R6:** quien es dueño de una propiedad no puede quedar como prospecto de esa misma propiedad (`trg_solicitud_no_es_dueno`);
  - **R11:** si una oferta pasa a `aceptada`, la propiedad deja de estar simplemente `disponible` y pasa a `en_negociacion`;
  - **R12:** no se puede registrar un cierre si la oferta no está `aceptada`. Si el cierre es válido, la solicitud queda `ganada` y la propiedad `vendida` (si la operación es venta) o `no_disponible`.

La función `registrar_cierre(...)` mete la fila en `transacciones` en una sola llamada. El trigger hace el resto.

### `02_carga_f4.sql`

Datos sintéticos coherentes con esas reglas. Ciudades, tipos y canales son catálogos chicos a propósito. Las tablas del proceso comercial superan las 50 filas que pide el curso.

Conteos de esa carga (captura `f4_conteos_tablas.png`), **antes** del cierre extra de la fase 5:

| Tabla | Filas |
|---|---|
| personas | 55 |
| propiedades | 52 |
| publicaciones | 60 |
| solicitudes_propiedad | 65 |
| visitas | 88 |
| ofertas | 61 |
| transacciones | 18 |

Después de cerrar la oferta 16, `transacciones` queda en **19**. Por eso el conteo y el cierre no tienen el mismo número: se tomaron en ese orden.

### `03_consultas_f4.sql`

Responde las 10 preguntas del entregable 1. Para mostrar una sola en clase, se selecciona ese bloque y se pulsa F5. No hace falta correr el archivo completo otra vez.

| Pregunta | Qué responde | Cómo está hecha |
|---|---|---|
| 1 | Qué propiedades están disponibles, a qué precio y dónde | Vista `v_inventario_disponible`. Solo publicaciones vigentes (`publicada = TRUE`) |
| 2 | Qué prospectos se interesaron en cada inmueble | JOIN de solicitud, persona y propiedad |
| 3 | Qué propiedades tienen más oportunidades abiertas | `GROUP BY` y `HAVING` (al menos 2) |
| 4 | En qué estado va cada prospecto | Vista `v_pipeline_activo` |
| 5 | Qué visitas hubo en cada oportunidad | JOIN con `visitas` |
| 6 | Qué campañas y canales trajeron más interesados | `GROUP BY` campaña y canal. Si la solicitud no tiene campaña (`campana_id` nulo, regla R10), no entra en este conteo |
| 7 | Cuántos prospectos, visitas y ofertas tiene cada inmueble | CTE `metricas` y tres `LEFT JOIN`. Es una de las dos consultas que se midieron en la fase 5 |
| 8 | Cuáles oportunidades avanzaron a negociación o cierre y cuáles no | Subconsulta con `EXISTS` |
| 9 | Qué propiedades llevan más tiempo publicadas sin un cierre | CTE y ventana `RANK()`. Es la otra consulta medida en la fase 5 |
| 10 | Cuánto dinero y qué comisión dejaron los cierres | Vista `v_resultado_cierres`. Usa `comision_valor` calculado |

El último `SELECT` del archivo solo cuenta filas. No es una pregunta del negocio; sirve para demostrar que la carga alcanzó el mínimo.

### `04_optimizacion_f5.sql`

Se eligieron las consultas 7 y 9 porque tocan casi todo el proceso (propiedades, solicitudes, visitas, ofertas, transacciones).

**Hipótesis:** sin índice en las llaves por las que se unen esas tablas (`propiedad_id`, `solicitud_id`, `oferta_id`), PostgreSQL recorre la tabla completa (Seq Scan). Con índice, en una base grande podría usar Index Scan.

**Qué pasó de verdad con estos datos (pocas decenas de filas):**

- Consulta 7: el plan sigue en Seq Scan. El tiempo no bajó. Con tablas tan pequeñas el motor prefiere leerlas enteras. Los índices quedan justificados para cuando haya miles de filas, no por los milisegundos de esta demo.
- Consulta 9: con índices el tiempo de ejecución bajó (en la medición guardada en `results/time.txt`, de 0,352 ms a 0,264 ms).
- La reescritura del bloque **D** cambia el `NOT IN` por `NOT EXISTS`. El plan pasa a un **Hash Anti Join** y en la captura se ve un **Index Scan** sobre `pk_ciudades`. Es la versión que conviene explicar en la sustentación.

La captura `f5_explain_7_antes.png` es el plan de la 7 **antes** de crear los índices del bloque B. La captura `f5_explain_9_despues.png` es el bloque D, **después**. Los tiempos de la foto no tienen que ser idénticos a `time.txt`: son otra ejecución en la misma máquina. Lo que importa es el tipo de plan (Seq Scan frente a Index Scan / Hash Anti Join) y que aparezcan Planning Time y Execution Time.

### `05_transacciones_f5.sql`

La operación que debe ser atómica es el **cierre**: insertar la transacción, marcar la solicitud como ganada y actualizar el estado de la propiedad. O pasan las tres cosas, o no pasa ninguna.

- **COMMIT (oferta 16).** La oferta 16 ya estaba `aceptada` y no tenía fila en `transacciones`. `registrar_cierre(16, …)` con valor final 250.000.000 y comisión 3,5 % inserta el cierre. El trigger pone la solicitud en `ganada` y la propiedad **3** (“Local comercial en Teusaquillo…”) en `vendida`.  
  - `f5_transaccion_commit_16.png` muestra el `COMMIT` en Messages.  
  - `f5_transaccion_commit_16_02.png` muestra el `SELECT` de verificación: `estado_comercial = vendida` y `estado_solicitud = ganada`.  
  No se vuelve a ejecutar el `BEGIN`. La oferta ya está cerrada.

- **ROLLBACK (oferta 1).** La oferta 1 está `pendiente`. El bloque `DO` intenta cerrarla, el trigger lanza el error de la regla R12 y no queda fila en `transacciones`. En Messages se leen los dos avisos:  
  `ROLLBACK implícito OK: R12: la transacción exige oferta aceptada (oferta_id=1, estado=pendiente)`  
  `Atomicidad: no quedó fila en transacciones para oferta 1`  
  Eso es la captura `f5_transaccion_rollback_do.png`.

**ACID, en palabras de este caso:**

- **Atomicidad:** el cierre inválido no deja una transacción a medias.
- **Consistencia:** no se puede cerrar una oferta que no está aceptada, y un cierre válido deja solicitud y propiedad alineadas.
- **Aislamiento:** la función `cerrar_venta_con_bloqueo` (mismo archivo, más abajo) hace `FOR UPDATE` sobre la solicitud y la propiedad para que dos sesiones no cierren a la vez dos ofertas de la misma propiedad y dejen el estado contradictorio. El nivel adecuado para ese caso es el de la transacción que toma el bloqueo de fila; el aislamiento por defecto de PostgreSQL es `READ COMMITTED`, y el `FOR UPDATE` es lo que evita la condición de carrera.
- **Durabilidad:** después del `COMMIT`, el cierre de la oferta 16 permanece aunque se cierre pgAdmin.

---

## 5. Qué prueba cada captura

Todas están en `documentacion/evidencia/`.

| Archivo | Qué tiene que poder decir el equipo |
|---|---|
| `f2_diagrama_conceptual.png` | Mismo dibujo que `modelo_conceptual_2.1.drawio`: 21 entidades. Las relaciones N:M todavía no son tablas |
| `f3_diagrama_relacional.png` | Mismo dibujo que `modelo_relacional_2.0.drawio`: las 24 tablas del script `01_ddl_f4.sql`, con PK y FK |
| `f0_bd_creada.png` | La base `inmobiliaria_mcs` existe en PostgreSQL 18 |
| `f4_ddl_commit.png` | El script de tablas corrió sobre esa base y terminó bien |
| `Carga_03.png` | La carga de datos hizo `COMMIT` |
| `f4_consulta01_inventario.png` | Pregunta 1: 31 publicaciones vigentes, con ciudad y precio |
| `f4_consulta06_campanas.png` | Pregunta 6: 12 campañas, con canal y número de oportunidades (la primera tiene 8) |
| `f4_consulta09_rank.png` | Pregunta 9: días en comercialización y `ranking_antiguedad` (la más antigua, 972 días, rango 1) |
| `f4_conteos_tablas.png` | La carga supera 50 filas en las tablas de negocio (ver tabla de la sección 4) |
| `f4_backup_propiedades.png` | El respaldo `inmobiliaria_mcs_f4.sql` está en `codigo/backup/` (14/11/2026) |
| `f5_explain_7_antes.png` | Plan de la consulta 7 antes de los índices: Seq Scan, con Planning Time y Execution Time |
| `f5_explain_9_despues.png` | Plan de la consulta 9 reescrita (`NOT EXISTS`): Index Scan en `pk_ciudades` |
| `f5_transaccion_commit_16.png` | El cierre de la oferta 16 hizo `COMMIT` |
| `f5_transaccion_commit_16_02.png` | Después de ese cierre, la propiedad 3 está `vendida` y la solicitud `ganada` |
| `f5_transaccion_rollback_do.png` | La oferta 1 (pendiente) no se cerró y no dejó fila |
| `f6_mongo_compass_coleccion.png` | 36 eventos en `seguimiento_eventos`, con fecha de tipo fecha |
| `f6_agregacion_canales.png` | WhatsApp 14, llamada 7, nota interna 7, email 6, feria 2 |
| `f6_agregacion_top_solicitudes.png` | La solicitud 2 (propiedad 1) es la que más interacciones tiene: 3 |

`f6_agregacion_canales_resultado.json` y `f6_agregacion_top_solicitudes_resultado.json` son esos mismos resultados en JSON. No son la colección. La colección completa es `codigo/mongodb/seguimiento_eventos_seed.json`.

---

## 6. MongoDB

Sirve porque un mensaje de WhatsApp, una llamada y una nota interna no tienen las mismas columnas. Meter eso en PostgreSQL obligaría a cambiar el esquema cada vez que aparezca un campo nuevo (`duracion_seg`, `sentimiento`, un adjunto). En Mongo cada evento es un documento con `contenido` y `metadata` flexibles.

**Cómo repetirlo**, desde la carpeta del proyecto, con el servicio de Mongo encendido:

```text
mongosh --file "codigo\mongodb\01_setup_y_carga_f6.js"
mongosh --file "codigo\mongodb\02_crud_f6.js"
mongosh --file "codigo\mongodb\03_agregaciones_f6.js"
```

Qué hace cada uno:

1. **`01_setup_y_carga_f6.js`** borra la colección, inserta los 36 eventos (convirtiendo la fecha a `Date`) y crea dos índices: por solicitud+fecha (para ver la línea de tiempo de una oportunidad) y por canal+fecha (para agrupar por canal).
2. **`02_crud_f6.js`** inserta un evento de prueba, lo lee, lo actualiza y lo borra. Al final el conteo vuelve a 36. Demuestra Create, Read, Update y Delete.
3. **`03_agregaciones_f6.js`** responde dos preguntas que complementan las de seguimiento y marketing:
   - **A1.** ¿Qué canal concentra más eventos?
   - **A2.** ¿Qué oportunidad (`solicitud_id` + `propiedad_id`) tiene más interacciones? Muestra las 10 primeras.

En Compass la base se llama `inmobiliaria_mcs_mongo` y la colección `seguimiento_eventos`. La conexión de las capturas aparece como **MCS**.

---

## 7. Cómo leer los dos diagramas (y por qué no tienen el mismo número de cajas)

Los PNG de `documentacion/evidencia/` son la exportación de los `.drawio`. Se contrastaron con `01_ddl_f4.sql`.

**Conceptual** (`f2_diagrama_conceptual.png`, 21 cajas). Describe el negocio. `#` es identificador, `*` obligatorio, `o` opcional. Una solicitud une un prospecto con una propiedad. El dueño va aparte, en `propiedad_propietarios`. Construcción y terreno son detalles opcionales de la propiedad (una casa puede tener los dos; un lote solo terreno). `comision_valor` está marcado como derivado: no se digita.

Tres relaciones son muchos-a-muchos y en este dibujo son líneas, no tablas:

- una persona y varios tipos de persona;
- una publicación y varios canales;
- una campaña y varias propiedades.

**Relacional** (`f3_diagrama_relacional.png`, 24 tablas). Es el paso siguiente: esas tres líneas se convierten en `persona_roles`, `publicacion_canales` y `campana_propiedades`. Esas 24 tablas son exactamente las de `01_ddl_f4.sql`. Las columnas que en el conceptual eran relaciones aquí son llaves foráneas (`ciudad_id`, `propiedad_id`, `solicitud_id`, etc.). `comision_valor` queda como columna generada, igual que en PostgreSQL.

MongoDB no aparece en ninguno de los dos dibujos. El seguimiento de WhatsApp, llamadas y notas vive solo en `seguimiento_eventos` y referencia los mismos `solicitud_id` y `propiedad_id`.

---

## 8. Qué falta

Armar el informe técnico en Word o PDF usando `06_informe_final_base_f6.md` como índice e insertar las figuras de `documentacion/evidencia/`.

No hay que volver a correr los scripts ni reexportar los diagramas.

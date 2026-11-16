# Presentación — MCS Inmobiliaria

**Equipo:** Harold Burgos, Sofía Camelo, Juan Triana  
**Base relacional:** `inmobiliaria_mcs` (PostgreSQL)  
**Base documental:** `inmobiliaria_mcs_mongo` (MongoDB)

Dos o tres diapositivas por fase. El texto de cada bloque es el que va en la diapositiva.

---

## Apertura

### Diapositiva 0 — Portada

Sistema de gestión y trazabilidad comercial para una inmobiliaria

Harold Burgos, Sofía Camelo, Juan Triana  
Bases de datos · 2026-2

PostgreSQL `inmobiliaria_mcs`  
MongoDB `inmobiliaria_mcs_mongo`

---

## Fase 1 — Formulación

### Diapositiva 1.1 — El problema

La inmobiliaria tenía propiedades, campañas, prospectos y seguimientos en archivos separados.

Eso producía:

- prospectos y propiedades duplicados
- historial de contactos incompleto
- campañas sin relación clara con las oportunidades que generaban

Buscamos una base que deje trazado quién se interesó, en qué inmueble, por qué campaña, qué seguimiento hubo y cómo cerró.

### Diapositiva 1.2 — Alcance y reglas

Incluimos propiedades, prospectos, campañas, visitas, ofertas y cierres.

Dejamos fuera contabilidad, nómina, trámites jurídicos y la automatización de WhatsApp.

Reglas que sostienen el diseño:

- R6: la solicitud une un prospecto con una propiedad; el dueño va aparte
- R10: la campaña en la solicitud es opcional
- R12: solo se cierra una oferta aceptada
- R16: la comisión se calcula, no se digita

### Diapositiva 1.3 — Lo que la base debe responder

Diez preguntas. Tres ejemplos:

1. Qué propiedades están disponibles, a qué precio y en qué ciudad.
6. Qué campañas y canales trajeron más oportunidades.
9. Qué propiedades llevan más tiempo publicadas sin un cierre.

Esas preguntas son el contrato de las consultas SQL.

---

## Fase 2 — Modelo conceptual

### Diapositiva 2.1 — Qué modelamos

Diez entidades de proceso: personas, propiedades, dueños, publicaciones, campañas, solicitudes, visitas, ofertas, transacciones y empleados.

Los catálogos (ciudades, tipos de inmueble, canales, roles) evitan texto libre.

Construcción y terreno son detalles opcionales de la propiedad. Una casa puede tener los dos; un lote, solo terreno.

### Diapositiva 2.2 — La decisión de R6

La solicitud no apunta al dueño.

`solicitudes_propiedad` relaciona persona interesada y propiedad.  
`propiedad_propietarios` registra a los dueños.

Una persona puede ser dueña de un inmueble y prospecto de otro. Esos papeles no se mezclan.

### Diapositiva 2.3 — Cardinalidades que importan

- Una propiedad, uno o más dueños.
- Una solicitud, cero o muchas visitas. Cada visita pertenece a una sola solicitud.
- Una oferta nace de una solicitud. Una oferta tiene como máximo un cierre.
- Campaña y propiedad son muchos a muchos. En el conceptual eso es una línea, no una tabla.

---

## Fase 3 — Modelo relacional y normalización

### Diapositiva 3.1 — De 21 cajas a 24 tablas

El relacional es BD_MCS v1.3, 24 tablas, las mismas del script de creación.

Tres relaciones muchos a muchos del conceptual pasaron a tablas puente:

- `persona_roles`
- `publicacion_canales`
- `campana_propiedades`

`propiedad_propietarios` ya era entidad en el conceptual, porque el dueño tiene identidad propia.

### Diapositiva 3.2 — 1FN a BCNF

1FN: nada de listas en una celda. “Ana, Luis” o “Meta; web” serían filas en un puente.

2FN: el nombre del dueño vive en `personas`, no en el puente de propietarios.

3FN: la ciudad, el canal y el rol no se copian. Se consultan con JOIN. La visita no guarda `propiedad_id`: se llega por la solicitud.

BCNF: cada determinante es una llave. No partimos tablas que ya cumplían.

`comision_valor` se calcula en PostgreSQL a partir del valor final y el porcentaje.

### Diapositiva 3.3 — Llaves del proceso

`solicitud_id` identifica la oportunidad.  
`visitas.solicitud_id`, `ofertas.solicitud_id` y `transacciones.oferta_id` arman la cadena.

La matrícula inmobiliaria es única, además del `propiedad_id`.  
`campana_id` en la solicitud puede quedar vacío.

---

## Fase 4 — PostgreSQL

### Diapositiva 4.1 — Cómo quedó armada la base

Orden de scripts, sobre `inmobiliaria_mcs` (el primero se corre en `postgres`):

1. Crear la base.
2. Crear las 24 tablas, restricciones, función de cierre y triggers.
3. Cargar datos de prueba.
4. Vistas y las diez consultas.

Conteos de la carga: 55 personas, 52 propiedades, 65 solicitudes, 88 visitas, 61 ofertas, 18 transacciones.

### Diapositiva 4.2 — Consultas y reglas en el motor

Tres vistas reutilizables: inventario disponible, pipeline activo y resultado de cierres.

Las diez preguntas usan JOIN, agrupación con HAVING, subconsulta, CTE y `RANK()`.

Triggers que cuidan el negocio:

- el dueño no puede ser prospecto de su misma propiedad
- una oferta aceptada pasa la propiedad a negociación
- un cierre exige oferta aceptada, marca la solicitud ganada y actualiza el estado del inmueble

El respaldo está en `inmobiliaria_mcs_f4.sql`.

### Diapositiva 4.3 — Tres resultados

Pregunta 1: 31 publicaciones vigentes, con ciudad y precio.

Pregunta 6: 12 campañas. La de más oportunidades tiene 8.

Pregunta 9: la propiedad más antigua sin cierre lleva 972 días y queda en el rango 1.

---

## Fase 5 — Optimización y transacciones

### Diapositiva 5.1 — Qué medimos

Elegimos la consulta 7 (prospectos, visitas y ofertas por inmueble) y la consulta 9 (antigüedad sin cierre).

Hipótesis: faltaban índices en las columnas con las que se unen solicitudes, visitas, ofertas y transacciones. En PostgreSQL la llave foránea no crea ese índice sola.

Con esta carga todas las ejecuciones quedaron bajo 0,5 ms.

### Diapositiva 5.2 — Qué pasó al indexar y al reescribir

Consulta 7: el plan siguió en Seq Scan. Pasó de 0,298 ms a 0,428 ms. Con tablas tan pequeñas el motor prefiere leerlas enteras. Los índices quedan para cuando haya miles de filas.

Consulta 9 original: de 0,352 ms a 0,264 ms después de los índices.

La reescritura con `NOT EXISTS` cambia el plan a Hash Anti Join y baja el tiempo de planificación. Esa es la versión que usamos para la pregunta 9.

### Diapositiva 5.3 — El cierre es una sola transacción

`registrar_cierre` inserta en `transacciones`. El trigger, en la misma transacción:

1. exige oferta aceptada
2. deja la solicitud en ganada
3. deja la propiedad en vendida o no disponible

Oferta 16: COMMIT. La propiedad 3 quedó vendida y la solicitud ganada.

Oferta 1, pendiente: el cierre se rechaza y no queda fila en `transacciones`.

Si dos sesiones cierran ofertas del mismo inmueble, `cerrar_venta_con_bloqueo` toma la fila con `FOR UPDATE`. La segunda espera. El nivel de aislamiento del cierre es READ COMMITTED, el de PostgreSQL, más ese bloqueo.

---

## Fase 6 — MongoDB

### Diapositiva 6.1 — Qué no metimos en PostgreSQL

Las visitas sí están en SQL: fecha, duración y calificación.

WhatsApp, llamadas, correos, notas internas y ferias no comparten las mismas columnas. Un mensaje trae texto; una llamada, duración; una nota, prioridad.

Eso vive en la colección `seguimiento_eventos`. Cada documento guarda `contenido` y `metadata` según el canal.

No copiamos personas ni propiedades. Guardamos `solicitud_id`, `persona_id` y `propiedad_id` para cruzar con PostgreSQL.

### Diapositiva 6.2 — Carga, índices y CRUD

36 eventos. Canales: WhatsApp 14, llamada 7, nota interna 7, correo 6, feria 2.

Dos índices: solicitud + fecha, para la línea de tiempo de una oportunidad; canal + fecha, para agrupar por canal.

El script de CRUD inserta un evento de prueba, lo lee, lo actualiza y lo borra. La colección vuelve a 36 documentos.

### Diapositiva 6.3 — Dos agregaciones

A1. Eventos por canal. WhatsApp concentra la actividad.

A2. Oportunidades con más interacciones. La solicitud 2, propiedad 1, tiene 3. El resto del top tiene 2.

Complementan el seguimiento y las campañas. Las visitas siguen contándose en SQL.

---

## Cierre

### Diapositiva 7.1 — Qué entregamos

Un hilo continuo: problema, modelo conceptual, 24 tablas en BCNF, base PostgreSQL con diez consultas, medición de dos planes, cierre transaccional y el historial de contactos en MongoDB.

### Diapositiva 7.2 — Límites que asumimos

- Una persona tiene un teléfono y un correo.
- Los empleados no están dentro de `personas`.
- Con pocas filas, los índices no cambian el plan de la consulta 7.
- MongoDB y PostgreSQL se cruzan por identificadores; no hay una llave foránea entre los dos motores.

### Diapositiva 7.3 — Para mostrar si lo piden

- Regla R6 en el diagrama y en `solicitudes_propiedad`.
- Consulta de inventario, de campañas o de antigüedad sin cierre.
- Plan EXPLAIN de la consulta 7: Seq Scan, y por qué el índice igual se justifica.
- COMMIT de la oferta 16 y rechazo de la oferta 1.
- Colección `seguimiento_eventos` y el conteo por canal.

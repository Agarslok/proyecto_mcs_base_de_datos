# Entregable 6 — Componente MongoDB

**Base documental:** `inmobiliaria_mcs_mongo` (nombre sugerido)  
**Colección:** `seguimiento_eventos`  
**Relacional de referencia:** PostgreSQL `inmobiliaria_mcs` (solo **referencias** por entero, sin duplicar el esquema)

---

## 1. Por qué este fragmento va en NoSQL (y no en PostgreSQL)

En E2 se dejó explícito: el núcleo relacional modela **visitas** como actividad estructurada (R7, R8). En la operación real, el asesor registra además:

- mensajes de **WhatsApp** con texto libre y metadatos variables;
- **llamadas** sin visita presencial;
- **notas internas** con campos opcionales (sentimiento, URL de adjunto, duración).

Eso es **semiestructurado e histórico**: el esquema cambia por canal y el volumen de eventos crece sin alterar `visitas` ni romper 1FN con columnas JSON en Postgres (posible, pero el curso pide un componente documental **separado**).

MongoDB almacena **eventos de seguimiento omnicanal** con documentos flexibles (`contenido`, `metadata`). Cada evento usa el `solicitud_id` de PostgreSQL y el `persona_id` y `propiedad_id` de esa misma solicitud. El canal del evento (WhatsApp, llamada, correo) no es el canal de marketing de la pregunta 6.

**No se replica:** tablas `personas`, `propiedades`, `campanas`, etc. Solo se guardan IDs para cruzar en consultas híbridas (informe o BI futuro).

---

## 2. Diseño del documento

```json
{
  "solicitud_id": 2,
  "persona_id": 24,
  "propiedad_id": 1,
  "canal": "whatsapp",
  "direccion": "entrante",
  "empleado_id": 5,
  "ocurrio_en": { "$date": "2026-03-05T14:30:00Z" },
  "contenido": {
    "resumen": "Pide visita fin de semana",
    "mensaje": "¿Pueden mostrar el apartamento el sábado en la mañana?"
  },
  "metadata": {
    "duracion_seg": null,
    "sentimiento": "positivo",
    "adjuntos": []
  }
}
```

| Campo | Obligatorio | Descripción |
|-------|-------------|-------------|
| `solicitud_id` | sí | FK lógica → `solicitudes_propiedad` |
| `persona_id` | sí | Prospecto |
| `propiedad_id` | sí | Inmueble de la oportunidad |
| `canal` | sí | `whatsapp`, `llamada`, `email`, `nota_interna`, `feria` |
| `direccion` | sí | `entrante` / `saliente` / `interno` |
| `empleado_id` | no | Asesor que registró o atendió |
| `ocurrio_en` | sí | Fecha del hecho |
| `contenido` | sí | Subdocumento variable por canal |
| `metadata` | no | Extensión sin migración de esquema |

---

## 3. Índices

| Índice | Campos | Uso |
|--------|--------|-----|
| `idx_solicitud_fecha` | `{ solicitud_id: 1, ocurrio_en: -1 }` | Timeline de una oportunidad (pregunta 4–5 ampliada) |
| `idx_canal_fecha` | `{ canal: 1, ocurrio_en: -1 }` | Eventos de seguimiento por canal. No es el canal de marketing de la pregunta 6 |

---

## 4. Cómo ejecutar en su máquina

### Opción A — mongosh

```text
mongosh
load("ruta/completa/codigo/mongodb/01_setup_y_carga_f6.js")
load("codigo/mongodb/02_crud_f6.js")
load("codigo/mongodb/03_agregaciones_f6.js")
```

En Windows, desde la carpeta del proyecto:

```text
mongosh --file "codigo\mongodb\01_setup_y_carga_f6.js"
```

### Opción B — MongoDB Compass

1. Crear base `inmobiliaria_mcs_mongo`.  
2. **Import** → `codigo/mongodb/seguimiento_eventos_seed.json` → colección `seguimiento_eventos`.  
3. **Indexes** → crear los dos índices anteriores.  
4. Pestaña **Aggregations** → pegar pipelines de `03_agregaciones_f6.js`.

### Opción C — Entrega sin servidor local

Incluir en el informe: `seguimiento_eventos_seed.json` + scripts como evidencia reproducible; capturas en `documentacion/evidencia/f6_*.png`.

---

## 5. CRUD (archivo `02_crud_f6.js`)

Demuestra **C**reate, **R**ead, **U**pdate, **D**elete sobre la misma colección, con comentarios que referencian `solicitud_id` existentes en PostgreSQL.

---

## 6. Dos agregaciones (archivo `03_agregaciones_f6.js`)

| # | Pregunta de negocio | Pipeline |
|---|---------------------|----------|
| A1 | ¿Qué **canales** concentran más **eventos** de seguimiento? | `$group` por `canal` + `$sort` |
| A2 | ¿Qué **oportunidades** (`solicitud_id`) tienen más interacciones registradas? | `$group` + `$sort` + `$limit` |

Relacionar en el informe con preguntas E1 **4, 5 y 6** (seguimiento y marketing), aclarando que Mongo **complementa** las visitas SQL.

---

## 7. Productos E6

- `codigo/mongodb/seguimiento_eventos_seed.json`
- `codigo/mongodb/01_setup_y_carga_f6.js`
- `codigo/mongodb/02_crud_f6.js`
- `codigo/mongodb/03_agregaciones_f6.js`
- Este documento + actualización de `06_informe_final_base_f6.md`

---

## 8. Evidencia ya tomada (verificada contra el seed)

| Archivo | Qué demuestra |
|---------|----------------|
| `documentacion/evidencia/f6_mongo_compass_coleccion.png` | Base `inmobiliaria_mcs_mongo`, colección `seguimiento_eventos`, **36** documentos; `ocurrio_en` como `ISODate` |
| `documentacion/evidencia/f6_agregacion_canales.png` | A1: whatsapp 14, llamada 7, nota_interna 7, email 6, feria 2 |
| `documentacion/evidencia/f6_agregacion_top_solicitudes.png` | A2: solicitud 2 / propiedad 1 con **3** interacciones; resto del top con 2 |
| `documentacion/evidencia/f6_agregacion_canales_resultado.json` | Mismos totales de A1 (export de la agregación, no de la colección) |
| `documentacion/evidencia/f6_agregacion_top_solicitudes_resultado.json` | Top 10 de A2 |

La carga canónica sigue siendo `codigo/mongodb/seguimiento_eventos_seed.json` más `01_setup_y_carga_f6.js`.
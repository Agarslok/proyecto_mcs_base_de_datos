# Entregable 6 — MongoDB

El seguimiento por WhatsApp, llamada, correo, feria y nota interna no cabe bien en la tabla `visitas`: el texto y los campos cambian según el canal. Por eso lo guardamos en la colección `seguimiento_eventos`, en la base `inmobiliaria_mcs_mongo`. Cada documento apunta a la solicitud de PostgreSQL y no copia nombres ni precios.

## Cómo lo cargamos

1. `scripts/01_setup_y_carga_f6.js` crea la colección, carga 36 eventos y define los índices.
2. `scripts/02_crud_f6.js` inserta, consulta, actualiza y borra un evento de prueba.
3. `scripts/03_agregaciones_f6.js` agrupa por canal y lista las solicitudes con más interacciones.
4. `scripts/seguimiento_eventos_seed.json` es el archivo de datos.

## Archivos

| Archivo | Qué es |
|---------|--------|
| `E6_mongodb_nosql.pdf` | Por qué esta parte va en MongoDB, cómo quedó el documento, los índices y las dos agregaciones. |
| `scripts/` | Carga, CRUD y agregaciones. |
| `evidencia/` | Capturas de Compass y el JSON de cada agregación. |

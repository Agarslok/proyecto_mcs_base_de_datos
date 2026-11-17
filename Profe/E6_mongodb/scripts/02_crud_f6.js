// Fase 6 · 02_crud_f6.js — CRUD sobre seguimiento_eventos
// Requiere 01_setup_y_carga_f6.js ejecutado antes.

const dbName = 'inmobiliaria_mcs_mongo';
const coll = db.getSiblingDB(dbName).seguimiento_eventos;

// CREATE — nuevo evento (solicitud 1, coherente con PG)
const nuevo = {
  solicitud_id: 1,
  persona_id: 23,
  propiedad_id: 1,
  canal: 'whatsapp',
  direccion: 'entrante',
  empleado_id: 4,
  ocurrio_en: new Date(),
  contenido: { mensaje: 'CRUD demo: ¿Todavía puedo visitar este fin de semana?' },
  metadata: { origen: 'crud_f6', sentimiento: 'positivo' },
};
const creado = coll.insertOne(nuevo);
print('CREATE insertOne _id=' + creado.insertedId);

// READ — timeline de una oportunidad
print('READ find solicitud_id=2 (más reciente primero):');
printjson(
  coll
    .find({ solicitud_id: 2 })
    .sort({ ocurrio_en: -1 })
    .limit(3)
    .toArray()
);

// UPDATE — añadir nota a metadata del documento recién creado
const upd = coll.updateOne(
  { _id: creado.insertedId },
  { $set: { 'metadata.actualizado_en': new Date(), 'metadata.revisado': true } }
);
print('UPDATE matched=' + upd.matchedCount + ' modified=' + upd.modifiedCount);

// DELETE — eliminar solo el documento de demostración CRUD
const del = coll.deleteOne({ _id: creado.insertedId });
print('DELETE deletedCount=' + del.deletedCount);

print('Conteo final (debe ser igual que tras carga): ' + coll.countDocuments());
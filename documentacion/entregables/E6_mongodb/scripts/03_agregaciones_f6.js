// Fase 6 · 03_agregaciones_f6.js — dos preguntas de negocio

const coll = db.getSiblingDB('inmobiliaria_mcs_mongo').seguimiento_eventos;

// A1 — ¿Qué canales concentran más eventos de seguimiento?
print('=== Agregación A1: eventos por canal ===');
printjson(
  coll
    .aggregate([
      { $group: { _id: '$canal', total_eventos: { $sum: 1 } } },
      { $sort: { total_eventos: -1 } },
      {
        $project: {
          _id: 0,
          canal: '$_id',
          total_eventos: 1,
        },
      },
    ])
    .toArray()
);

// A2 — ¿Qué oportunidades (solicitud_id) tienen más interacciones?
print('=== Agregación A2: top solicitudes por interacciones ===');
printjson(
  coll
    .aggregate([
      {
        $group: {
          _id: { solicitud_id: '$solicitud_id', propiedad_id: '$propiedad_id' },
          interacciones: { $sum: 1 },
          canales_distintos: { $addToSet: '$canal' },
        },
      },
      {
        $project: {
          _id: 0,
          solicitud_id: '$_id.solicitud_id',
          propiedad_id: '$_id.propiedad_id',
          interacciones: 1,
          n_canales: { $size: '$canales_distintos' },
          canales: '$canales_distintos',
        },
      },
      { $sort: { interacciones: -1, solicitud_id: 1 } },
      { $limit: 10 },
    ])
    .toArray()
);

// Extra — eventos últimos 60 días por canal (muestra índice idx_canal_fecha)
const desde = new Date();
desde.setDate(desde.getDate() - 60);
print('=== Extra: eventos por canal (últimos 60 días) ===');
printjson(
  coll
    .aggregate([
      { $match: { ocurrio_en: { $gte: desde } } },
      { $group: { _id: '$canal', total: { $sum: 1 } } },
      { $sort: { total: -1 } },
    ])
    .toArray()
);
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

// Extra — mismos eventos del seed (marzo y abril de 2026), no "últimos 60 días"
// desde hoy: esas fechas ya quedaron fuera de esa ventana.
print('=== Extra: eventos por canal en el periodo del seed (desde 2026-03-01) ===');
printjson(
  coll
    .aggregate([
      { $match: { ocurrio_en: { $gte: new Date('2026-03-01T00:00:00Z') } } },
      { $group: { _id: '$canal', total: { $sum: 1 } } },
      { $sort: { total: -1, _id: 1 } },
    ])
    .toArray()
);
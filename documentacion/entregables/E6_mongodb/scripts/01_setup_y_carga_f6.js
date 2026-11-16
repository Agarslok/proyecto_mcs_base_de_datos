// Fase 6 · 01_setup_y_carga_f6.js
// Desde la raíz del repo:
//   mongosh --file "codigo/mongodb/01_setup_y_carga_f6.js"
// Si falla la ruta, importe seguimiento_eventos_seed.json con Compass.

const fs = require('fs');
const path = require('path');

const dbName = 'inmobiliaria_mcs_mongo';
const collName = 'seguimiento_eventos';

const candidates = [
  path.join('codigo', 'mongodb', 'seguimiento_eventos_seed.json'),
  path.join(__dirname || '.', 'seguimiento_eventos_seed.json'),
];

let seedPath = null;
for (const p of candidates) {
  if (fs.existsSync(p)) {
    seedPath = p;
    break;
  }
}

if (!seedPath) {
  print('ERROR: no se encuentra seguimiento_eventos_seed.json');
  print('Rutas probadas: ' + candidates.join(', '));
  quit(1);
}

const conn = db.getSiblingDB(dbName);
const coll = conn.getCollection(collName);

coll.drop();

const docs = JSON.parse(fs.readFileSync(seedPath, 'utf8')).map((d) => ({
  ...d,
  ocurrio_en: new Date(d.ocurrio_en),
}));

const ins = coll.insertMany(docs);
print('Insertados: ' + ins.insertedCount + ' documentos en ' + dbName + '.' + collName);
print('Seed: ' + seedPath);

coll.createIndex({ solicitud_id: 1, ocurrio_en: -1 }, { name: 'idx_solicitud_fecha' });
coll.createIndex({ canal: 1, ocurrio_en: -1 }, { name: 'idx_canal_fecha' });

print('Índices:');
printjson(coll.getIndexes());
print('Total documentos: ' + coll.countDocuments());
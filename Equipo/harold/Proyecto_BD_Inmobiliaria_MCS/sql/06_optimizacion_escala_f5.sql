-- =============================================================================
-- Fase 5 · 06_optimizacion_escala_f5.sql
-- Validación de la hipótesis de 04_optimizacion_f5.sql a escala de producción.
--
-- Con la carga del curso (~50-90 filas por tabla) todas las consultas tardan
-- menos de 0,5 ms y el planificador prefiere Seq Scan: no se puede saber si un
-- índice sirve. Este script construye, en un esquema aparte (escala), una copia
-- ampliada del pipeline comercial (100.000 propiedades, 125.000 solicitudes,
-- 170.000 visitas, 117.000 ofertas), mide las consultas ANTES y DESPUÉS de los
-- índices candidatos y deja en la base solo los índices que demostraron utilidad.
--
-- Ejecutar sobre inmobiliaria_mcs después de 01-05. Tarda menos de un minuto.
-- El esquema escala se elimina al final: no altera los datos del proyecto.
-- =============================================================================
SET client_encoding = 'UTF8';
SELECT setseed(0.42);                       -- datos reproducibles

DROP SCHEMA IF EXISTS escala CASCADE;
CREATE SCHEMA escala;

-- -----------------------------------------------------------------------------
-- A. Copia ampliada (misma estructura de columnas usada por las consultas)
-- -----------------------------------------------------------------------------
CREATE TABLE escala.ciudades AS SELECT ciudad_id, nombre FROM public.ciudades;
ALTER TABLE escala.ciudades ADD PRIMARY KEY (ciudad_id);

CREATE TABLE escala.propiedades AS
SELECT g AS propiedad_id,
       'Propiedad ' || g AS titulo,
       (SELECT min(ciudad_id) FROM public.ciudades) + (g % (SELECT count(*) FROM public.ciudades))::int AS ciudad_id,
       (ARRAY['disponible','disponible','disponible','en_negociacion','vendida','no_disponible'])[1 + (g % 6)] AS estado_comercial,
       timestamp '2025-01-01' + (g % 600) * interval '1 day' AS creado_en
FROM generate_series(1, 100000) g;
ALTER TABLE escala.propiedades ADD PRIMARY KEY (propiedad_id);

CREATE TABLE escala.publicaciones AS
SELECT g AS publicacion_id,
       1 + floor(random() * 100000)::int AS propiedad_id,
       date '2025-01-01' + floor(random() * 650)::int AS fecha_publicacion,
       random() < 0.8 AS publicada
FROM generate_series(1, 115000) g;
ALTER TABLE escala.publicaciones ADD PRIMARY KEY (publicacion_id);

CREATE TABLE escala.solicitudes_propiedad AS
SELECT g AS solicitud_id,
       1 + floor(random() * 100000)::int AS propiedad_id,
       CASE WHEN random() < 0.7 THEN 1 + floor(random() * 12)::int END AS campana_id,
       (ARRAY['nueva','en_seguimiento','en_seguimiento','en_negociacion','ganada','perdida','descartada'])[1 + floor(random() * 7)::int] AS estado
FROM generate_series(1, 125000) g;
ALTER TABLE escala.solicitudes_propiedad ADD PRIMARY KEY (solicitud_id);

CREATE TABLE escala.visitas AS
SELECT g AS visita_id, 1 + floor(random() * 125000)::int AS solicitud_id
FROM generate_series(1, 170000) g;
ALTER TABLE escala.visitas ADD PRIMARY KEY (visita_id);

CREATE TABLE escala.ofertas AS
SELECT g AS oferta_id, 1 + floor(random() * 125000)::int AS solicitud_id,
       (ARRAY['pendiente','aceptada','rechazada','caducada'])[1 + floor(random() * 4)::int] AS estado_oferta
FROM generate_series(1, 117000) g;
ALTER TABLE escala.ofertas ADD PRIMARY KEY (oferta_id);

CREATE TABLE escala.transacciones AS
SELECT row_number() OVER ()::int AS transaccion_id, oferta_id,
       CASE WHEN random() < 0.05 THEN 'anulada' ELSE 'cerrada' END AS estado
FROM escala.ofertas WHERE estado_oferta = 'aceptada';
ALTER TABLE escala.transacciones ADD PRIMARY KEY (transaccion_id);
ALTER TABLE escala.transacciones ADD CONSTRAINT uq_esc_transacciones_oferta UNIQUE (oferta_id);   -- igual que en public

ANALYZE escala.ciudades, escala.propiedades, escala.publicaciones, escala.solicitudes_propiedad,
        escala.visitas, escala.ofertas, escala.transacciones;

SELECT 'propiedades' AS tabla, count(*) FROM escala.propiedades
UNION ALL SELECT 'publicaciones', count(*) FROM escala.publicaciones
UNION ALL SELECT 'solicitudes_propiedad', count(*) FROM escala.solicitudes_propiedad
UNION ALL SELECT 'visitas', count(*) FROM escala.visitas
UNION ALL SELECT 'ofertas', count(*) FROM escala.ofertas
UNION ALL SELECT 'transacciones', count(*) FROM escala.transacciones;

SET search_path = escala, public;

-- -----------------------------------------------------------------------------
-- B. ANTES de los índices
-- -----------------------------------------------------------------------------
-- === E1 ANTES · Ficha de una propiedad (preguntas 2, 5 y 8 para un inmueble) ===
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.solicitud_id, s.estado,
       (SELECT count(*) FROM visitas v WHERE v.solicitud_id = s.solicitud_id) AS visitas,
       (SELECT count(*) FROM ofertas o WHERE o.solicitud_id = s.solicitud_id) AS ofertas
FROM solicitudes_propiedad s
WHERE s.propiedad_id = 4264;

-- === E2 ANTES · Pipeline activo de una propiedad (preguntas 3 y 4) ===
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.solicitud_id, s.estado
FROM solicitudes_propiedad s
WHERE s.propiedad_id = 4264 AND s.estado IN ('nueva','en_seguimiento','en_negociacion');

-- === E3 ANTES · Consulta 7 completa (métricas de todas las propiedades) ===
EXPLAIN (ANALYZE, BUFFERS)
WITH metricas AS (
    SELECT p.propiedad_id, p.titulo,
           COUNT(DISTINCT s.solicitud_id) AS n_prospectos,
           COUNT(DISTINCT v.visita_id)    AS n_visitas,
           COUNT(DISTINCT o.oferta_id)    AS n_ofertas
    FROM propiedades p
    LEFT JOIN solicitudes_propiedad s ON s.propiedad_id = p.propiedad_id
    LEFT JOIN visitas v               ON v.solicitud_id = s.solicitud_id
    LEFT JOIN ofertas o               ON o.solicitud_id = s.solicitud_id
    GROUP BY p.propiedad_id, p.titulo
)
SELECT * FROM metricas WHERE n_prospectos > 0
ORDER BY n_prospectos DESC, n_visitas DESC, n_ofertas DESC;

-- === E3b ANTES · Consulta 7 REESCRITA (agrega cada tabla por separado) ===
-- Hipótesis: la consulta original une visitas Y ofertas de la misma solicitud;
-- el JOIN multiplica filas (visitas x ofertas) y COUNT(DISTINCT) las vuelve a
-- deduplicar. Agregando cada tabla por separado se evita esa explosión. Devuelve
-- exactamente las mismas filas (verificado: 52 de 52 en public y todas en escala).
EXPLAIN (ANALYZE, BUFFERS)
WITH sol AS (SELECT propiedad_id, COUNT(*) AS n_prospectos FROM solicitudes_propiedad GROUP BY propiedad_id),
vis AS (SELECT s.propiedad_id, COUNT(*) AS n_visitas
        FROM visitas v JOIN solicitudes_propiedad s ON s.solicitud_id = v.solicitud_id GROUP BY s.propiedad_id),
ofe AS (SELECT s.propiedad_id, COUNT(*) AS n_ofertas
        FROM ofertas o JOIN solicitudes_propiedad s ON s.solicitud_id = o.solicitud_id GROUP BY s.propiedad_id)
SELECT p.propiedad_id, p.titulo, sol.n_prospectos,
       COALESCE(vis.n_visitas, 0) AS n_visitas, COALESCE(ofe.n_ofertas, 0) AS n_ofertas
FROM propiedades p
JOIN sol      ON sol.propiedad_id = p.propiedad_id
LEFT JOIN vis ON vis.propiedad_id = p.propiedad_id
LEFT JOIN ofe ON ofe.propiedad_id = p.propiedad_id
ORDER BY n_prospectos DESC, n_visitas DESC, n_ofertas DESC;

-- === E4 ANTES · Consulta 9 reescrita (NOT EXISTS, versión oficial) ===
EXPLAIN (ANALYZE, BUFFERS)
WITH cerradas AS (
    SELECT DISTINCT s.propiedad_id
    FROM solicitudes_propiedad s
    JOIN ofertas o       ON o.solicitud_id = s.solicitud_id
    JOIN transacciones t ON t.oferta_id = o.oferta_id
    WHERE t.estado <> 'anulada'
), inicio_comercial AS (
    SELECT p.propiedad_id, p.titulo, p.estado_comercial, c.nombre AS ciudad,
           COALESCE(MIN(pub.fecha_publicacion) FILTER (WHERE pub.publicada), p.creado_en::date) AS fecha_inicio
    FROM propiedades p
    JOIN ciudades c ON c.ciudad_id = p.ciudad_id
    LEFT JOIN publicaciones pub ON pub.propiedad_id = p.propiedad_id
    WHERE NOT EXISTS (SELECT 1 FROM cerradas x WHERE x.propiedad_id = p.propiedad_id)
    GROUP BY p.propiedad_id, p.titulo, p.estado_comercial, c.nombre, p.creado_en
)
SELECT propiedad_id, titulo, ciudad, estado_comercial, fecha_inicio,
       CURRENT_DATE - fecha_inicio AS dias_en_comercializacion,
       RANK() OVER (ORDER BY CURRENT_DATE - fecha_inicio DESC) AS ranking_antiguedad
FROM inicio_comercial
ORDER BY dias_en_comercializacion DESC, propiedad_id
LIMIT 20;

-- -----------------------------------------------------------------------------
-- C. Los 8 índices candidatos de 04_optimizacion_f5.sql (mismas definiciones)
-- -----------------------------------------------------------------------------
CREATE INDEX idx_sol_propiedad_id ON solicitudes_propiedad (propiedad_id);
CREATE INDEX idx_sol_campana_id ON solicitudes_propiedad (campana_id) WHERE campana_id IS NOT NULL;
CREATE INDEX idx_sol_estado_activo ON solicitudes_propiedad (propiedad_id, estado)
    WHERE estado IN ('nueva', 'en_seguimiento', 'en_negociacion');
CREATE INDEX idx_visitas_solicitud_id ON visitas (solicitud_id);
CREATE INDEX idx_ofertas_solicitud_id ON ofertas (solicitud_id);
CREATE INDEX idx_ofertas_estado ON ofertas (solicitud_id, estado_oferta);
CREATE INDEX idx_transacciones_oferta_id ON transacciones (oferta_id);
CREATE INDEX idx_publicaciones_propiedad_pub ON publicaciones (propiedad_id, fecha_publicacion) WHERE publicada = TRUE;
ANALYZE escala.solicitudes_propiedad, escala.visitas, escala.ofertas, escala.transacciones, escala.publicaciones;
SELECT pg_stat_reset();                     -- para contar qué índices usa cada consulta

-- -----------------------------------------------------------------------------
-- D. DESPUÉS de los índices (mismas consultas)
-- -----------------------------------------------------------------------------
-- === E1 DESPUÉS ===
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.solicitud_id, s.estado,
       (SELECT count(*) FROM visitas v WHERE v.solicitud_id = s.solicitud_id) AS visitas,
       (SELECT count(*) FROM ofertas o WHERE o.solicitud_id = s.solicitud_id) AS ofertas
FROM solicitudes_propiedad s
WHERE s.propiedad_id = 4264;

-- === E2 DESPUÉS ===
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.solicitud_id, s.estado
FROM solicitudes_propiedad s
WHERE s.propiedad_id = 4264 AND s.estado IN ('nueva','en_seguimiento','en_negociacion');

-- === E3 DESPUÉS ===
EXPLAIN (ANALYZE, BUFFERS)
WITH metricas AS (
    SELECT p.propiedad_id, p.titulo,
           COUNT(DISTINCT s.solicitud_id) AS n_prospectos,
           COUNT(DISTINCT v.visita_id)    AS n_visitas,
           COUNT(DISTINCT o.oferta_id)    AS n_ofertas
    FROM propiedades p
    LEFT JOIN solicitudes_propiedad s ON s.propiedad_id = p.propiedad_id
    LEFT JOIN visitas v               ON v.solicitud_id = s.solicitud_id
    LEFT JOIN ofertas o               ON o.solicitud_id = s.solicitud_id
    GROUP BY p.propiedad_id, p.titulo
)
SELECT * FROM metricas WHERE n_prospectos > 0
ORDER BY n_prospectos DESC, n_visitas DESC, n_ofertas DESC;

-- === E3b DESPUÉS · Consulta 7 REESCRITA (agrega cada tabla por separado) ===
-- Hipótesis: la consulta original une visitas Y ofertas de la misma solicitud;
-- el JOIN multiplica filas (visitas x ofertas) y COUNT(DISTINCT) las vuelve a
-- deduplicar. Agregando cada tabla por separado se evita esa explosión. Devuelve
-- exactamente las mismas filas (verificado: 52 de 52 en public y todas en escala).
EXPLAIN (ANALYZE, BUFFERS)
WITH sol AS (SELECT propiedad_id, COUNT(*) AS n_prospectos FROM solicitudes_propiedad GROUP BY propiedad_id),
vis AS (SELECT s.propiedad_id, COUNT(*) AS n_visitas
        FROM visitas v JOIN solicitudes_propiedad s ON s.solicitud_id = v.solicitud_id GROUP BY s.propiedad_id),
ofe AS (SELECT s.propiedad_id, COUNT(*) AS n_ofertas
        FROM ofertas o JOIN solicitudes_propiedad s ON s.solicitud_id = o.solicitud_id GROUP BY s.propiedad_id)
SELECT p.propiedad_id, p.titulo, sol.n_prospectos,
       COALESCE(vis.n_visitas, 0) AS n_visitas, COALESCE(ofe.n_ofertas, 0) AS n_ofertas
FROM propiedades p
JOIN sol      ON sol.propiedad_id = p.propiedad_id
LEFT JOIN vis ON vis.propiedad_id = p.propiedad_id
LEFT JOIN ofe ON ofe.propiedad_id = p.propiedad_id
ORDER BY n_prospectos DESC, n_visitas DESC, n_ofertas DESC;

-- === E4 DESPUÉS ===
EXPLAIN (ANALYZE, BUFFERS)
WITH cerradas AS (
    SELECT DISTINCT s.propiedad_id
    FROM solicitudes_propiedad s
    JOIN ofertas o       ON o.solicitud_id = s.solicitud_id
    JOIN transacciones t ON t.oferta_id = o.oferta_id
    WHERE t.estado <> 'anulada'
), inicio_comercial AS (
    SELECT p.propiedad_id, p.titulo, p.estado_comercial, c.nombre AS ciudad,
           COALESCE(MIN(pub.fecha_publicacion) FILTER (WHERE pub.publicada), p.creado_en::date) AS fecha_inicio
    FROM propiedades p
    JOIN ciudades c ON c.ciudad_id = p.ciudad_id
    LEFT JOIN publicaciones pub ON pub.propiedad_id = p.propiedad_id
    WHERE NOT EXISTS (SELECT 1 FROM cerradas x WHERE x.propiedad_id = p.propiedad_id)
    GROUP BY p.propiedad_id, p.titulo, p.estado_comercial, c.nombre, p.creado_en
)
SELECT propiedad_id, titulo, ciudad, estado_comercial, fecha_inicio,
       CURRENT_DATE - fecha_inicio AS dias_en_comercializacion,
       RANK() OVER (ORDER BY CURRENT_DATE - fecha_inicio DESC) AS ranking_antiguedad
FROM inicio_comercial
ORDER BY dias_en_comercializacion DESC, propiedad_id
LIMIT 20;

-- -----------------------------------------------------------------------------
-- E. ¿Qué índices usó el planificador en las 4 consultas?
-- -----------------------------------------------------------------------------
SELECT indexrelname AS indice, idx_scan AS veces_usado,
       pg_size_pretty(pg_relation_size(indexrelid)) AS tamano
FROM pg_stat_user_indexes
WHERE schemaname = 'escala' AND indexrelname LIKE 'idx_%'
ORDER BY idx_scan DESC, indexrelname;

-- -----------------------------------------------------------------------------
-- F. Decisión sobre la base del proyecto (public), con base en la evidencia
--    (ver informe, sección 11.1, y evidencia/f5_optimizacion_escala.txt):
--    · La consulta 7 se reemplaza por su versión reescrita (E3b) en 03_consultas_f4.sql.
--    · Se conservan los índices que el planificador usa y que reducen el tiempo:
--      idx_sol_propiedad_id, idx_visitas_solicitud_id, idx_ofertas_solicitud_id.
--    · Se eliminan los redundantes o sin uso demostrado:
--      idx_transacciones_oferta_id  duplica el índice de uq_transacciones_oferta (UNIQUE ya indexa oferta_id);
--      idx_ofertas_estado           comparte la columna inicial con idx_ofertas_solicitud_id y no se usó;
--      idx_sol_estado_activo        no mejora frente a idx_sol_propiedad_id (pocas filas por propiedad);
--      idx_sol_campana_id           ninguna consulta del portafolio filtra por campaña con alta selectividad;
--      idx_publicaciones_propiedad_pub  la consulta 9 lee todas las publicaciones (agregación completa).
-- -----------------------------------------------------------------------------
DROP INDEX IF EXISTS public.idx_transacciones_oferta_id;
DROP INDEX IF EXISTS public.idx_ofertas_estado;
DROP INDEX IF EXISTS public.idx_sol_estado_activo;
DROP INDEX IF EXISTS public.idx_sol_campana_id;
DROP INDEX IF EXISTS public.idx_publicaciones_propiedad_pub;
CREATE INDEX IF NOT EXISTS idx_sol_propiedad_id     ON public.solicitudes_propiedad (propiedad_id);
CREATE INDEX IF NOT EXISTS idx_visitas_solicitud_id ON public.visitas (solicitud_id);
CREATE INDEX IF NOT EXISTS idx_ofertas_solicitud_id ON public.ofertas (solicitud_id);

RESET search_path;
DROP SCHEMA escala CASCADE;

SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

	-- =============================================================================
-- Fase 5 · 04_optimizacion_f5.sql
-- Optimización: EXPLAIN ANALYZE antes/después + índices justificados.
-- Ejecutar en pgAdmin sobre inmobiliaria_mcs (después de 01–03).
--
-- Consultas elegidas (relevantes para el negocio):
--   · Pregunta 7 — métricas por propiedad (CTE + 3 LEFT JOIN + agregación).
--   · Pregunta 9 — antigüedad sin cierre (CTE + NOT IN + ventana RANK).
--
-- Copie cada plan (árbol + tiempos) al informe en
-- documentacion/05_optimizacion_transacciones_f5.md
-- =============================================================================

SET client_encoding = 'UTF8';
SET TIME ZONE 'America/Bogota';

-- -----------------------------------------------------------------------------
-- A. Línea base (sin índices adicionales de esta fase)
-- Los FK de PostgreSQL no crean índice en la tabla hija por defecto;
-- las consultas 7 y 9 unen muchas veces por propiedad_id / solicitud_id.
-- -----------------------------------------------------------------------------

-- === A1. EXPLAIN ANALYZE · Consulta 7 · ANTES (copiar salida al informe f5) ===

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT TEXT)
WITH metricas AS (
    SELECT
        p.propiedad_id,
        p.titulo,
        COUNT(DISTINCT s.solicitud_id) AS n_prospectos,
        COUNT(DISTINCT v.visita_id)    AS n_visitas,
        COUNT(DISTINCT o.oferta_id)    AS n_ofertas
    FROM propiedades p
    LEFT JOIN solicitudes_propiedad s ON s.propiedad_id = p.propiedad_id
    LEFT JOIN visitas v               ON v.solicitud_id = s.solicitud_id
    LEFT JOIN ofertas o               ON o.solicitud_id = s.solicitud_id
    GROUP BY p.propiedad_id, p.titulo
)
SELECT *
FROM metricas
WHERE n_prospectos > 0
ORDER BY n_prospectos DESC, n_visitas DESC, n_ofertas DESC;

-- === A2. EXPLAIN ANALYZE · Consulta 9 · ANTES ===

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT TEXT)
WITH inicio_comercial AS (
    SELECT
        p.propiedad_id,
        p.titulo,
        p.estado_comercial,
        c.nombre AS ciudad,
        COALESCE(MIN(pub.fecha_publicacion), p.creado_en::date) AS fecha_inicio
    FROM propiedades p
    JOIN ciudades c ON c.ciudad_id = p.ciudad_id
    LEFT JOIN publicaciones pub ON pub.propiedad_id = p.propiedad_id
    WHERE p.propiedad_id NOT IN (
        SELECT s.propiedad_id
        FROM solicitudes_propiedad s
        JOIN ofertas o       ON o.solicitud_id = s.solicitud_id
        JOIN transacciones t ON t.oferta_id = o.oferta_id
        WHERE t.estado <> 'anulada'
    )
    GROUP BY p.propiedad_id, p.titulo, p.estado_comercial, c.nombre, p.creado_en
)
SELECT
    propiedad_id,
    titulo,
    ciudad,
    estado_comercial,
    fecha_inicio,
    CURRENT_DATE - fecha_inicio AS dias_en_comercializacion,
    RANK() OVER (ORDER BY CURRENT_DATE - fecha_inicio DESC) AS ranking_antiguedad
FROM inicio_comercial
ORDER BY dias_en_comercializacion DESC, propiedad_id;

-- -----------------------------------------------------------------------------
-- B. Hipótesis → índices (justificación en documentacion/05_..._f5.md)
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_sol_propiedad_id
    ON solicitudes_propiedad (propiedad_id);

CREATE INDEX IF NOT EXISTS idx_sol_campana_id
    ON solicitudes_propiedad (campana_id)
    WHERE campana_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sol_estado_activo
    ON solicitudes_propiedad (propiedad_id, estado)
    WHERE estado IN ('nueva', 'en_seguimiento', 'en_negociacion');

CREATE INDEX IF NOT EXISTS idx_visitas_solicitud_id
    ON visitas (solicitud_id);

CREATE INDEX IF NOT EXISTS idx_ofertas_solicitud_id
    ON ofertas (solicitud_id);

CREATE INDEX IF NOT EXISTS idx_ofertas_estado
    ON ofertas (solicitud_id, estado_oferta);

CREATE INDEX IF NOT EXISTS idx_transacciones_oferta_id
    ON transacciones (oferta_id);

CREATE INDEX IF NOT EXISTS idx_publicaciones_propiedad_pub
    ON publicaciones (propiedad_id, fecha_publicacion)
    WHERE publicada = TRUE;

-- Estadísticas del planificador (obligatorio tras crear índices)
ANALYZE propiedades;
ANALYZE solicitudes_propiedad;
ANALYZE visitas;
ANALYZE ofertas;
ANALYZE transacciones;
ANALYZE publicaciones;

-- === B. Índices creados y ANALYZE ejecutado ===

-- -----------------------------------------------------------------------------
-- C. Misma consulta después de índices
-- -----------------------------------------------------------------------------

-- === C1. EXPLAIN ANALYZE · Consulta 7 · DESPUÉS ===

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT TEXT)
WITH metricas AS (
    SELECT
        p.propiedad_id,
        p.titulo,
        COUNT(DISTINCT s.solicitud_id) AS n_prospectos,
        COUNT(DISTINCT v.visita_id)    AS n_visitas,
        COUNT(DISTINCT o.oferta_id)    AS n_ofertas
    FROM propiedades p
    LEFT JOIN solicitudes_propiedad s ON s.propiedad_id = p.propiedad_id
    LEFT JOIN visitas v               ON v.solicitud_id = s.solicitud_id
    LEFT JOIN ofertas o               ON o.solicitud_id = s.solicitud_id
    GROUP BY p.propiedad_id, p.titulo
)
SELECT *
FROM metricas
WHERE n_prospectos > 0
ORDER BY n_prospectos DESC, n_visitas DESC, n_ofertas DESC;

-- === C2. EXPLAIN ANALYZE · Consulta 9 · DESPUÉS (índices) ===

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT TEXT)
WITH inicio_comercial AS (
    SELECT
        p.propiedad_id,
        p.titulo,
        p.estado_comercial,
        c.nombre AS ciudad,
        COALESCE(MIN(pub.fecha_publicacion), p.creado_en::date) AS fecha_inicio
    FROM propiedades p
    JOIN ciudades c ON c.ciudad_id = p.ciudad_id
    LEFT JOIN publicaciones pub ON pub.propiedad_id = p.propiedad_id
    WHERE p.propiedad_id NOT IN (
        SELECT s.propiedad_id
        FROM solicitudes_propiedad s
        JOIN ofertas o       ON o.solicitud_id = s.solicitud_id
        JOIN transacciones t ON t.oferta_id = o.oferta_id
        WHERE t.estado <> 'anulada'
    )
    GROUP BY p.propiedad_id, p.titulo, p.estado_comercial, c.nombre, p.creado_en
)
SELECT
    propiedad_id,
    titulo,
    ciudad,
    estado_comercial,
    fecha_inicio,
    CURRENT_DATE - fecha_inicio AS dias_en_comercializacion,
    RANK() OVER (ORDER BY CURRENT_DATE - fecha_inicio DESC) AS ranking_antiguedad
FROM inicio_comercial
ORDER BY dias_en_comercializacion DESC, propiedad_id;

-- -----------------------------------------------------------------------------
-- D. Reescritura semántica de la consulta 9 (anti-join en lugar de NOT IN)
-- Útil ante crecimiento del volumen: NOT IN + subconsulta correlacionada
-- a menudo favorece Hash Anti Join con índices en la cadena oferta→transacción.
-- -----------------------------------------------------------------------------

-- === D. EXPLAIN ANALYZE · Consulta 9 REESCRITA (NOT EXISTS) · DESPUÉS ===

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT TEXT)
WITH cerradas AS (
    SELECT DISTINCT s.propiedad_id
    FROM solicitudes_propiedad s
    JOIN ofertas o       ON o.solicitud_id = s.solicitud_id
    JOIN transacciones t ON t.oferta_id = o.oferta_id
    WHERE t.estado <> 'anulada'
),
inicio_comercial AS (
    SELECT
        p.propiedad_id,
        p.titulo,
        p.estado_comercial,
        c.nombre AS ciudad,
        COALESCE(MIN(pub.fecha_publicacion) FILTER (WHERE pub.publicada), p.creado_en::date) AS fecha_inicio
    FROM propiedades p
    JOIN ciudades c ON c.ciudad_id = p.ciudad_id
    LEFT JOIN publicaciones pub ON pub.propiedad_id = p.propiedad_id
    WHERE NOT EXISTS (
        SELECT 1 FROM cerradas x WHERE x.propiedad_id = p.propiedad_id
    )
    GROUP BY p.propiedad_id, p.titulo, p.estado_comercial, c.nombre, p.creado_en
)
SELECT
    propiedad_id,
    titulo,
    ciudad,
    estado_comercial,
    fecha_inicio,
    CURRENT_DATE - fecha_inicio AS dias_en_comercializacion,
    RANK() OVER (ORDER BY CURRENT_DATE - fecha_inicio DESC) AS ranking_antiguedad
FROM inicio_comercial
ORDER BY dias_en_comercializacion DESC, propiedad_id;

-- -----------------------------------------------------------------------------
-- E. Inventario de índices del proyecto (verificación)
-- -----------------------------------------------------------------------------
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;
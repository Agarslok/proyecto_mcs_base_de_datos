-- =============================================================================
-- Fase 4 · 03_consultas_f4.sql
-- Vistas, función/trigger de dominio y las 10 consultas del Entregable 1.
-- Ejecutar conectado a inmobiliaria_mcs, DESPUÉS de 01 y 02.
--
-- Rúbrica cubierta:
--   JOIN de varias tablas, GROUP BY + HAVING, subconsulta, CTE,
--   vistas reutilizables, función, trigger, función de ventana.
-- La función y los triggers ya existen en 01_ddl_f4.sql; aquí se
-- recrean para que este script contenga los objetos exigidos.
-- =============================================================================

SET client_encoding = 'UTF8';
SET TIME ZONE 'America/Bogota';

-- -----------------------------------------------------------------------------
-- Vistas reutilizables
-- -----------------------------------------------------------------------------

-- Pregunta 1: inventario con precio vigente (publicada = TRUE).
CREATE OR REPLACE VIEW v_inventario_disponible AS
SELECT
    p.propiedad_id,
    p.matricula_inmobiliaria,
    p.titulo,
    p.estado_comercial,
    c.nombre AS ciudad,
    p.direccion,
    ti.nombre AS tipo_inmueble,
    top.nombre AS tipo_operacion,
    pub.precio,
    pub.valor_administracion,
    pub.fecha_publicacion,
    e.nombre AS asesor_captacion
FROM propiedades p
JOIN ciudades c              ON c.ciudad_id = p.ciudad_id
JOIN tipos_inmueble ti       ON ti.tipo_inmueble_id = p.tipo_inmueble_id
JOIN empleados e             ON e.empleado_id = p.responsable_id
JOIN publicaciones pub       ON pub.propiedad_id = p.propiedad_id
                            AND pub.publicada = TRUE
JOIN tipos_operacion top     ON top.tipo_operacion_id = pub.tipo_operacion_id
WHERE p.estado_comercial = 'disponible';

-- Pipeline que aún no cerró ni se perdió.
CREATE OR REPLACE VIEW v_pipeline_activo AS
SELECT
    s.solicitud_id,
    s.estado,
    s.creado_en,
    pe.nombres || ' ' || pe.apellidos AS prospecto,
    pe.email,
    p.propiedad_id,
    p.titulo,
    p.estado_comercial,
    ca.nombre_campana,
    cm.nombre AS canal
FROM solicitudes_propiedad s
JOIN personas pe             ON pe.persona_id = s.persona_id
JOIN propiedades p           ON p.propiedad_id = s.propiedad_id
LEFT JOIN campanas ca        ON ca.campana_id = s.campana_id
LEFT JOIN canales_marketing cm ON cm.canal_id = ca.canal_id
WHERE s.estado IN ('nueva', 'en_seguimiento', 'en_negociacion');

-- Pregunta 10: resultado económico de cierres (comisión generada, R16).
CREATE OR REPLACE VIEW v_resultado_cierres AS
SELECT
    t.transaccion_id,
    t.estado AS estado_contrato,
    t.valor_final,
    t.comision_porcentaje,
    t.comision_valor,
    t.fecha_inicio_contrato,
    t.fecha_fin_contrato,
    p.propiedad_id,
    p.titulo,
    p.estado_comercial,
    c.nombre AS ciudad,
    pe.nombres || ' ' || pe.apellidos AS prospecto,
    emp.nombre AS asesor_cierre
FROM transacciones t
JOIN ofertas o               ON o.oferta_id = t.oferta_id
JOIN solicitudes_propiedad s ON s.solicitud_id = o.solicitud_id
JOIN propiedades p           ON p.propiedad_id = s.propiedad_id
JOIN ciudades c              ON c.ciudad_id = p.ciudad_id
JOIN personas pe             ON pe.persona_id = s.persona_id
JOIN empleados emp           ON emp.empleado_id = t.empleado_id;

-- -----------------------------------------------------------------------------
-- Función de dominio (R12) — idéntica a 01_ddl_f4.sql
-- Uso: SELECT registrar_cierre(oferta_id, empleado_id, valor, %, inicio, fin);
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION registrar_cierre(
    p_oferta_id           integer,
    p_empleado_id         integer,
    p_valor_final         numeric,
    p_comision_porcentaje numeric,
    p_fecha_inicio        date,
    p_fecha_fin           date DEFAULT NULL,
    p_estado              varchar DEFAULT 'cerrada'
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_id integer;
BEGIN
    INSERT INTO transacciones (
        oferta_id, empleado_id, valor_final, comision_porcentaje,
        fecha_inicio_contrato, fecha_fin_contrato, estado
    ) VALUES (
        p_oferta_id, p_empleado_id, p_valor_final, p_comision_porcentaje,
        p_fecha_inicio, p_fecha_fin, p_estado
    )
    RETURNING transaccion_id INTO v_id;

    RETURN v_id;
END;
$$;

-- Trigger de dominio (R12): no cerrar si la oferta no está aceptada;
-- al insertar, marca solicitud ganada y actualiza estado_comercial (R11).
CREATE OR REPLACE FUNCTION fn_validar_y_aplicar_transaccion()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_oferta text;
    v_solicitud_id  integer;
    v_propiedad_id  integer;
    v_tipo          text;
BEGIN
    SELECT o.estado_oferta, o.solicitud_id, s.propiedad_id
      INTO v_estado_oferta, v_solicitud_id, v_propiedad_id
      FROM ofertas o
      JOIN solicitudes_propiedad s ON s.solicitud_id = o.solicitud_id
     WHERE o.oferta_id = NEW.oferta_id;

    IF v_estado_oferta IS DISTINCT FROM 'aceptada' THEN
        RAISE EXCEPTION
            'R12: la transacción exige oferta aceptada (oferta_id=%, estado=%)',
            NEW.oferta_id, v_estado_oferta;
    END IF;

    UPDATE solicitudes_propiedad
       SET estado = 'ganada',
           fecha_cierre = COALESCE(fecha_cierre, now())
     WHERE solicitud_id = v_solicitud_id;

    SELECT t.nombre
      INTO v_tipo
      FROM publicaciones pub
      JOIN tipos_operacion t ON t.tipo_operacion_id = pub.tipo_operacion_id
     WHERE pub.propiedad_id = v_propiedad_id
     ORDER BY CASE WHEN t.nombre = 'venta' THEN 0 ELSE 1 END,
              pub.fecha_publicacion DESC
     LIMIT 1;

    IF v_tipo = 'venta' THEN
        UPDATE propiedades
           SET estado_comercial = 'vendida'
         WHERE propiedad_id = v_propiedad_id;
    ELSE
        UPDATE propiedades
           SET estado_comercial = 'no_disponible'
         WHERE propiedad_id = v_propiedad_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_y_aplicar_transaccion ON transacciones;
CREATE TRIGGER trg_validar_y_aplicar_transaccion
    BEFORE INSERT ON transacciones
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_y_aplicar_transaccion();

-- =============================================================================
-- 10 consultas ↔ preguntas del Entregable 1
-- En pgAdmin: Execute (F5) deja un grid por SELECT. Para defender una
-- pregunta, seleccione solo ese bloque y ejecútelo.
-- =============================================================================

-- Pregunta 1. Propiedades disponibles, precio, ubicación y estado.
-- Técnica: vista + JOIN de 6 tablas. Precio vigente = publicada TRUE.
SELECT *
FROM v_inventario_disponible
ORDER BY ciudad, precio;

-- Pregunta 2. Prospectos que han mostrado interés en cada propiedad.
-- Técnica: JOIN solicitudes + personas + propiedades (R5, R6).
SELECT
    p.propiedad_id,
    p.titulo,
    pe.persona_id,
    pe.nombres || ' ' || pe.apellidos AS prospecto,
    pe.email,
    pe.telefono,
    s.solicitud_id,
    s.estado AS estado_oportunidad,
    s.creado_en
FROM propiedades p
JOIN solicitudes_propiedad s ON s.propiedad_id = p.propiedad_id
JOIN personas pe             ON pe.persona_id = s.persona_id
ORDER BY p.propiedad_id, s.creado_en;

-- Pregunta 3. Propiedades con más oportunidades comerciales ACTIVAS.
-- Técnica: GROUP BY + HAVING.
SELECT
    p.propiedad_id,
    p.titulo,
    p.estado_comercial,
    c.nombre AS ciudad,
    COUNT(*) AS oportunidades_activas
FROM propiedades p
JOIN ciudades c              ON c.ciudad_id = p.ciudad_id
JOIN solicitudes_propiedad s ON s.propiedad_id = p.propiedad_id
WHERE s.estado IN ('nueva', 'en_seguimiento', 'en_negociacion')
GROUP BY p.propiedad_id, p.titulo, p.estado_comercial, c.nombre
HAVING COUNT(*) >= 2
ORDER BY oportunidades_activas DESC, p.propiedad_id;

-- Pregunta 4. Estado de seguimiento de cada prospecto interesado.
-- Técnica: JOIN + filtro de estado (vista de pipeline).
SELECT
    prospecto,
    email,
    titulo AS propiedad,
    estado AS estado_seguimiento,
    nombre_campana,
    canal,
    creado_en
FROM v_pipeline_activo
ORDER BY estado, creado_en;

-- Pregunta 5. Actividades de seguimiento / visitas por oportunidad.
-- Técnica: JOIN visitas → solicitud → persona/propiedad (R7, R8).
SELECT
    s.solicitud_id,
    pe.nombres || ' ' || pe.apellidos AS prospecto,
    p.titulo AS propiedad,
    s.estado AS estado_oportunidad,
    v.visita_id,
    emp.nombre AS asesor_visita,
    v.fecha_programada,
    v.fecha_realizada,
    v.duracion_min,
    v.calificacion_interes,
    v.feedback_cliente,
    v.motivo_cancelacion
FROM visitas v
JOIN solicitudes_propiedad s ON s.solicitud_id = v.solicitud_id
JOIN personas pe             ON pe.persona_id = s.persona_id
JOIN propiedades p           ON p.propiedad_id = s.propiedad_id
JOIN empleados emp           ON emp.empleado_id = v.empleado_id
ORDER BY s.solicitud_id, v.fecha_programada;

-- Pregunta 6. Campañas y canales que más prospectos / oportunidades generan.
-- Técnica: GROUP BY campaña y canal. campana_id NULL (R10) queda fuera:
--         no hay campaña que atribuir.
SELECT
    ca.campana_id,
    ca.nombre_campana,
    ca.estado AS estado_campana,
    cm.nombre AS canal,
    COUNT(s.solicitud_id) AS oportunidades,
    COUNT(DISTINCT s.persona_id) AS prospectos_distintos
FROM campanas ca
JOIN canales_marketing cm    ON cm.canal_id = ca.canal_id
JOIN solicitudes_propiedad s ON s.campana_id = ca.campana_id
GROUP BY ca.campana_id, ca.nombre_campana, ca.estado, cm.nombre
ORDER BY oportunidades DESC, prospectos_distintos DESC;

-- Pregunta 7. Propiedades con más prospectos, visitas y negociaciones.
-- Técnica: CTE + agregaciones.
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

-- Pregunta 8. Oportunidades que llegaron a negociación o cierre vs las que no.
-- Técnica: LEFT JOIN + subconsulta de cierre.
SELECT
    s.solicitud_id,
    pe.nombres || ' ' || pe.apellidos AS prospecto,
    p.titulo AS propiedad,
    s.estado,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM ofertas o
            JOIN transacciones t ON t.oferta_id = o.oferta_id
            WHERE o.solicitud_id = s.solicitud_id
        ) THEN 'cierre'
        WHEN EXISTS (
            SELECT 1
            FROM ofertas o
            WHERE o.solicitud_id = s.solicitud_id
        ) THEN 'negociacion_sin_cierre'
        ELSE 'sin_oferta'
    END AS avance,
    COUNT(o.oferta_id) AS n_ofertas
FROM solicitudes_propiedad s
JOIN personas pe  ON pe.persona_id = s.persona_id
JOIN propiedades p ON p.propiedad_id = s.propiedad_id
LEFT JOIN ofertas o ON o.solicitud_id = s.solicitud_id
GROUP BY s.solicitud_id, pe.nombres, pe.apellidos, p.titulo, s.estado
ORDER BY avance, s.solicitud_id;

-- Pregunta 9. Propiedades más tiempo en comercialización SIN cierre.
-- Técnica: CTE + función de ventana RANK (rúbrica SQL).
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

-- Pregunta 10. Resultado comercial y económico de propiedades vendidas / cerradas.
-- Técnica: vista sobre transacción (comision_valor generado, R16).
SELECT
    transaccion_id,
    titulo,
    ciudad,
    estado_comercial,
    prospecto,
    asesor_cierre,
    valor_final,
    comision_porcentaje,
    comision_valor,
    fecha_inicio_contrato,
    fecha_fin_contrato,
    estado_contrato
FROM v_resultado_cierres
ORDER BY valor_final DESC;

-- -----------------------------------------------------------------------------
-- Verificación rápida de cardinalidades (no es pregunta E1)
-- -----------------------------------------------------------------------------
SELECT 'personas' AS tabla, COUNT(*) FROM personas
UNION ALL SELECT 'propiedades', COUNT(*) FROM propiedades
UNION ALL SELECT 'publicaciones', COUNT(*) FROM publicaciones
UNION ALL SELECT 'solicitudes_propiedad', COUNT(*) FROM solicitudes_propiedad
UNION ALL SELECT 'visitas', COUNT(*) FROM visitas
UNION ALL SELECT 'ofertas', COUNT(*) FROM ofertas
UNION ALL SELECT 'transacciones', COUNT(*) FROM transacciones
ORDER BY 1;

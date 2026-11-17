-- =============================================================================
-- Fase 5 · 05_transacciones_f5.sql
-- Transacciones, ACID y concurrencia sobre el cierre comercial (R11, R12).
-- Ejecutar en pgAdmin sobre inmobiliaria_mcs.
--
-- Recomendación: correr cada bloque por separado (seleccionar + F5).
-- El bloque E requiere DOS Query Tools abiertos (dos sesiones).
-- =============================================================================

SET client_encoding = 'UTF8';
SET TIME ZONE 'America/Bogota';

-- -----------------------------------------------------------------------------
-- 1. Nivel de aislamiento por defecto del motor
-- -----------------------------------------------------------------------------
SHOW transaction_isolation;

-- -----------------------------------------------------------------------------
-- 2. Operación atómica de cierre (R12) con COMMIT explícito
--    Paso A: localizar una oferta ACEPTADA que aún NO tenga transacción.
-- -----------------------------------------------------------------------------

SELECT
    o.oferta_id,
    o.solicitud_id,
    o.estado_oferta,
    o.valor_ofertado,
    s.propiedad_id,
    p.titulo,
    p.estado_comercial AS estado_propiedad_antes
FROM ofertas o
JOIN solicitudes_propiedad s ON s.solicitud_id = o.solicitud_id
JOIN propiedades p           ON p.propiedad_id = s.propiedad_id
LEFT JOIN transacciones t    ON t.oferta_id = o.oferta_id
WHERE o.estado_oferta = 'aceptada'
  AND t.transaccion_id IS NULL
ORDER BY o.oferta_id
LIMIT 5;

-- Si la lista está vacía, la carga ya cerró todas las aceptadas: use una
-- oferta en 'pendiente', acéptela y re-ejecute el SELECT anterior:
--
--   BEGIN;
--   UPDATE ofertas SET estado_oferta = 'aceptada' WHERE oferta_id = <id_pendiente>;
--   COMMIT;
--
-- Reemplace <oferta_id> y <empleado_id> en el bloque siguiente.

-- Paso B: transacción explícita (todo o nada)
-- La oferta 61 está aceptada y su propiedad (22) todavía no tiene cierre.


BEGIN;

SELECT registrar_cierre(
    p_oferta_id           => 61,          -- aceptada, propiedad 22, sin cierre previo
    p_empleado_id         => 4,
    p_valor_final         => 1038000000,
    p_comision_porcentaje => 3.5,
    p_fecha_inicio        => CURRENT_DATE,
    p_fecha_fin           => NULL,
    p_estado              => 'cerrada'
) AS nueva_transaccion_id;

SELECT p.propiedad_id, p.titulo, p.estado_comercial, s.estado AS estado_solicitud
FROM ofertas o
JOIN solicitudes_propiedad s ON s.solicitud_id = o.solicitud_id
JOIN propiedades p           ON p.propiedad_id = s.propiedad_id
WHERE o.oferta_id = 61;

COMMIT;


-- -----------------------------------------------------------------------------
-- 3. Evidencia de ROLLBACK (Atomicidad + consistencia)
--    Intentar cerrar una oferta NO aceptada debe fallar y no persistir nada.
-- -----------------------------------------------------------------------------

DO $$
DECLARE
    v_oferta integer;
    v_err text;
BEGIN
  SELECT o.oferta_id
    INTO v_oferta
    FROM ofertas o
    WHERE o.estado_oferta <> 'aceptada'
    LIMIT 1;

  IF v_oferta IS NULL THEN
    RAISE NOTICE 'No hay oferta no aceptada para la demo.';
    RETURN;
  END IF;

  BEGIN
    PERFORM registrar_cierre(
        v_oferta, 4, 100000, 3.0, CURRENT_DATE, NULL, 'cerrada'
    );
    RAISE EXCEPTION 'Debió fallar y no llegó aquí';
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      IF v_err NOT LIKE 'R12:%' THEN
        RAISE;
      END IF;
      RAISE NOTICE 'ROLLBACK implícito OK: %', v_err;
  END;

  IF NOT EXISTS (SELECT 1 FROM transacciones WHERE oferta_id = v_oferta) THEN
    RAISE NOTICE 'Atomicidad: no quedó fila en transacciones para oferta %', v_oferta;
  ELSE
    RAISE EXCEPTION 'ERROR: quedó transacción huérfana';
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. Función transaccional con bloqueo de fila (concurrencia en cierre)
--    Evita que dos sesiones cierren dos ofertas distintas sobre la misma
--    propiedad en venta, dejando estado_comercial incoherente.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cerrar_venta_con_bloqueo(
    p_oferta_id           integer,
    p_empleado_id         integer,
    p_valor_final         numeric,
    p_comision_porcentaje numeric,
    p_fecha_inicio        date,
    p_fecha_fin           date DEFAULT NULL,
    p_estado_contrato     varchar DEFAULT 'cerrada'
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_propiedad_id integer;
    v_tx_id        integer;
BEGIN
    SELECT s.propiedad_id
      INTO v_propiedad_id
      FROM ofertas o
      JOIN solicitudes_propiedad s ON s.solicitud_id = o.solicitud_id
     WHERE o.oferta_id = p_oferta_id
     FOR UPDATE OF s;

    IF v_propiedad_id IS NULL THEN
        RAISE EXCEPTION 'Oferta % no existe', p_oferta_id;
    END IF;

    PERFORM 1 FROM propiedades WHERE propiedad_id = v_propiedad_id FOR UPDATE;

    IF EXISTS (
        SELECT 1 FROM propiedades
        WHERE propiedad_id = v_propiedad_id
          AND estado_comercial = 'vendida'
    ) OR EXISTS (
        SELECT 1
        FROM transacciones t
        JOIN ofertas o ON o.oferta_id = t.oferta_id
        JOIN solicitudes_propiedad s ON s.solicitud_id = o.solicitud_id
        WHERE s.propiedad_id = v_propiedad_id
          AND t.estado <> 'anulada'
    ) THEN
        RAISE EXCEPTION
            'R12: la propiedad % ya tiene un cierre vigente', v_propiedad_id;
    END IF;

    SELECT registrar_cierre(
        p_oferta_id, p_empleado_id, p_valor_final, p_comision_porcentaje,
        p_fecha_inicio, p_fecha_fin, p_estado_contrato
    ) INTO v_tx_id;

    RETURN v_tx_id;
END;
$$;

COMMENT ON FUNCTION cerrar_venta_con_bloqueo IS
    'R12: serializa cierres sobre la misma propiedad con FOR UPDATE (fase 5).';

-- -----------------------------------------------------------------------------
-- 5. Escenario de concurrencia (documentar en sustentación)
--
-- Sesión A                          | Sesión B
-- ----------------------------------|----------------------------------
-- BEGIN;                            | BEGIN;
-- SELECT ... FOR UPDATE propiedad 1 | SELECT ... FOR UPDATE propiedad 1
-- (adquiere lock)                    | (espera)
-- registrar_cierre(...); COMMIT;    | (prosigue tras COMMIT de A)
--
-- Anomalía sin bloqueo: dos COMMIT con dos transacciones sobre ofertas
-- distintas de la misma propiedad en venta → último trigger gana en
-- estado_comercial; riesgo de decisión contradictoria (no perdida de filas,
-- pero decisión de negocio ambigua).
--
-- Nivel de aislamiento recomendado: READ COMMITTED (default en PostgreSQL)
-- para la operación OLTP de cierre + bloqueo explícito en propiedad.
-- Para reportes pesados (consultas 7/9) en paralelo: READ COMMITTED basta;
-- si se exige snapshot estable de conteos, usar REPEATABLE READ en esa sesión.
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- 6. Mapa ACID ↔ implementación MCS
-- -----------------------------------------------------------------------------

/*
| Propiedad | Cómo se evidencia en inmobiliaria_mcs |
|-----------|----------------------------------------|
| Atomicidad | BEGIN … registrar_cierre / triggers … COMMIT; fallo → ROLLBACK sin fila parcial |
| Consistencia | CHECK, FK, triggers R6/R11/R12, comision_valor GENERATED |
| Aislamiento | READ COMMITTED + FOR UPDATE en cerrar_venta_con_bloqueo |
| Durabilidad | COMMIT persiste en WAL (motor PostgreSQL) |
*/

-- Consulta de control: propiedades vendidas deben tener transacción asociada
SELECT
    p.propiedad_id,
    p.titulo,
    p.estado_comercial,
    COUNT(DISTINCT t.transaccion_id) AS cierres
FROM propiedades p
JOIN solicitudes_propiedad s ON s.propiedad_id = p.propiedad_id
JOIN ofertas o               ON o.solicitud_id = s.solicitud_id
JOIN transacciones t         ON t.oferta_id = o.oferta_id
WHERE p.estado_comercial IN ('vendida', 'no_disponible')
GROUP BY p.propiedad_id, p.titulo, p.estado_comercial
ORDER BY p.propiedad_id;
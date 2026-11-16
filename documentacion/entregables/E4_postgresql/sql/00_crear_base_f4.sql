-- =============================================================================
-- Fase 4 · 00_crear_base_f4.sql
-- Crear la base inmobiliaria_mcs (una sola vez).
--
-- En pgAdmin 4:
--   1. Conectarse al servidor.
--   2. Query Tool SOBRE la base "postgres" (mantenimiento), no sobre inmobiliaria_mcs.
--   3. Ejecutar este script.
--   4. Refrescar Databases y abrir Query Tool sobre inmobiliaria_mcs
--      para correr 01_ddl_f4.sql, 02_carga_f4.sql y 03_consultas_f4.sql.
--
-- Si la base ya existe, este CREATE falla: es correcto, continúe con 01.
-- =============================================================================

CREATE DATABASE inmobiliaria_mcs
    WITH
    ENCODING = 'UTF8'
    TEMPLATE = template0;

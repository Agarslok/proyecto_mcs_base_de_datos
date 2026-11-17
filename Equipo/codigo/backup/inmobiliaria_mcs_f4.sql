--
-- PostgreSQL database dump
--

\restrict qZiw7Bu6C0lGHbQqtfF06ts40lOAbA0mIeVfAhvpiCtJgvkRiEmcDICbZt9NsBg

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

-- Started on 2026-11-17 15:11:21

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 286 (class 1255 OID 20013)
-- Name: cerrar_venta_con_bloqueo(integer, integer, numeric, numeric, date, date, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cerrar_venta_con_bloqueo(p_oferta_id integer, p_empleado_id integer, p_valor_final numeric, p_comision_porcentaje numeric, p_fecha_inicio date, p_fecha_fin date DEFAULT NULL::date, p_estado_contrato character varying DEFAULT 'cerrada'::character varying) RETURNS integer
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


ALTER FUNCTION public.cerrar_venta_con_bloqueo(p_oferta_id integer, p_empleado_id integer, p_valor_final numeric, p_comision_porcentaje numeric, p_fecha_inicio date, p_fecha_fin date, p_estado_contrato character varying) OWNER TO postgres;

--
-- TOC entry 5360 (class 0 OID 0)
-- Dependencies: 286
-- Name: FUNCTION cerrar_venta_con_bloqueo(p_oferta_id integer, p_empleado_id integer, p_valor_final numeric, p_comision_porcentaje numeric, p_fecha_inicio date, p_fecha_fin date, p_estado_contrato character varying); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.cerrar_venta_con_bloqueo(p_oferta_id integer, p_empleado_id integer, p_valor_final numeric, p_comision_porcentaje numeric, p_fecha_inicio date, p_fecha_fin date, p_estado_contrato character varying) IS 'R12: serializa cierres sobre la misma propiedad con FOR UPDATE (fase 5).';


--
-- TOC entry 269 (class 1255 OID 19489)
-- Name: fn_oferta_aceptada_en_negociacion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_oferta_aceptada_en_negociacion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_propiedad_id integer;
BEGIN
    IF NEW.estado_oferta = 'aceptada'
       AND (TG_OP = 'INSERT' OR OLD.estado_oferta IS DISTINCT FROM 'aceptada') THEN
        SELECT s.propiedad_id
          INTO v_propiedad_id
          FROM solicitudes_propiedad s
         WHERE s.solicitud_id = NEW.solicitud_id;

        UPDATE propiedades
           SET estado_comercial = 'en_negociacion'
         WHERE propiedad_id = v_propiedad_id
           AND estado_comercial = 'disponible';

        UPDATE solicitudes_propiedad
           SET estado = 'en_negociacion'
         WHERE solicitud_id = NEW.solicitud_id
           AND estado IN ('nueva', 'en_seguimiento');
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_oferta_aceptada_en_negociacion() OWNER TO postgres;

--
-- TOC entry 270 (class 1255 OID 19490)
-- Name: fn_set_actualizado_en(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_set_actualizado_en() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.actualizado_en := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_set_actualizado_en() OWNER TO postgres;

--
-- TOC entry 271 (class 1255 OID 19491)
-- Name: fn_solicitud_motivo_descarte(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_solicitud_motivo_descarte() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.estado = 'descartada'
       AND (NEW.motivo_descarte IS NULL OR btrim(NEW.motivo_descarte) = '') THEN
        RAISE EXCEPTION
            'La solicitud % está descartada: motivo_descarte es obligatorio',
            COALESCE(NEW.solicitud_id::text, 'nueva');
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_solicitud_motivo_descarte() OWNER TO postgres;

--
-- TOC entry 272 (class 1255 OID 19492)
-- Name: fn_solicitud_no_es_dueno(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_solicitud_no_es_dueno() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM propiedad_propietarios pp
        WHERE pp.persona_id = NEW.persona_id
          AND pp.propiedad_id = NEW.propiedad_id
    ) THEN
        RAISE EXCEPTION
            'R2/R6: persona_id=% es propietario de propiedad_id=%; no puede ser prospecto de la misma',
            NEW.persona_id, NEW.propiedad_id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_solicitud_no_es_dueno() OWNER TO postgres;

--
-- TOC entry 284 (class 1255 OID 19493)
-- Name: fn_validar_y_aplicar_transaccion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_validar_y_aplicar_transaccion() RETURNS trigger
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


ALTER FUNCTION public.fn_validar_y_aplicar_transaccion() OWNER TO postgres;

--
-- TOC entry 285 (class 1255 OID 19494)
-- Name: registrar_cierre(integer, integer, numeric, numeric, date, date, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.registrar_cierre(p_oferta_id integer, p_empleado_id integer, p_valor_final numeric, p_comision_porcentaje numeric, p_fecha_inicio date, p_fecha_fin date DEFAULT NULL::date, p_estado character varying DEFAULT 'cerrada'::character varying) RETURNS integer
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


ALTER FUNCTION public.registrar_cierre(p_oferta_id integer, p_empleado_id integer, p_valor_final numeric, p_comision_porcentaje numeric, p_fecha_inicio date, p_fecha_fin date, p_estado character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 219 (class 1259 OID 19495)
-- Name: acceso_via; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.acceso_via (
    acceso_via_id integer NOT NULL,
    nombre character varying(40) NOT NULL
);


ALTER TABLE public.acceso_via OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 19500)
-- Name: acceso_via_acceso_via_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.acceso_via ALTER COLUMN acceso_via_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.acceso_via_acceso_via_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 221 (class 1259 OID 19501)
-- Name: campana_propiedades; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.campana_propiedades (
    campana_propiedad_id integer NOT NULL,
    campana_id integer NOT NULL,
    propiedad_id integer NOT NULL
);


ALTER TABLE public.campana_propiedades OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 19507)
-- Name: campana_propiedades_campana_propiedad_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.campana_propiedades ALTER COLUMN campana_propiedad_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.campana_propiedades_campana_propiedad_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 223 (class 1259 OID 19508)
-- Name: campanas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.campanas (
    campana_id integer NOT NULL,
    canal_id integer NOT NULL,
    nombre_campana character varying(150) NOT NULL,
    presupuesto_planeado numeric(14,2) NOT NULL,
    presupuesto_invertido numeric(14,2),
    fecha_inicio date NOT NULL,
    fecha_fin date NOT NULL,
    estado character varying(20) NOT NULL,
    CONSTRAINT ck_campanas_estado CHECK (((estado)::text = ANY (ARRAY[('planificada'::character varying)::text, ('activa'::character varying)::text, ('cerrada'::character varying)::text]))),
    CONSTRAINT ck_campanas_fechas CHECK ((fecha_fin >= fecha_inicio)),
    CONSTRAINT ck_campanas_presup_inv CHECK (((presupuesto_invertido IS NULL) OR (presupuesto_invertido >= (0)::numeric))),
    CONSTRAINT ck_campanas_presup_plan CHECK ((presupuesto_planeado >= (0)::numeric))
);


ALTER TABLE public.campanas OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 19522)
-- Name: campanas_campana_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.campanas ALTER COLUMN campana_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.campanas_campana_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 225 (class 1259 OID 19523)
-- Name: canales_marketing; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.canales_marketing (
    canal_id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


ALTER TABLE public.canales_marketing OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 19530)
-- Name: canales_marketing_canal_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.canales_marketing ALTER COLUMN canal_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.canales_marketing_canal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 227 (class 1259 OID 19531)
-- Name: ciudades; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ciudades (
    ciudad_id integer NOT NULL,
    nombre character varying(100) NOT NULL
);


ALTER TABLE public.ciudades OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 19536)
-- Name: ciudades_ciudad_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.ciudades ALTER COLUMN ciudad_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.ciudades_ciudad_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 229 (class 1259 OID 19537)
-- Name: detalle_construcciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalle_construcciones (
    detalle_construccion_id integer NOT NULL,
    propiedad_id integer NOT NULL,
    estado_conservacion_id integer NOT NULL,
    area_construida_m2 numeric(10,2) NOT NULL,
    habitaciones integer NOT NULL,
    banos integer NOT NULL,
    parqueaderos integer NOT NULL,
    pisos_totales integer NOT NULL,
    piso_ubicacion integer NOT NULL,
    anio_construccion integer NOT NULL,
    amoblado boolean DEFAULT false NOT NULL,
    ascensor boolean DEFAULT false NOT NULL,
    deposito boolean DEFAULT false NOT NULL,
    CONSTRAINT ck_dc_anio CHECK (((anio_construccion >= 1800) AND (anio_construccion <= 2100))),
    CONSTRAINT ck_dc_area CHECK ((area_construida_m2 > (0)::numeric)),
    CONSTRAINT ck_dc_banos CHECK ((banos >= 0)),
    CONSTRAINT ck_dc_habitaciones CHECK ((habitaciones >= 0)),
    CONSTRAINT ck_dc_parqueaderos CHECK ((parqueaderos >= 0)),
    CONSTRAINT ck_dc_piso_ub CHECK ((piso_ubicacion >= 0)),
    CONSTRAINT ck_dc_pisos CHECK ((pisos_totales >= 1))
);


ALTER TABLE public.detalle_construcciones OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 19563)
-- Name: detalle_construcciones_detalle_construccion_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.detalle_construcciones ALTER COLUMN detalle_construccion_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.detalle_construcciones_detalle_construccion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 231 (class 1259 OID 19564)
-- Name: detalle_terrenos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalle_terrenos (
    detalle_terreno_id integer NOT NULL,
    propiedad_id integer NOT NULL,
    uso_suelo_id integer NOT NULL,
    acceso_via_id integer NOT NULL,
    frente_m numeric(8,2) NOT NULL,
    fondo_m numeric(8,2) NOT NULL,
    topografia character varying(20) NOT NULL,
    zona character varying(10) NOT NULL,
    es_esquinero boolean DEFAULT false NOT NULL,
    CONSTRAINT ck_dt_fondo CHECK ((fondo_m > (0)::numeric)),
    CONSTRAINT ck_dt_frente CHECK ((frente_m > (0)::numeric)),
    CONSTRAINT ck_dt_topografia CHECK (((topografia)::text = ANY (ARRAY[('plana'::character varying)::text, ('inclinada'::character varying)::text]))),
    CONSTRAINT ck_dt_zona CHECK (((zona)::text = ANY (ARRAY[('urbana'::character varying)::text, ('rural'::character varying)::text])))
);


ALTER TABLE public.detalle_terrenos OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 19581)
-- Name: detalle_terrenos_detalle_terreno_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.detalle_terrenos ALTER COLUMN detalle_terreno_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.detalle_terrenos_detalle_terreno_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 233 (class 1259 OID 19582)
-- Name: empleados; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.empleados (
    empleado_id integer NOT NULL,
    rol_id integer NOT NULL,
    nombre character varying(150) NOT NULL,
    email character varying(150) NOT NULL,
    telefono character varying(30),
    fecha_ingreso date NOT NULL
);


ALTER TABLE public.empleados OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 19590)
-- Name: empleados_empleado_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.empleados ALTER COLUMN empleado_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.empleados_empleado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 235 (class 1259 OID 19591)
-- Name: estado_conservacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estado_conservacion (
    estado_conservacion_id integer NOT NULL,
    nombre character varying(40) NOT NULL
);


ALTER TABLE public.estado_conservacion OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 19596)
-- Name: estado_conservacion_estado_conservacion_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.estado_conservacion ALTER COLUMN estado_conservacion_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.estado_conservacion_estado_conservacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 237 (class 1259 OID 19597)
-- Name: ofertas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ofertas (
    oferta_id integer NOT NULL,
    solicitud_id integer NOT NULL,
    estado_oferta character varying(20) DEFAULT 'pendiente'::character varying NOT NULL,
    valor_ofertado numeric(14,2) NOT NULL,
    fecha_oferta timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_ofertas_estado CHECK (((estado_oferta)::text = ANY (ARRAY[('pendiente'::character varying)::text, ('aceptada'::character varying)::text, ('rechazada'::character varying)::text, ('caducada'::character varying)::text]))),
    CONSTRAINT ck_ofertas_valor CHECK ((valor_ofertado > (0)::numeric))
);


ALTER TABLE public.ofertas OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 19609)
-- Name: ofertas_oferta_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.ofertas ALTER COLUMN oferta_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.ofertas_oferta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 239 (class 1259 OID 19610)
-- Name: persona_roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.persona_roles (
    persona_id integer NOT NULL,
    tipo_persona_id integer NOT NULL
);


ALTER TABLE public.persona_roles OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 19615)
-- Name: personas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.personas (
    persona_id integer NOT NULL,
    nombres character varying(100) NOT NULL,
    apellidos character varying(100) NOT NULL,
    telefono character varying(30),
    email character varying(150) NOT NULL,
    ciudad_id integer NOT NULL
);


ALTER TABLE public.personas OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 19623)
-- Name: personas_persona_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.personas ALTER COLUMN persona_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.personas_persona_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 242 (class 1259 OID 19624)
-- Name: propiedad_propietarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.propiedad_propietarios (
    propiedad_propietario_id integer NOT NULL,
    persona_id integer NOT NULL,
    propiedad_id integer NOT NULL
);


ALTER TABLE public.propiedad_propietarios OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 19630)
-- Name: propiedad_propietarios_propiedad_propietario_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.propiedad_propietarios ALTER COLUMN propiedad_propietario_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.propiedad_propietarios_propiedad_propietario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 244 (class 1259 OID 19631)
-- Name: propiedades; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.propiedades (
    propiedad_id integer NOT NULL,
    tipo_inmueble_id integer NOT NULL,
    ciudad_id integer NOT NULL,
    responsable_id integer NOT NULL,
    matricula_inmobiliaria character varying(50) NOT NULL,
    titulo character varying(200) NOT NULL,
    descripcion text,
    direccion character varying(150) NOT NULL,
    area_total_m2 numeric(10,2) NOT NULL,
    estado_comercial character varying(20) DEFAULT 'disponible'::character varying NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_propiedades_area CHECK ((area_total_m2 > (0)::numeric)),
    CONSTRAINT ck_propiedades_estado CHECK (((estado_comercial)::text = ANY (ARRAY[('disponible'::character varying)::text, ('en_negociacion'::character varying)::text, ('vendida'::character varying)::text, ('no_disponible'::character varying)::text])))
);


ALTER TABLE public.propiedades OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 19652)
-- Name: propiedades_propiedad_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.propiedades ALTER COLUMN propiedad_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.propiedades_propiedad_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 246 (class 1259 OID 19653)
-- Name: publicacion_canales; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.publicacion_canales (
    publicacion_canal_id integer NOT NULL,
    canal_id integer NOT NULL,
    publicacion_id integer NOT NULL
);


ALTER TABLE public.publicacion_canales OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 19659)
-- Name: publicacion_canales_publicacion_canal_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.publicacion_canales ALTER COLUMN publicacion_canal_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.publicacion_canales_publicacion_canal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 248 (class 1259 OID 19660)
-- Name: publicaciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.publicaciones (
    publicacion_id integer NOT NULL,
    propiedad_id integer NOT NULL,
    tipo_operacion_id integer NOT NULL,
    precio numeric(14,2) NOT NULL,
    valor_administracion numeric(14,2),
    publicada boolean DEFAULT true NOT NULL,
    fecha_publicacion date NOT NULL,
    fecha_retiro date,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_publicaciones_admin CHECK (((valor_administracion IS NULL) OR (valor_administracion >= (0)::numeric))),
    CONSTRAINT ck_publicaciones_fechas CHECK (((fecha_retiro IS NULL) OR (fecha_retiro >= fecha_publicacion))),
    CONSTRAINT ck_publicaciones_precio CHECK ((precio > (0)::numeric))
);


ALTER TABLE public.publicaciones OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 19677)
-- Name: publicaciones_publicacion_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.publicaciones ALTER COLUMN publicacion_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.publicaciones_publicacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 250 (class 1259 OID 19678)
-- Name: rol_empleado; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rol_empleado (
    rol_id integer NOT NULL,
    nombre_rol character varying(30) NOT NULL
);


ALTER TABLE public.rol_empleado OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 19683)
-- Name: rol_empleado_rol_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.rol_empleado ALTER COLUMN rol_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.rol_empleado_rol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 252 (class 1259 OID 19684)
-- Name: solicitudes_propiedad; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.solicitudes_propiedad (
    solicitud_id integer NOT NULL,
    persona_id integer NOT NULL,
    propiedad_id integer NOT NULL,
    empleado_id integer,
    campana_id integer,
    estado character varying(20) DEFAULT 'nueva'::character varying NOT NULL,
    motivo_descarte character varying(200),
    presupuesto_cliente numeric(14,2) NOT NULL,
    requiere_financiacion boolean DEFAULT false NOT NULL,
    fecha_cierre timestamp with time zone,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_solicitudes_estado CHECK (((estado)::text = ANY (ARRAY[('nueva'::character varying)::text, ('en_seguimiento'::character varying)::text, ('en_negociacion'::character varying)::text, ('ganada'::character varying)::text, ('perdida'::character varying)::text, ('descartada'::character varying)::text]))),
    CONSTRAINT ck_solicitudes_presupuesto CHECK ((presupuesto_cliente > (0)::numeric))
);


ALTER TABLE public.solicitudes_propiedad OWNER TO postgres;

--
-- TOC entry 5361 (class 0 OID 0)
-- Dependencies: 252
-- Name: TABLE solicitudes_propiedad; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.solicitudes_propiedad IS 'Oportunidad comercial: prospecto + propiedad (R6). No usa propiedad_propietarios.';


--
-- TOC entry 5362 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN solicitudes_propiedad.campana_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.solicitudes_propiedad.campana_id IS 'R10: NULL si el origen no es una campaña.';


--
-- TOC entry 253 (class 1259 OID 19701)
-- Name: solicitudes_propiedad_solicitud_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.solicitudes_propiedad ALTER COLUMN solicitud_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.solicitudes_propiedad_solicitud_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 254 (class 1259 OID 19702)
-- Name: tipos_inmueble; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipos_inmueble (
    tipo_inmueble_id integer NOT NULL,
    nombre character varying(40) NOT NULL
);


ALTER TABLE public.tipos_inmueble OWNER TO postgres;

--
-- TOC entry 255 (class 1259 OID 19707)
-- Name: tipos_inmueble_tipo_inmueble_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.tipos_inmueble ALTER COLUMN tipo_inmueble_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tipos_inmueble_tipo_inmueble_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 256 (class 1259 OID 19708)
-- Name: tipos_operacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipos_operacion (
    tipo_operacion_id integer NOT NULL,
    nombre character varying(20) NOT NULL
);


ALTER TABLE public.tipos_operacion OWNER TO postgres;

--
-- TOC entry 257 (class 1259 OID 19713)
-- Name: tipos_operacion_tipo_operacion_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.tipos_operacion ALTER COLUMN tipo_operacion_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tipos_operacion_tipo_operacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 258 (class 1259 OID 19714)
-- Name: tipos_persona; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipos_persona (
    tipo_persona_id integer NOT NULL,
    nombre character varying(20) NOT NULL
);


ALTER TABLE public.tipos_persona OWNER TO postgres;

--
-- TOC entry 259 (class 1259 OID 19719)
-- Name: tipos_persona_tipo_persona_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.tipos_persona ALTER COLUMN tipo_persona_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tipos_persona_tipo_persona_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 260 (class 1259 OID 19720)
-- Name: transacciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transacciones (
    transaccion_id integer NOT NULL,
    oferta_id integer NOT NULL,
    empleado_id integer NOT NULL,
    valor_final numeric(14,2) NOT NULL,
    comision_porcentaje numeric(5,2) NOT NULL,
    comision_valor numeric(14,2) GENERATED ALWAYS AS (round(((valor_final * comision_porcentaje) / (100)::numeric), 2)) STORED,
    fecha_inicio_contrato date NOT NULL,
    fecha_fin_contrato date,
    estado character varying(15) NOT NULL,
    CONSTRAINT ck_transacciones_comision CHECK (((comision_porcentaje >= (0)::numeric) AND (comision_porcentaje <= (100)::numeric))),
    CONSTRAINT ck_transacciones_estado CHECK (((estado)::text = ANY (ARRAY[('activa'::character varying)::text, ('cerrada'::character varying)::text, ('anulada'::character varying)::text]))),
    CONSTRAINT ck_transacciones_fechas CHECK (((fecha_fin_contrato IS NULL) OR (fecha_fin_contrato >= fecha_inicio_contrato))),
    CONSTRAINT ck_transacciones_valor CHECK ((valor_final > (0)::numeric))
);


ALTER TABLE public.transacciones OWNER TO postgres;

--
-- TOC entry 5363 (class 0 OID 0)
-- Dependencies: 260
-- Name: COLUMN transacciones.comision_valor; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.transacciones.comision_valor IS 'R16: derivado GENERATED ALWAYS. No se digita.';


--
-- TOC entry 261 (class 1259 OID 19735)
-- Name: transacciones_transaccion_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.transacciones ALTER COLUMN transaccion_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.transacciones_transaccion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 262 (class 1259 OID 19736)
-- Name: uso_suelo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.uso_suelo (
    uso_suelo_id integer NOT NULL,
    nombre character varying(40) NOT NULL
);


ALTER TABLE public.uso_suelo OWNER TO postgres;

--
-- TOC entry 263 (class 1259 OID 19741)
-- Name: uso_suelo_uso_suelo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.uso_suelo ALTER COLUMN uso_suelo_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.uso_suelo_uso_suelo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 264 (class 1259 OID 19742)
-- Name: v_inventario_disponible; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_inventario_disponible AS
 SELECT p.propiedad_id,
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
   FROM (((((public.propiedades p
     JOIN public.ciudades c ON ((c.ciudad_id = p.ciudad_id)))
     JOIN public.tipos_inmueble ti ON ((ti.tipo_inmueble_id = p.tipo_inmueble_id)))
     JOIN public.empleados e ON ((e.empleado_id = p.responsable_id)))
     JOIN public.publicaciones pub ON (((pub.propiedad_id = p.propiedad_id) AND (pub.publicada = true))))
     JOIN public.tipos_operacion top ON ((top.tipo_operacion_id = pub.tipo_operacion_id)))
  WHERE ((p.estado_comercial)::text = 'disponible'::text);


ALTER VIEW public.v_inventario_disponible OWNER TO postgres;

--
-- TOC entry 265 (class 1259 OID 19747)
-- Name: v_pipeline_activo; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_pipeline_activo AS
 SELECT s.solicitud_id,
    s.estado,
    s.creado_en,
    (((pe.nombres)::text || ' '::text) || (pe.apellidos)::text) AS prospecto,
    pe.email,
    p.propiedad_id,
    p.titulo,
    p.estado_comercial,
    ca.nombre_campana,
    cm.nombre AS canal
   FROM ((((public.solicitudes_propiedad s
     JOIN public.personas pe ON ((pe.persona_id = s.persona_id)))
     JOIN public.propiedades p ON ((p.propiedad_id = s.propiedad_id)))
     LEFT JOIN public.campanas ca ON ((ca.campana_id = s.campana_id)))
     LEFT JOIN public.canales_marketing cm ON ((cm.canal_id = ca.canal_id)))
  WHERE ((s.estado)::text = ANY (ARRAY[('nueva'::character varying)::text, ('en_seguimiento'::character varying)::text, ('en_negociacion'::character varying)::text]));


ALTER VIEW public.v_pipeline_activo OWNER TO postgres;

--
-- TOC entry 266 (class 1259 OID 19752)
-- Name: v_resultado_cierres; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_resultado_cierres AS
 SELECT t.transaccion_id,
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
    (((pe.nombres)::text || ' '::text) || (pe.apellidos)::text) AS prospecto,
    emp.nombre AS asesor_cierre
   FROM ((((((public.transacciones t
     JOIN public.ofertas o ON ((o.oferta_id = t.oferta_id)))
     JOIN public.solicitudes_propiedad s ON ((s.solicitud_id = o.solicitud_id)))
     JOIN public.propiedades p ON ((p.propiedad_id = s.propiedad_id)))
     JOIN public.ciudades c ON ((c.ciudad_id = p.ciudad_id)))
     JOIN public.personas pe ON ((pe.persona_id = s.persona_id)))
     JOIN public.empleados emp ON ((emp.empleado_id = t.empleado_id)));


ALTER VIEW public.v_resultado_cierres OWNER TO postgres;

--
-- TOC entry 267 (class 1259 OID 19757)
-- Name: visitas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.visitas (
    visita_id integer NOT NULL,
    solicitud_id integer NOT NULL,
    empleado_id integer NOT NULL,
    fecha_programada timestamp with time zone NOT NULL,
    fecha_realizada timestamp with time zone,
    duracion_min integer,
    motivo_cancelacion character varying(200),
    feedback_cliente text,
    calificacion_interes integer,
    observaciones_empleado text,
    CONSTRAINT ck_visitas_calificacion CHECK (((calificacion_interes IS NULL) OR ((calificacion_interes >= 1) AND (calificacion_interes <= 5)))),
    CONSTRAINT ck_visitas_duracion CHECK (((duracion_min IS NULL) OR (duracion_min > 0)))
);


ALTER TABLE public.visitas OWNER TO postgres;

--
-- TOC entry 268 (class 1259 OID 19768)
-- Name: visitas_visita_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.visitas ALTER COLUMN visita_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.visitas_visita_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 5308 (class 0 OID 19495)
-- Dependencies: 219
-- Data for Name: acceso_via; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.acceso_via (acceso_via_id, nombre) FROM stdin;
1	pavimentada
2	destapada
3	peatonal
\.


--
-- TOC entry 5310 (class 0 OID 19501)
-- Dependencies: 221
-- Data for Name: campana_propiedades; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.campana_propiedades (campana_propiedad_id, campana_id, propiedad_id) FROM stdin;
1	1	1
2	5	1
3	2	2
4	6	2
5	3	3
6	7	3
7	4	4
8	8	4
9	5	5
10	9	5
11	6	6
12	10	6
13	7	7
14	11	7
15	8	8
16	12	8
17	9	9
18	1	9
19	10	10
20	2	10
21	11	11
22	3	11
23	12	12
24	4	12
25	1	13
26	2	14
27	3	15
28	4	16
29	5	17
30	6	18
31	7	19
32	8	20
33	9	21
34	10	22
35	11	23
36	12	24
37	1	25
38	2	26
39	3	27
40	4	28
41	5	29
42	6	30
43	7	31
44	8	32
45	9	33
46	10	34
47	11	35
48	12	36
49	1	37
50	2	38
51	3	39
52	4	40
53	5	41
54	6	42
55	7	43
56	8	44
57	9	45
58	10	46
59	11	47
60	12	48
61	1	49
62	2	50
63	3	51
64	4	52
\.


--
-- TOC entry 5312 (class 0 OID 19508)
-- Dependencies: 223
-- Data for Name: campanas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.campanas (campana_id, canal_id, nombre_campana, presupuesto_planeado, presupuesto_invertido, fecha_inicio, fecha_fin, estado) FROM stdin;
1	2	Leads Meta Q1	25000000.00	22000000.00	2026-01-10	2026-03-31	cerrada
2	1	Portales web abril	12000000.00	9500000.00	2026-04-01	2026-06-30	cerrada
3	2	Meta mid year	30000000.00	18000000.00	2026-07-01	2026-09-30	activa
4	3	WhatsApp referidos	4000000.00	2800000.00	2026-08-01	2026-11-30	activa
5	5	Feria Corferias	18000000.00	18000000.00	2026-05-12	2026-05-18	cerrada
6	4	Referidos asesores	2000000.00	900000.00	2026-02-01	2026-12-15	activa
7	1	Remarketing web	8000000.00	\N	2026-10-01	2026-12-31	activa
8	2	Lanzamiento norte	15000000.00	\N	2026-11-01	2027-01-31	planificada
9	3	Captacion WhatsApp	3500000.00	1200000.00	2026-03-01	2026-08-31	cerrada
10	1	Inventario premium	10000000.00	6000000.00	2026-06-01	2026-12-01	activa
11	2	Campaña lotes	7000000.00	4400000.00	2026-04-15	2026-10-15	cerrada
12	5	Open house Usaquen	5000000.00	5000000.00	2026-09-01	2026-09-07	cerrada
\.


--
-- TOC entry 5314 (class 0 OID 19523)
-- Dependencies: 225
-- Data for Name: canales_marketing; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.canales_marketing (canal_id, nombre, activo) FROM stdin;
1	web	t
2	Meta Ads	t
3	WhatsApp	t
4	referidos	t
5	feria inmobiliaria	t
\.


--
-- TOC entry 5316 (class 0 OID 19531)
-- Dependencies: 227
-- Data for Name: ciudades; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ciudades (ciudad_id, nombre) FROM stdin;
1	Bogota
2	Medellin
3	Cali
4	Barranquilla
5	Bucaramanga
6	Cartagena
7	Pereira
8	Manizales
9	Santa Marta
10	Ibague
\.


--
-- TOC entry 5318 (class 0 OID 19537)
-- Dependencies: 229
-- Data for Name: detalle_construcciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalle_construcciones (detalle_construccion_id, propiedad_id, estado_conservacion_id, area_construida_m2, habitaciones, banos, parqueaderos, pisos_totales, piso_ubicacion, anio_construccion, amoblado, ascensor, deposito) FROM stdin;
1	1	2	41.50	2	2	1	9	2	1996	f	t	f
2	2	3	43.00	3	3	2	1	1	1997	f	f	f
3	3	4	44.50	4	1	0	11	4	1998	f	f	t
4	5	2	47.50	2	3	2	13	6	2000	t	t	f
5	6	3	49.00	3	1	0	14	7	2001	f	t	t
6	7	4	50.50	4	2	1	1	1	2002	f	f	f
7	8	1	52.00	1	3	2	16	2	2003	f	f	f
8	10	3	55.00	3	2	1	8	4	2005	t	t	f
9	11	4	56.50	4	3	2	9	5	2006	f	t	f
10	12	1	58.00	1	1	0	1	1	2007	f	f	t
11	13	2	59.50	2	2	1	11	7	2008	f	f	f
12	15	4	62.50	4	1	0	13	2	2010	t	t	t
13	16	1	64.00	1	2	1	14	3	2011	f	t	f
14	17	2	65.50	2	3	2	1	1	2012	f	f	f
15	18	3	67.00	3	1	0	16	5	2013	f	f	t
16	20	1	70.00	1	3	2	8	7	2015	t	t	f
17	21	2	71.50	2	1	0	9	1	2016	f	t	t
18	22	3	73.00	3	2	1	1	1	2017	f	f	f
19	23	4	74.50	4	3	2	11	3	2018	f	f	f
20	25	2	77.50	2	2	1	13	5	2020	t	t	f
21	26	3	79.00	3	3	2	14	6	2021	f	t	f
22	27	4	80.50	4	1	0	1	1	2022	f	f	t
23	28	1	82.00	1	2	1	16	1	1995	f	f	f
24	30	3	85.00	3	1	0	8	3	1997	t	t	t
25	31	4	86.50	4	2	1	9	4	1998	f	t	f
26	32	1	88.00	1	3	2	1	1	1999	f	f	f
27	33	2	89.50	2	1	0	11	6	2000	f	f	t
28	35	4	92.50	4	3	2	13	1	2002	t	t	f
29	36	1	94.00	1	1	0	14	2	2003	f	t	t
30	37	2	95.50	2	2	1	1	1	2004	f	f	f
31	38	3	97.00	3	3	2	16	4	2005	f	f	f
32	40	1	100.00	1	2	1	8	6	2007	t	t	f
33	41	2	101.50	2	3	2	9	7	2008	f	t	f
34	42	3	103.00	3	1	0	1	1	2009	f	f	t
35	43	4	104.50	4	2	1	11	2	2010	f	f	f
36	45	2	107.50	2	1	0	13	4	2012	t	t	t
37	46	3	109.00	3	2	1	14	5	2013	f	t	f
38	47	4	110.50	4	3	2	1	1	2014	f	f	f
39	48	1	112.00	1	1	0	16	7	2015	f	f	t
40	50	3	115.00	3	3	2	8	2	2017	t	t	f
41	51	4	116.50	4	1	0	9	3	2018	f	t	t
42	52	1	118.00	1	2	1	1	1	2019	f	f	f
\.


--
-- TOC entry 5320 (class 0 OID 19564)
-- Dependencies: 231
-- Data for Name: detalle_terrenos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalle_terrenos (detalle_terreno_id, propiedad_id, uso_suelo_id, acceso_via_id, frente_m, fondo_m, topografia, zona, es_esquinero) FROM stdin;
1	2	1	1	10.50	14.00	plana	urbana	f
2	4	1	1	12.50	16.00	plana	urbana	f
3	7	1	2	15.50	19.00	plana	urbana	f
4	9	2	1	17.50	21.00	inclinada	urbana	f
5	12	1	1	20.50	24.00	inclinada	rural	f
6	14	3	2	22.50	26.00	plana	urbana	f
7	17	1	1	25.50	29.00	plana	urbana	f
8	19	4	1	27.50	31.00	plana	urbana	f
9	22	1	1	10.50	34.00	plana	urbana	f
10	24	1	1	12.50	36.00	inclinada	rural	f
11	27	1	1	15.50	39.00	inclinada	urbana	f
12	29	2	1	17.50	41.00	plana	urbana	f
13	32	1	1	20.50	14.00	plana	urbana	f
14	34	3	1	22.50	16.00	plana	urbana	f
15	37	1	1	25.50	19.00	plana	urbana	f
16	39	4	1	27.50	21.00	inclinada	urbana	f
17	42	1	2	10.50	24.00	inclinada	rural	f
18	44	1	1	12.50	26.00	plana	urbana	f
19	47	1	1	15.50	29.00	plana	urbana	f
20	49	2	2	17.50	31.00	plana	urbana	f
21	52	1	1	20.50	34.00	plana	urbana	f
\.


--
-- TOC entry 5322 (class 0 OID 19582)
-- Dependencies: 233
-- Data for Name: empleados; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.empleados (empleado_id, rol_id, nombre, email, telefono, fecha_ingreso) FROM stdin;
1	3	Harold Burgos	harold.burgos@mcs.co	3001110001	2022-01-15
2	2	Sofia Camelo	sofia.camelo@mcs.co	3001110002	2022-03-01
3	2	Juan Triana	juan.triana@mcs.co	3001110003	2021-11-20
4	1	Marta Rincon	marta.rincon@mcs.co	3001110004	2023-02-10
5	1	Pedro Ospina	pedro.ospina@mcs.co	3001110005	2023-05-18
6	1	Luisa Restrepo	luisa.restrepo@mcs.co	3001110006	2024-01-08
7	1	Andres Mejia	andres.mejia@mcs.co	3001110007	2024-06-01
8	1	Elena Vargas	elena.vargas@mcs.co	3001110008	2025-01-12
9	1	Diego Parra	diego.parra@mcs.co	3001110009	2025-04-03
10	1	Camila Soto	camila.soto@mcs.co	3001110010	2025-08-21
\.


--
-- TOC entry 5324 (class 0 OID 19591)
-- Dependencies: 235
-- Data for Name: estado_conservacion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.estado_conservacion (estado_conservacion_id, nombre) FROM stdin;
1	excelente
2	bueno
3	regular
4	a_remodelar
\.


--
-- TOC entry 5326 (class 0 OID 19597)
-- Dependencies: 237
-- Data for Name: ofertas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ofertas (oferta_id, solicitud_id, estado_oferta, valor_ofertado, fecha_oferta) FROM stdin;
1	2	pendiente	193000000.00	2026-05-03 15:00:00-05
2	2	aceptada	198000000.00	2026-05-04 15:00:00-05
3	3	pendiente	202000000.00	2026-05-04 15:00:00-05
4	3	aceptada	207000000.00	2026-05-05 15:00:00-05
5	4	pendiente	211000000.00	2026-05-05 15:00:00-05
6	4	aceptada	216000000.00	2026-05-06 15:00:00-05
7	6	pendiente	229000000.00	2026-05-07 15:00:00-05
8	6	aceptada	234000000.00	2026-05-08 15:00:00-05
9	7	pendiente	238000000.00	2026-05-08 15:00:00-05
10	7	aceptada	243000000.00	2026-05-09 15:00:00-05
11	8	pendiente	247000000.00	2026-05-09 15:00:00-05
12	8	aceptada	252000000.00	2026-05-10 15:00:00-05
13	10	pendiente	265000000.00	2026-05-11 15:00:00-05
14	10	aceptada	270000000.00	2026-05-12 15:00:00-05
15	11	pendiente	274000000.00	2026-05-12 15:00:00-05
16	11	aceptada	279000000.00	2026-05-13 15:00:00-05
17	13	pendiente	292000000.00	2026-05-14 15:00:00-05
18	13	aceptada	297000000.00	2026-05-15 15:00:00-05
19	14	pendiente	301000000.00	2026-05-15 15:00:00-05
20	14	aceptada	306000000.00	2026-05-16 15:00:00-05
21	16	pendiente	319000000.00	2026-05-17 15:00:00-05
22	16	aceptada	324000000.00	2026-05-18 15:00:00-05
23	17	pendiente	328000000.00	2026-05-18 15:00:00-05
24	17	aceptada	333000000.00	2026-05-19 15:00:00-05
25	18	pendiente	337000000.00	2026-05-19 15:00:00-05
26	18	aceptada	342000000.00	2026-05-20 15:00:00-05
27	19	aceptada	346000000.00	2026-05-20 15:00:00-05
28	20	caducada	355000000.00	2026-05-21 15:00:00-05
29	21	rechazada	364000000.00	2026-05-22 15:00:00-05
30	22	aceptada	373000000.00	2026-05-23 15:00:00-05
31	24	aceptada	391000000.00	2026-05-25 15:00:00-05
32	26	pendiente	409000000.00	2026-05-27 15:00:00-05
33	27	aceptada	418000000.00	2026-05-28 15:00:00-05
34	28	caducada	427000000.00	2026-05-29 15:00:00-05
35	29	rechazada	436000000.00	2026-05-30 15:00:00-05
36	30	pendiente	445000000.00	2026-05-31 15:00:00-05
37	32	aceptada	463000000.00	2026-06-02 15:00:00-05
38	34	pendiente	481000000.00	2026-06-04 15:00:00-05
39	35	aceptada	490000000.00	2026-06-05 15:00:00-05
40	36	caducada	499000000.00	2026-06-06 15:00:00-05
41	37	rechazada	508000000.00	2026-06-07 15:00:00-05
42	38	pendiente	517000000.00	2026-06-08 15:00:00-05
43	40	aceptada	535000000.00	2026-06-10 15:00:00-05
44	42	pendiente	553000000.00	2026-06-12 15:00:00-05
45	43	aceptada	562000000.00	2026-06-13 15:00:00-05
46	44	caducada	571000000.00	2026-06-14 15:00:00-05
47	45	rechazada	580000000.00	2026-06-15 15:00:00-05
48	46	pendiente	589000000.00	2026-06-16 15:00:00-05
49	48	aceptada	607000000.00	2026-06-18 15:00:00-05
50	50	pendiente	625000000.00	2026-06-20 15:00:00-05
51	51	aceptada	634000000.00	2026-06-21 15:00:00-05
52	52	caducada	643000000.00	2026-06-22 15:00:00-05
53	53	rechazada	652000000.00	2026-06-23 15:00:00-05
54	54	pendiente	661000000.00	2026-06-24 15:00:00-05
55	56	aceptada	679000000.00	2026-06-26 15:00:00-05
56	58	pendiente	697000000.00	2026-06-28 15:00:00-05
57	59	aceptada	706000000.00	2026-06-29 15:00:00-05
58	60	caducada	715000000.00	2026-06-30 15:00:00-05
59	61	rechazada	724000000.00	2026-07-01 15:00:00-05
60	62	pendiente	733000000.00	2026-07-02 15:00:00-05
61	64	aceptada	751000000.00	2026-07-04 15:00:00-05
\.


--
-- TOC entry 5328 (class 0 OID 19610)
-- Dependencies: 239
-- Data for Name: persona_roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.persona_roles (persona_id, tipo_persona_id) FROM stdin;
1	1
2	1
3	1
4	1
5	1
6	1
7	1
8	1
9	1
10	1
11	1
12	1
13	1
14	1
15	1
16	1
17	1
18	1
19	1
20	1
21	1
22	1
23	1
24	1
25	1
20	2
21	2
22	2
23	2
24	2
25	2
26	2
27	2
28	2
29	2
30	2
31	2
32	2
33	2
34	2
35	2
36	2
37	2
38	2
39	2
40	2
41	2
42	2
43	2
44	2
45	2
46	2
47	2
48	2
49	2
50	2
51	2
52	2
53	2
54	2
55	2
\.


--
-- TOC entry 5329 (class 0 OID 19615)
-- Dependencies: 240
-- Data for Name: personas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.personas (persona_id, nombres, apellidos, telefono, email, ciudad_id) FROM stdin;
1	Ana	Garcia	3002000001	ana.garcia1@mail.co	1
2	Luis	Rodriguez	3002000002	luis.rodriguez2@mail.co	2
3	Maria	Martinez	3002000003	maria.martinez3@mail.co	3
4	Carlos	Lopez	3002000004	carlos.lopez4@mail.co	4
5	Sofia	Gonzalez	3002000005	sofia.gonzalez5@mail.co	5
6	Andres	Hernandez	3002000006	andres.hernandez6@mail.co	6
7	Laura	Perez	3002000007	laura.perez7@mail.co	7
8	Diego	Sanchez	3002000008	diego.sanchez8@mail.co	8
9	Camila	Ramirez	3002000009	camila.ramirez9@mail.co	9
10	Juan	Torres	3002000010	juan.torres10@mail.co	10
11	Valentina	Flores	3002000011	valentina.flores11@mail.co	1
12	Santiago	Rivera	3002000012	santiago.rivera12@mail.co	2
13	Daniela	Gomez	3002000013	daniela.gomez13@mail.co	3
14	Felipe	Diaz	3002000014	felipe.diaz14@mail.co	4
15	Isabella	Cruz	3002000015	isabella.cruz15@mail.co	5
16	Mateo	Morales	3002000016	mateo.morales16@mail.co	6
17	Gabriela	Reyes	3002000017	gabriela.reyes17@mail.co	7
18	Sebastian	Gutierrez	3002000018	sebastian.gutierrez18@mail.co	8
19	Paula	Ortiz	3002000019	paula.ortiz19@mail.co	9
20	Nicolas	Rojas	3002000020	nicolas.rojas20@mail.co	10
21	Juliana	Vargas	3002000021	juliana.vargas21@mail.co	1
22	David	Castro	3002000022	david.castro22@mail.co	2
23	Carolina	Ruiz	3002000023	carolina.ruiz23@mail.co	3
24	Alejandro	Jimenez	3002000024	alejandro.jimenez24@mail.co	4
25	Natalia	Mendoza	3002000025	natalia.mendoza25@mail.co	5
26	Camilo	Aguilar	3002000026	camilo.aguilar26@mail.co	6
27	Daniel	Medina	3002000027	daniel.medina27@mail.co	7
28	Mariana	Cortes	3002000028	mariana.cortes28@mail.co	8
29	Jorge	Silva	3002000029	jorge.silva29@mail.co	9
30	Andrea	Ramos	3002000030	andrea.ramos30@mail.co	10
31	Ricardo	Romero	3002000031	ricardo.romero31@mail.co	1
32	Elena	Suarez	3002000032	elena.suarez32@mail.co	2
33	Oscar	Herrera	3002000033	oscar.herrera33@mail.co	3
34	Patricia	Nunez	3002000034	patricia.nunez34@mail.co	4
35	Hernan	Molina	3002000035	hernan.molina35@mail.co	5
36	Lucia	Delgado	3002000036	lucia.delgado36@mail.co	6
37	Tomas	Pena	3002000037	tomas.pena37@mail.co	7
38	Diana	Guerrero	3002000038	diana.guerrero38@mail.co	8
39	Pablo	Cabrera	3002000039	pablo.cabrera39@mail.co	9
40	Monica	Navarro	3002000040	monica.navarro40@mail.co	10
41	Cristian	Campos	3002000041	cristian.campos41@mail.co	1
42	Angela	Vega	3002000042	angela.vega42@mail.co	2
43	Mauricio	Soto	3002000043	mauricio.soto43@mail.co	3
44	Claudia	Leon	3002000044	claudia.leon44@mail.co	4
45	Esteban	Rincon	3002000045	esteban.rincon45@mail.co	5
46	Adriana	Mejia	3002000046	adriana.mejia46@mail.co	6
47	Julian	Cardenas	3002000047	julian.cardenas47@mail.co	7
48	Liliana	Parra	3002000048	liliana.parra48@mail.co	8
49	Ivan	Quintero	3002000049	ivan.quintero49@mail.co	9
50	Tatiana	Salazar	3002000050	tatiana.salazar50@mail.co	10
51	Rafael	Bermudez	3002000051	rafael.bermudez51@mail.co	1
52	Catalina	Castaño	3002000052	catalina.castaño52@mail.co	2
53	Hugo	Ospina	3002000053	hugo.ospina53@mail.co	3
54	Gloria	Restrepo	3002000054	gloria.restrepo54@mail.co	4
55	Fernando	Valencia	3002000055	fernando.valencia55@mail.co	5
\.


--
-- TOC entry 5331 (class 0 OID 19624)
-- Dependencies: 242
-- Data for Name: propiedad_propietarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.propiedad_propietarios (propiedad_propietario_id, persona_id, propiedad_id) FROM stdin;
1	1	1
2	2	2
3	3	3
4	4	4
5	5	4
6	5	5
7	6	6
8	7	7
9	8	8
10	9	8
11	9	9
12	10	10
13	11	11
14	12	12
15	13	12
16	13	13
17	14	14
18	15	15
19	16	16
20	17	16
21	17	17
22	18	18
23	19	19
24	20	20
25	21	20
26	21	21
27	22	22
28	23	23
29	24	24
30	25	24
31	25	25
32	1	26
33	2	27
34	3	28
35	4	28
36	4	29
37	5	30
38	6	31
39	7	32
40	8	32
41	8	33
42	9	34
43	10	35
44	11	36
45	12	36
46	12	37
47	13	38
48	14	39
49	15	40
50	16	40
51	16	41
52	17	42
53	18	43
54	19	44
55	20	44
56	20	45
57	21	46
58	22	47
59	23	48
60	24	48
61	24	49
62	25	50
63	1	51
64	2	52
65	3	52
\.


--
-- TOC entry 5333 (class 0 OID 19631)
-- Dependencies: 244
-- Data for Name: propiedades; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.propiedades (propiedad_id, tipo_inmueble_id, ciudad_id, responsable_id, matricula_inmobiliaria, titulo, descripcion, direccion, area_total_m2, estado_comercial, creado_en, actualizado_en) FROM stdin;
7	2	7	7	50N-000007	Casa en Granada 7	Inmueble de demostracion 7 para trazabilidad comercial MCS.	Calle 17 # 7-21	161.00	disponible	2024-02-19 08:00:00-05	2024-02-19 08:00:00-05
8	3	8	8	50N-000008	Local comercial en Bocagrande 8	Inmueble de demostracion 8 para trazabilidad comercial MCS.	Calle 18 # 8-24	64.00	disponible	2024-02-26 08:00:00-05	2024-02-26 08:00:00-05
10	5	10	10	50N-000010	Oficina en Ciudad Jardin 10	Inmueble de demostracion 10 para trazabilidad comercial MCS.	Calle 20 # 10-30	68.00	disponible	2024-03-11 08:00:00-05	2024-03-11 08:00:00-05
11	1	1	1	50N-000011	Apartamento en Chapinero 11	Inmueble de demostracion 11 para trazabilidad comercial MCS.	Calle 21 # 11-33	70.00	disponible	2024-03-18 08:00:00-05	2024-03-18 08:00:00-05
12	2	2	2	50N-000012	Casa en Usaquen 12	Inmueble de demostracion 12 para trazabilidad comercial MCS.	Calle 22 # 12-36	176.00	disponible	2024-03-25 08:00:00-05	2024-03-25 08:00:00-05
13	3	3	3	50N-000013	Local comercial en Teusaquillo 13	Inmueble de demostracion 13 para trazabilidad comercial MCS.	Calle 23 # 13-39	74.00	disponible	2024-04-01 08:00:00-05	2024-04-01 08:00:00-05
15	5	5	5	50N-000015	Oficina en El Poblado 15	Inmueble de demostracion 15 para trazabilidad comercial MCS.	Calle 25 # 15-45	78.00	disponible	2024-04-15 08:00:00-05	2024-04-15 08:00:00-05
16	1	6	6	50N-000016	Apartamento en Laureles 16	Inmueble de demostracion 16 para trazabilidad comercial MCS.	Calle 26 # 16-48	80.00	disponible	2024-04-22 08:00:00-05	2024-04-22 08:00:00-05
18	3	8	8	50N-000018	Local comercial en Bocagrande 18	Inmueble de demostracion 18 para trazabilidad comercial MCS.	Calle 28 # 18-54	84.00	disponible	2024-05-06 08:00:00-05	2024-05-06 08:00:00-05
19	4	9	9	50N-000019	Lote en Cabecera 19	Inmueble de demostracion 19 para trazabilidad comercial MCS.	Calle 29 # 19-57	478.00	disponible	2024-05-13 08:00:00-05	2024-05-13 08:00:00-05
20	5	10	10	50N-000020	Oficina en Ciudad Jardin 20	Inmueble de demostracion 20 para trazabilidad comercial MCS.	Calle 30 # 20-60	88.00	disponible	2024-05-20 08:00:00-05	2024-05-20 08:00:00-05
21	1	1	1	50N-000021	Apartamento en Chapinero 21	Inmueble de demostracion 21 para trazabilidad comercial MCS.	Calle 31 # 21-63	90.00	disponible	2024-05-27 08:00:00-05	2024-05-27 08:00:00-05
25	5	5	5	50N-000025	Oficina en El Poblado 25	Inmueble de demostracion 25 para trazabilidad comercial MCS.	Calle 35 # 25-75	98.00	disponible	2024-06-24 08:00:00-05	2024-06-24 08:00:00-05
26	1	6	6	50N-000026	Apartamento en Laureles 26	Inmueble de demostracion 26 para trazabilidad comercial MCS.	Calle 36 # 26-78	100.00	disponible	2024-07-01 08:00:00-05	2024-07-01 08:00:00-05
28	3	8	8	50N-000028	Local comercial en Bocagrande 28	Inmueble de demostracion 28 para trazabilidad comercial MCS.	Calle 38 # 28-4	104.00	disponible	2024-07-15 08:00:00-05	2024-07-15 08:00:00-05
30	5	10	10	50N-000030	Oficina en Ciudad Jardin 30	Inmueble de demostracion 30 para trazabilidad comercial MCS.	Calle 40 # 30-10	108.00	disponible	2024-07-29 08:00:00-05	2024-07-29 08:00:00-05
31	1	1	1	50N-000031	Apartamento en Chapinero 31	Inmueble de demostracion 31 para trazabilidad comercial MCS.	Calle 41 # 31-13	110.00	disponible	2024-08-05 08:00:00-05	2024-08-05 08:00:00-05
33	3	3	3	50N-000033	Local comercial en Teusaquillo 33	Inmueble de demostracion 33 para trazabilidad comercial MCS.	Calle 43 # 33-19	114.00	disponible	2024-08-19 08:00:00-05	2024-08-19 08:00:00-05
34	4	4	4	50N-000034	Lote en Cedritos 34	Inmueble de demostracion 34 para trazabilidad comercial MCS.	Calle 44 # 34-22	658.00	disponible	2024-08-26 08:00:00-05	2024-08-26 08:00:00-05
35	5	5	5	50N-000035	Oficina en El Poblado 35	Inmueble de demostracion 35 para trazabilidad comercial MCS.	Calle 45 # 35-25	118.00	disponible	2024-09-02 08:00:00-05	2024-09-02 08:00:00-05
36	1	6	6	50N-000036	Apartamento en Laureles 36	Inmueble de demostracion 36 para trazabilidad comercial MCS.	Calle 46 # 36-28	120.00	disponible	2024-09-09 08:00:00-05	2024-09-09 08:00:00-05
38	3	8	8	50N-000038	Local comercial en Bocagrande 38	Inmueble de demostracion 38 para trazabilidad comercial MCS.	Calle 48 # 38-34	124.00	disponible	2024-09-23 08:00:00-05	2024-09-23 08:00:00-05
39	4	9	9	50N-000039	Lote en Cabecera 39	Inmueble de demostracion 39 para trazabilidad comercial MCS.	Calle 49 # 39-37	718.00	disponible	2024-09-30 08:00:00-05	2024-09-30 08:00:00-05
41	1	1	1	50N-000041	Apartamento en Chapinero 41	Inmueble de demostracion 41 para trazabilidad comercial MCS.	Calle 51 # 41-43	130.00	no_disponible	2024-10-14 08:00:00-05	2024-10-14 08:00:00-05
42	2	2	2	50N-000042	Casa en Usaquen 42	Inmueble de demostracion 42 para trazabilidad comercial MCS.	Calle 52 # 42-46	266.00	no_disponible	2024-10-21 08:00:00-05	2024-10-21 08:00:00-05
43	3	3	3	50N-000043	Local comercial en Teusaquillo 43	Inmueble de demostracion 43 para trazabilidad comercial MCS.	Calle 53 # 43-49	134.00	no_disponible	2024-10-28 08:00:00-05	2024-10-28 08:00:00-05
44	4	4	4	50N-000044	Lote en Cedritos 44	Inmueble de demostracion 44 para trazabilidad comercial MCS.	Calle 54 # 44-52	778.00	no_disponible	2024-11-04 08:00:00-05	2024-11-04 08:00:00-05
46	1	6	6	50N-000046	Apartamento en Laureles 46	Inmueble de demostracion 46 para trazabilidad comercial MCS.	Calle 56 # 46-58	140.00	disponible	2024-11-18 08:00:00-05	2024-11-18 08:00:00-05
47	2	7	7	50N-000047	Casa en Granada 47	Inmueble de demostracion 47 para trazabilidad comercial MCS.	Calle 57 # 47-61	281.00	disponible	2024-11-25 08:00:00-05	2024-11-25 08:00:00-05
49	4	9	9	50N-000049	Lote en Cabecera 49	Inmueble de demostracion 49 para trazabilidad comercial MCS.	Calle 59 # 49-67	838.00	disponible	2024-12-09 08:00:00-05	2024-12-09 08:00:00-05
50	5	10	10	50N-000050	Oficina en Ciudad Jardin 50	Inmueble de demostracion 50 para trazabilidad comercial MCS.	Calle 60 # 50-70	148.00	disponible	2024-12-16 08:00:00-05	2024-12-16 08:00:00-05
51	1	1	1	50N-000051	Apartamento en Chapinero 51	Inmueble de demostracion 51 para trazabilidad comercial MCS.	Calle 61 # 51-73	150.00	disponible	2024-12-23 08:00:00-05	2024-12-23 08:00:00-05
52	2	2	2	50N-000052	Casa en Usaquen 52	Inmueble de demostracion 52 para trazabilidad comercial MCS.	Calle 62 # 52-76	296.00	disponible	2024-12-30 08:00:00-05	2024-12-30 08:00:00-05
22	2	2	2	50N-000022	Casa en Usaquen 22	Inmueble de demostracion 22 para trazabilidad comercial MCS.	Calle 32 # 22-66	206.00	en_negociacion	2024-06-03 08:00:00-05	2026-11-14 19:34:14.042239-05
1	1	1	1	50N-000001	Apartamento en Chapinero 1	Inmueble de demostracion 1 para trazabilidad comercial MCS.	Calle 11 # 1-3	50.00	vendida	2024-01-08 08:00:00-05	2026-11-14 19:34:14.042239-05
2	2	2	2	50N-000002	Casa en Usaquen 2	Inmueble de demostracion 2 para trazabilidad comercial MCS.	Calle 12 # 2-6	146.00	vendida	2024-01-15 08:00:00-05	2026-11-14 19:34:14.042239-05
3	3	3	3	50N-000003	Local comercial en Teusaquillo 3	Inmueble de demostracion 3 para trazabilidad comercial MCS.	Calle 13 # 3-9	54.00	vendida	2024-01-22 08:00:00-05	2026-11-14 19:34:14.042239-05
4	4	4	4	50N-000004	Lote en Cedritos 4	Inmueble de demostracion 4 para trazabilidad comercial MCS.	Calle 14 # 4-12	298.00	vendida	2024-01-29 08:00:00-05	2026-11-14 19:34:14.042239-05
5	5	5	5	50N-000005	Oficina en El Poblado 5	Inmueble de demostracion 5 para trazabilidad comercial MCS.	Calle 15 # 5-15	58.00	vendida	2024-02-05 08:00:00-05	2026-11-14 19:34:14.042239-05
23	3	3	3	50N-000023	Local comercial en Teusaquillo 23	Inmueble de demostracion 23 para trazabilidad comercial MCS.	Calle 33 # 23-69	94.00	vendida	2024-06-10 08:00:00-05	2026-11-14 19:34:14.042239-05
24	4	4	4	50N-000024	Lote en Cedritos 24	Inmueble de demostracion 24 para trazabilidad comercial MCS.	Calle 34 # 24-72	538.00	vendida	2024-06-17 08:00:00-05	2026-11-14 19:34:14.042239-05
27	2	7	7	50N-000027	Casa en Granada 27	Inmueble de demostracion 27 para trazabilidad comercial MCS.	Calle 37 # 27-1	221.00	vendida	2024-07-08 08:00:00-05	2026-11-14 19:34:14.042239-05
29	4	9	9	50N-000029	Lote en Cabecera 29	Inmueble de demostracion 29 para trazabilidad comercial MCS.	Calle 39 # 29-7	598.00	vendida	2024-07-22 08:00:00-05	2026-11-14 19:34:14.042239-05
32	2	2	2	50N-000032	Casa en Usaquen 32	Inmueble de demostracion 32 para trazabilidad comercial MCS.	Calle 42 # 32-16	236.00	vendida	2024-08-12 08:00:00-05	2026-11-14 19:34:14.042239-05
37	2	7	7	50N-000037	Casa en Granada 37	Inmueble de demostracion 37 para trazabilidad comercial MCS.	Calle 47 # 37-31	251.00	vendida	2024-09-16 08:00:00-05	2026-11-14 19:34:14.042239-05
40	5	10	10	50N-000040	Oficina en Ciudad Jardin 40	Inmueble de demostracion 40 para trazabilidad comercial MCS.	Calle 50 # 40-40	128.00	vendida	2024-10-07 08:00:00-05	2026-11-14 19:34:14.042239-05
45	5	5	5	50N-000045	Oficina en El Poblado 45	Inmueble de demostracion 45 para trazabilidad comercial MCS.	Calle 55 # 45-55	138.00	vendida	2024-11-11 08:00:00-05	2026-11-14 19:34:14.042239-05
48	3	8	8	50N-000048	Local comercial en Bocagrande 48	Inmueble de demostracion 48 para trazabilidad comercial MCS.	Calle 58 # 48-64	144.00	vendida	2024-12-02 08:00:00-05	2026-11-14 19:34:14.042239-05
6	1	6	6	50N-000006	Apartamento en Laureles 6	Inmueble de demostracion 6 para trazabilidad comercial MCS.	Calle 16 # 6-18	60.00	vendida	2024-02-12 08:00:00-05	2026-11-14 19:34:14.042239-05
9	4	9	9	50N-000009	Lote en Cabecera 9	Inmueble de demostracion 9 para trazabilidad comercial MCS.	Calle 19 # 9-27	358.00	vendida	2024-03-04 08:00:00-05	2026-11-14 19:34:14.042239-05
14	4	4	4	50N-000014	Lote en Cedritos 14	Inmueble de demostracion 14 para trazabilidad comercial MCS.	Calle 24 # 14-42	418.00	no_disponible	2024-04-08 08:00:00-05	2026-11-14 19:34:14.042239-05
17	2	7	7	50N-000017	Casa en Granada 17	Inmueble de demostracion 17 para trazabilidad comercial MCS.	Calle 27 # 17-51	191.00	vendida	2024-04-29 08:00:00-05	2026-11-14 19:34:14.042239-05
\.


--
-- TOC entry 5335 (class 0 OID 19653)
-- Dependencies: 246
-- Data for Name: publicacion_canales; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.publicacion_canales (publicacion_canal_id, canal_id, publicacion_id) FROM stdin;
1	2	1
2	3	2
3	5	2
4	4	3
5	2	4
6	5	4
7	1	5
8	2	6
9	4	6
10	3	7
11	1	8
12	4	8
13	5	9
14	1	10
15	3	10
16	2	11
17	3	12
18	5	12
19	4	13
20	2	14
21	5	14
22	1	15
23	2	16
24	4	16
25	3	17
26	1	18
27	4	18
28	5	19
29	1	20
30	3	20
31	2	21
32	3	22
33	5	22
34	4	23
35	2	24
36	5	24
37	1	25
38	2	26
39	4	26
40	3	27
41	1	28
42	4	28
43	5	29
44	1	30
45	3	30
46	2	31
47	3	32
48	5	32
49	4	33
50	2	34
51	5	34
52	1	35
53	2	36
54	4	36
55	3	37
56	1	38
57	4	38
58	5	39
59	1	40
60	3	40
61	2	41
62	3	42
63	5	42
64	4	43
65	2	44
66	5	44
67	1	45
68	2	46
69	4	46
70	3	47
71	1	48
72	4	48
73	5	49
74	1	50
75	3	50
76	2	51
77	3	52
78	5	52
79	4	53
80	2	54
81	5	54
82	1	55
83	2	56
84	4	56
85	3	57
86	1	58
87	4	58
88	5	59
89	1	60
90	3	60
\.


--
-- TOC entry 5337 (class 0 OID 19660)
-- Dependencies: 248
-- Data for Name: publicaciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.publicaciones (publicacion_id, propiedad_id, tipo_operacion_id, precio, valor_administracion, publicada, fecha_publicacion, fecha_retiro, creado_en, actualizado_en) FROM stdin;
1	1	1	192500000.00	355000.00	t	2025-06-04	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
2	2	1	205000000.00	360000.00	t	2025-06-07	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
3	3	1	217500000.00	365000.00	t	2025-06-10	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
4	4	1	230000000.00	\N	t	2025-06-13	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
5	5	1	242500000.00	375000.00	t	2025-06-16	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
6	6	1	255000000.00	380000.00	t	2025-06-19	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
7	7	2	2360000.00	\N	t	2025-06-22	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
8	8	1	280000000.00	\N	t	2025-06-25	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
9	9	1	292500000.00	395000.00	t	2025-06-28	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
10	10	1	305000000.00	400000.00	t	2025-07-01	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
11	11	1	317500000.00	405000.00	t	2025-07-04	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
12	12	1	330000000.00	\N	t	2025-07-07	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
13	13	1	342500000.00	415000.00	t	2025-07-10	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
14	14	2	2920000.00	\N	t	2025-07-13	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
15	15	1	367500000.00	425000.00	t	2025-07-16	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
16	16	1	380000000.00	\N	t	2025-07-19	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
17	17	1	392500000.00	435000.00	t	2025-07-22	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
18	18	1	405000000.00	440000.00	t	2025-07-25	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
19	19	1	417500000.00	445000.00	t	2025-07-28	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
20	20	1	430000000.00	\N	t	2025-07-31	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
21	21	2	3480000.00	\N	t	2025-08-03	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
22	22	1	455000000.00	460000.00	t	2025-08-06	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
23	23	1	467500000.00	465000.00	t	2025-08-09	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
24	24	1	480000000.00	\N	t	2025-08-12	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
25	25	1	492500000.00	475000.00	t	2025-08-15	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
26	26	1	505000000.00	480000.00	t	2025-08-18	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
27	27	1	517500000.00	485000.00	t	2025-08-21	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
28	28	2	4040000.00	\N	t	2025-08-24	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
29	29	1	542500000.00	495000.00	t	2025-08-27	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
30	30	1	555000000.00	500000.00	t	2025-08-30	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
31	31	1	567500000.00	505000.00	t	2025-09-02	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
32	32	1	580000000.00	\N	t	2025-09-05	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
33	33	1	592500000.00	515000.00	t	2025-09-08	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
34	34	1	605000000.00	520000.00	t	2025-09-11	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
35	35	2	4600000.00	\N	t	2025-09-14	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
36	36	1	630000000.00	\N	t	2025-09-17	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
37	37	1	642500000.00	535000.00	t	2025-09-20	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
38	38	1	655000000.00	540000.00	t	2025-09-23	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
39	39	1	667500000.00	545000.00	t	2025-09-26	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
40	40	1	680000000.00	\N	t	2025-09-29	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
41	41	1	692500000.00	555000.00	f	2025-10-02	2025-11-11	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
42	42	2	5160000.00	\N	f	2025-10-05	2025-11-14	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
43	43	1	717500000.00	565000.00	f	2025-10-08	2025-11-17	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
44	44	1	730000000.00	\N	f	2025-10-11	2025-11-20	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
45	45	1	742500000.00	575000.00	t	2024-03-17	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
46	46	1	755000000.00	580000.00	t	2024-03-18	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
47	47	1	767500000.00	585000.00	t	2024-03-19	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
48	48	1	780000000.00	\N	t	2024-03-20	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
49	49	2	5720000.00	\N	t	2024-03-21	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
50	50	1	805000000.00	600000.00	t	2024-03-22	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
51	51	1	817500000.00	605000.00	t	2024-03-23	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
52	52	1	830000000.00	\N	t	2024-03-24	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
53	1	2	2290000.00	290000.00	t	2026-01-11	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
54	2	2	2380000.00	300000.00	t	2026-01-12	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
55	3	2	2470000.00	310000.00	t	2026-01-13	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
56	4	2	2560000.00	320000.00	t	2026-01-14	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
57	5	2	2650000.00	330000.00	t	2026-01-15	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
58	6	2	2740000.00	340000.00	t	2026-01-16	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
59	7	2	2830000.00	350000.00	t	2026-01-17	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
60	8	2	2920000.00	360000.00	t	2026-01-18	\N	2026-11-14 19:34:14.042239-05	2026-11-14 19:34:14.042239-05
\.


--
-- TOC entry 5339 (class 0 OID 19678)
-- Dependencies: 250
-- Data for Name: rol_empleado; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rol_empleado (rol_id, nombre_rol) FROM stdin;
1	asesor
2	coordinador
3	administrador
\.


--
-- TOC entry 5341 (class 0 OID 19684)
-- Dependencies: 252
-- Data for Name: solicitudes_propiedad; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.solicitudes_propiedad (solicitud_id, persona_id, propiedad_id, empleado_id, campana_id, estado, motivo_descarte, presupuesto_cliente, requiere_financiacion, fecha_cierre, creado_en, actualizado_en) FROM stdin;
1	23	1	4	1	nueva	\N	208000000.00	f	\N	2026-03-02 09:00:00-05	2026-03-02 09:00:00-05
3	25	1	6	1	en_negociacion	\N	224000000.00	f	\N	2026-03-04 09:00:00-05	2026-03-04 09:00:00-05
5	26	2	8	2	nueva	\N	240000000.00	f	\N	2026-03-06 09:00:00-05	2026-03-06 09:00:00-05
7	28	2	10	\N	en_negociacion	\N	256000000.00	f	\N	2026-03-08 09:00:00-05	2026-03-08 09:00:00-05
9	29	3	5	3	nueva	\N	272000000.00	f	\N	2026-03-10 09:00:00-05	2026-03-10 09:00:00-05
11	31	3	7	3	en_negociacion	\N	288000000.00	f	\N	2026-03-12 09:00:00-05	2026-03-12 09:00:00-05
12	32	4	8	4	nueva	\N	296000000.00	t	\N	2026-03-13 09:00:00-05	2026-03-13 09:00:00-05
14	34	4	10	\N	en_negociacion	\N	312000000.00	t	\N	2026-03-15 09:00:00-05	2026-03-15 09:00:00-05
15	35	5	4	5	nueva	\N	320000000.00	f	\N	2026-03-16 09:00:00-05	2026-03-16 09:00:00-05
17	37	5	6	5	en_negociacion	\N	336000000.00	f	\N	2026-03-18 09:00:00-05	2026-03-18 09:00:00-05
20	43	25	9	1	perdida	\N	280000000.00	f	2026-04-16 10:00:00-05	2026-03-27 10:00:00-05	2026-03-27 10:00:00-05
21	47	26	10	2	descartada	presupuesto insuficiente para el inmueble	286500000.00	t	\N	2026-03-29 10:00:00-05	2026-03-29 10:00:00-05
23	55	28	5	4	nueva	\N	299500000.00	f	\N	2026-04-02 10:00:00-05	2026-04-02 10:00:00-05
25	27	30	7	6	nueva	\N	312500000.00	f	\N	2026-04-06 10:00:00-05	2026-04-06 10:00:00-05
26	31	31	8	7	en_seguimiento	\N	319000000.00	f	\N	2026-04-08 10:00:00-05	2026-04-08 10:00:00-05
28	39	33	10	9	perdida	\N	332000000.00	f	2026-05-02 10:00:00-05	2026-04-12 10:00:00-05	2026-04-12 10:00:00-05
29	43	34	4	10	descartada	presupuesto insuficiente para el inmueble	338500000.00	f	\N	2026-04-14 10:00:00-05	2026-04-14 10:00:00-05
30	47	35	5	\N	en_seguimiento	\N	345000000.00	t	\N	2026-04-16 10:00:00-05	2026-04-16 10:00:00-05
31	51	36	6	12	nueva	\N	351500000.00	f	\N	2026-04-18 10:00:00-05	2026-04-18 10:00:00-05
33	23	38	8	2	nueva	\N	364500000.00	t	\N	2026-04-22 10:00:00-05	2026-04-22 10:00:00-05
34	27	39	9	3	en_seguimiento	\N	371000000.00	f	\N	2026-04-24 10:00:00-05	2026-04-24 10:00:00-05
36	35	41	\N	\N	perdida	\N	384000000.00	t	2026-05-18 10:00:00-05	2026-04-28 10:00:00-05	2026-04-28 10:00:00-05
37	39	42	5	6	descartada	presupuesto insuficiente para el inmueble	390500000.00	f	\N	2026-04-30 10:00:00-05	2026-04-30 10:00:00-05
38	43	43	6	7	en_seguimiento	\N	397000000.00	f	\N	2026-05-02 10:00:00-05	2026-05-02 10:00:00-05
39	47	44	7	8	nueva	\N	403500000.00	t	\N	2026-05-04 10:00:00-05	2026-05-04 10:00:00-05
41	55	46	9	10	nueva	\N	416500000.00	f	\N	2026-05-08 10:00:00-05	2026-05-08 10:00:00-05
42	23	47	10	\N	en_seguimiento	\N	423000000.00	t	\N	2026-05-10 10:00:00-05	2026-05-10 10:00:00-05
44	31	49	5	1	perdida	\N	436000000.00	f	2026-06-03 10:00:00-05	2026-05-14 10:00:00-05	2026-05-14 10:00:00-05
45	35	50	\N	2	descartada	presupuesto insuficiente para el inmueble	442500000.00	t	\N	2026-05-16 10:00:00-05	2026-05-16 10:00:00-05
46	39	51	7	3	en_seguimiento	\N	449000000.00	f	\N	2026-05-18 10:00:00-05	2026-05-18 10:00:00-05
47	43	52	8	4	nueva	\N	455500000.00	f	\N	2026-05-20 10:00:00-05	2026-05-20 10:00:00-05
49	54	7	10	7	nueva	\N	468500000.00	f	\N	2026-05-24 10:00:00-05	2026-05-24 10:00:00-05
50	22	8	4	8	en_seguimiento	\N	475000000.00	f	\N	2026-05-26 10:00:00-05	2026-05-26 10:00:00-05
52	30	10	6	10	perdida	\N	488000000.00	f	2026-06-19 10:00:00-05	2026-05-30 10:00:00-05	2026-05-30 10:00:00-05
53	34	11	7	11	descartada	presupuesto insuficiente para el inmueble	494500000.00	f	\N	2026-06-01 10:00:00-05	2026-06-01 10:00:00-05
54	38	12	\N	\N	en_seguimiento	\N	501000000.00	t	\N	2026-06-03 10:00:00-05	2026-06-03 10:00:00-05
55	42	13	9	1	nueva	\N	507500000.00	f	\N	2026-06-05 10:00:00-05	2026-06-05 10:00:00-05
57	50	15	4	3	nueva	\N	520500000.00	t	\N	2026-06-09 10:00:00-05	2026-06-09 10:00:00-05
58	54	16	5	4	en_seguimiento	\N	527000000.00	f	\N	2026-06-11 10:00:00-05	2026-06-11 10:00:00-05
60	26	18	7	\N	perdida	\N	540000000.00	t	2026-07-05 10:00:00-05	2026-06-15 10:00:00-05	2026-06-15 10:00:00-05
61	30	19	8	7	descartada	presupuesto insuficiente para el inmueble	546500000.00	f	\N	2026-06-17 10:00:00-05	2026-06-17 10:00:00-05
62	34	20	9	8	en_seguimiento	\N	553000000.00	f	\N	2026-06-19 10:00:00-05	2026-06-19 10:00:00-05
63	38	21	\N	9	nueva	\N	559500000.00	t	\N	2026-06-21 10:00:00-05	2026-06-21 10:00:00-05
64	42	22	4	10	en_negociacion	\N	566000000.00	f	\N	2026-06-23 10:00:00-05	2026-06-23 10:00:00-05
65	46	23	5	11	nueva	\N	572500000.00	f	\N	2026-06-25 10:00:00-05	2026-06-25 10:00:00-05
4	26	1	7	1	en_negociacion	\N	232000000.00	t	\N	2026-03-05 09:00:00-05	2026-11-14 19:34:14.042239-05
8	29	2	4	2	en_negociacion	\N	264000000.00	t	\N	2026-03-09 09:00:00-05	2026-11-14 19:34:14.042239-05
2	24	1	5	1	ganada	\N	216000000.00	t	2026-11-14 19:34:14.042239-05	2026-03-03 09:00:00-05	2026-11-14 19:34:14.042239-05
6	27	2	9	2	ganada	\N	248000000.00	t	2026-11-14 19:34:14.042239-05	2026-03-07 09:00:00-05	2026-11-14 19:34:14.042239-05
10	30	3	6	3	ganada	\N	280000000.00	t	2026-11-14 19:34:14.042239-05	2026-03-11 09:00:00-05	2026-11-14 19:34:14.042239-05
13	33	4	9	4	ganada	\N	304000000.00	f	2026-11-14 19:34:14.042239-05	2026-03-14 09:00:00-05	2026-11-14 19:34:14.042239-05
16	36	5	5	5	ganada	\N	328000000.00	t	2026-11-14 19:34:14.042239-05	2026-03-17 09:00:00-05	2026-11-14 19:34:14.042239-05
18	35	23	\N	\N	ganada	\N	267000000.00	t	2026-11-14 19:34:14.042239-05	2026-03-23 10:00:00-05	2026-11-14 19:34:14.042239-05
19	39	24	8	12	ganada	\N	273500000.00	f	2026-11-14 19:34:14.042239-05	2026-03-25 10:00:00-05	2026-11-14 19:34:14.042239-05
22	51	27	4	3	ganada	\N	293000000.00	f	2026-11-14 19:34:14.042239-05	2026-03-31 10:00:00-05	2026-11-14 19:34:14.042239-05
24	23	29	6	\N	ganada	\N	306000000.00	t	2026-11-14 19:34:14.042239-05	2026-04-04 10:00:00-05	2026-11-14 19:34:14.042239-05
27	35	32	\N	8	ganada	\N	325500000.00	t	2026-11-14 19:34:14.042239-05	2026-04-10 10:00:00-05	2026-11-14 19:34:14.042239-05
32	55	37	7	1	ganada	\N	358000000.00	f	2026-11-14 19:34:14.042239-05	2026-04-20 10:00:00-05	2026-11-14 19:34:14.042239-05
35	31	40	10	4	ganada	\N	377500000.00	f	2026-11-14 19:34:14.042239-05	2026-04-26 10:00:00-05	2026-11-14 19:34:14.042239-05
40	51	45	8	9	ganada	\N	410000000.00	f	2026-11-14 19:34:14.042239-05	2026-05-06 10:00:00-05	2026-11-14 19:34:14.042239-05
43	27	48	4	12	ganada	\N	429500000.00	f	2026-11-14 19:34:14.042239-05	2026-05-12 10:00:00-05	2026-11-14 19:34:14.042239-05
48	50	6	9	\N	ganada	\N	462000000.00	t	2026-11-14 19:34:14.042239-05	2026-05-22 10:00:00-05	2026-11-14 19:34:14.042239-05
51	26	9	5	9	ganada	\N	481500000.00	t	2026-11-14 19:34:14.042239-05	2026-05-28 10:00:00-05	2026-11-14 19:34:14.042239-05
56	46	14	10	2	ganada	\N	514000000.00	f	2026-11-14 19:34:14.042239-05	2026-06-07 10:00:00-05	2026-11-14 19:34:14.042239-05
59	22	17	6	5	ganada	\N	533500000.00	f	2026-11-14 19:34:14.042239-05	2026-06-13 10:00:00-05	2026-11-14 19:34:14.042239-05
\.


--
-- TOC entry 5343 (class 0 OID 19702)
-- Dependencies: 254
-- Data for Name: tipos_inmueble; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipos_inmueble (tipo_inmueble_id, nombre) FROM stdin;
1	apartamento
2	casa
3	local
4	lote
5	oficina
\.


--
-- TOC entry 5345 (class 0 OID 19708)
-- Dependencies: 256
-- Data for Name: tipos_operacion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipos_operacion (tipo_operacion_id, nombre) FROM stdin;
1	venta
2	arriendo
\.


--
-- TOC entry 5347 (class 0 OID 19714)
-- Dependencies: 258
-- Data for Name: tipos_persona; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipos_persona (tipo_persona_id, nombre) FROM stdin;
1	propietario
2	prospecto
\.


--
-- TOC entry 5349 (class 0 OID 19720)
-- Dependencies: 260
-- Data for Name: transacciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.transacciones (transaccion_id, oferta_id, empleado_id, valor_final, comision_porcentaje, fecha_inicio_contrato, fecha_fin_contrato, estado) FROM stdin;
1	2	5	198000000.00	3.50	2026-06-05	\N	cerrada
2	8	9	234000000.00	4.00	2026-06-09	\N	cerrada
3	14	6	270000000.00	4.50	2026-06-13	\N	cerrada
4	18	9	297000000.00	3.00	2026-06-17	\N	cerrada
5	22	5	324000000.00	3.50	2026-06-21	\N	cerrada
6	26	7	342000000.00	4.00	2026-06-25	\N	cerrada
7	27	8	346000000.00	4.50	2026-06-29	\N	cerrada
8	30	4	373000000.00	3.00	2026-07-03	\N	cerrada
9	31	6	391000000.00	3.50	2026-07-07	\N	cerrada
10	33	9	418000000.00	4.00	2026-07-11	\N	cerrada
11	37	7	463000000.00	4.50	2026-07-15	\N	cerrada
12	39	10	490000000.00	3.00	2026-07-19	\N	cerrada
13	43	8	535000000.00	3.50	2026-07-23	\N	cerrada
14	45	4	562000000.00	4.00	2026-07-27	\N	cerrada
15	49	9	607000000.00	4.50	2026-07-31	\N	cerrada
16	51	5	634000000.00	3.00	2026-08-04	\N	cerrada
17	55	10	679000000.00	3.50	2026-08-08	2027-08-08	activa
18	57	6	706000000.00	4.00	2026-08-12	\N	cerrada
\.


--
-- TOC entry 5351 (class 0 OID 19736)
-- Dependencies: 262
-- Data for Name: uso_suelo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.uso_suelo (uso_suelo_id, nombre) FROM stdin;
1	residencial
2	comercial
3	mixto
4	rural
\.


--
-- TOC entry 5353 (class 0 OID 19757)
-- Dependencies: 267
-- Data for Name: visitas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.visitas (visita_id, solicitud_id, empleado_id, fecha_programada, fecha_realizada, duracion_min, motivo_cancelacion, feedback_cliente, calificacion_interes, observaciones_empleado) FROM stdin;
1	1	4	2026-04-02 11:00:00-05	2026-04-02 12:00:00-05	36	\N	Interes alto en la zona y el precio	2	Seguimiento por WhatsApp al dia siguiente
2	1	4	2026-04-05 11:00:00-05	\N	\N	\N	\N	\N	\N
3	2	5	2026-04-03 11:00:00-05	2026-04-03 12:00:00-05	37	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
4	2	5	2026-04-06 11:00:00-05	2026-04-06 12:00:00-05	37	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
5	3	6	2026-04-04 11:00:00-05	2026-04-04 12:00:00-05	38	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
6	3	6	2026-04-07 11:00:00-05	2026-04-07 12:00:00-05	38	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
7	4	7	2026-04-05 11:00:00-05	2026-04-05 12:00:00-05	39	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
8	4	7	2026-04-08 11:00:00-05	2026-04-08 12:00:00-05	39	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
9	5	8	2026-04-06 11:00:00-05	2026-04-06 12:00:00-05	40	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
10	5	8	2026-04-09 11:00:00-05	\N	\N	\N	\N	\N	\N
11	6	9	2026-04-07 11:00:00-05	2026-04-07 12:00:00-05	41	\N	Interes alto en la zona y el precio	2	Seguimiento por WhatsApp al dia siguiente
12	6	9	2026-04-10 11:00:00-05	2026-04-10 12:00:00-05	41	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
13	7	10	2026-04-08 11:00:00-05	2026-04-08 12:00:00-05	42	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
14	7	10	2026-04-11 11:00:00-05	2026-04-11 12:00:00-05	42	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
15	8	4	2026-04-09 11:00:00-05	2026-04-09 12:00:00-05	43	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
16	8	4	2026-04-12 11:00:00-05	2026-04-12 12:00:00-05	43	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
17	9	5	2026-04-10 11:00:00-05	2026-04-10 12:00:00-05	44	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
18	9	5	2026-04-13 11:00:00-05	\N	\N	\N	\N	\N	\N
19	10	6	2026-04-11 11:00:00-05	2026-04-11 12:00:00-05	45	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
20	10	6	2026-04-14 11:00:00-05	2026-04-14 12:00:00-05	45	\N	Interes alto en la zona y el precio	2	Seguimiento por WhatsApp al dia siguiente
21	11	7	2026-04-12 11:00:00-05	2026-04-12 12:00:00-05	46	\N	Interes alto en la zona y el precio	2	Seguimiento por WhatsApp al dia siguiente
22	11	7	2026-04-15 11:00:00-05	2026-04-15 12:00:00-05	46	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
23	12	8	2026-04-13 11:00:00-05	2026-04-13 12:00:00-05	47	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
24	12	8	2026-04-16 11:00:00-05	\N	\N	\N	\N	\N	\N
25	13	9	2026-04-14 11:00:00-05	2026-04-14 12:00:00-05	48	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
26	13	9	2026-04-17 11:00:00-05	2026-04-17 12:00:00-05	48	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
27	14	10	2026-04-15 11:00:00-05	2026-04-15 12:00:00-05	49	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
28	14	10	2026-04-18 11:00:00-05	2026-04-18 12:00:00-05	49	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
29	15	4	2026-04-16 11:00:00-05	2026-04-16 12:00:00-05	50	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
30	15	4	2026-04-19 11:00:00-05	\N	\N	\N	\N	\N	\N
31	16	5	2026-04-17 11:00:00-05	2026-04-17 12:00:00-05	51	\N	Interes alto en la zona y el precio	2	Seguimiento por WhatsApp al dia siguiente
32	16	5	2026-04-20 11:00:00-05	2026-04-20 12:00:00-05	51	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
33	17	6	2026-04-18 11:00:00-05	2026-04-18 12:00:00-05	52	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
34	17	6	2026-04-21 11:00:00-05	2026-04-21 12:00:00-05	52	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
35	18	7	2026-04-19 11:00:00-05	2026-04-19 12:00:00-05	53	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
36	18	7	2026-04-22 11:00:00-05	2026-04-22 12:00:00-05	53	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
37	19	8	2026-04-20 11:00:00-05	2026-04-20 12:00:00-05	54	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
38	19	8	2026-04-23 11:00:00-05	2026-04-23 12:00:00-05	54	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
39	20	9	2026-04-21 11:00:00-05	2026-04-21 12:00:00-05	55	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
40	20	9	2026-04-24 11:00:00-05	2026-04-24 12:00:00-05	55	\N	Interes alto en la zona y el precio	2	Seguimiento por WhatsApp al dia siguiente
41	21	10	2026-04-22 11:00:00-05	2026-04-22 12:00:00-05	56	\N	Interes alto en la zona y el precio	2	Seguimiento por WhatsApp al dia siguiente
42	21	10	2026-04-25 11:00:00-05	2026-04-25 12:00:00-05	56	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
43	22	4	2026-04-23 11:00:00-05	2026-04-23 12:00:00-05	57	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
44	22	4	2026-04-26 11:00:00-05	2026-04-26 12:00:00-05	57	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
45	23	5	2026-04-24 11:00:00-05	2026-04-24 12:00:00-05	58	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
46	23	5	2026-04-27 11:00:00-05	\N	\N	\N	\N	\N	\N
47	24	6	2026-04-25 11:00:00-05	2026-04-25 12:00:00-05	59	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
48	24	6	2026-04-28 11:00:00-05	2026-04-28 12:00:00-05	59	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
49	25	7	2026-04-26 11:00:00-05	2026-04-26 12:00:00-05	60	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
50	25	7	2026-04-29 11:00:00-05	\N	\N	\N	\N	\N	\N
51	26	8	2026-04-27 11:00:00-05	2026-04-27 12:00:00-05	61	\N	Interes alto en la zona y el precio	2	Seguimiento por WhatsApp al dia siguiente
52	27	9	2026-04-28 11:00:00-05	2026-04-28 12:00:00-05	62	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
53	28	10	2026-04-29 11:00:00-05	2026-04-29 12:00:00-05	63	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
54	29	4	2026-04-30 11:00:00-05	2026-04-30 12:00:00-05	64	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
55	30	5	2026-05-01 11:00:00-05	2026-05-01 12:00:00-05	65	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
56	31	6	2026-05-02 11:00:00-05	\N	\N	\N	\N	\N	\N
57	32	7	2026-05-03 11:00:00-05	2026-05-03 12:00:00-05	67	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
58	33	8	2026-05-04 11:00:00-05	\N	\N	cliente reprogramo	\N	\N	\N
59	34	9	2026-05-05 11:00:00-05	2026-05-05 12:00:00-05	69	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
60	35	10	2026-05-06 11:00:00-05	2026-05-06 12:00:00-05	70	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
61	36	4	2026-05-07 11:00:00-05	2026-05-07 12:00:00-05	71	\N	Interes alto en la zona y el precio	2	Seguimiento por WhatsApp al dia siguiente
62	37	5	2026-05-08 11:00:00-05	2026-05-08 12:00:00-05	72	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
63	38	6	2026-05-09 11:00:00-05	2026-05-09 12:00:00-05	73	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
64	39	7	2026-05-10 11:00:00-05	\N	\N	\N	\N	\N	\N
65	40	8	2026-05-11 11:00:00-05	2026-05-11 12:00:00-05	35	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
66	41	9	2026-05-12 11:00:00-05	\N	\N	\N	\N	\N	\N
67	42	10	2026-05-13 11:00:00-05	2026-05-13 12:00:00-05	37	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
68	43	4	2026-05-14 11:00:00-05	2026-05-14 12:00:00-05	38	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
69	44	5	2026-05-15 11:00:00-05	2026-05-15 12:00:00-05	39	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
70	45	6	2026-05-16 11:00:00-05	2026-05-16 12:00:00-05	40	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
71	46	7	2026-05-17 11:00:00-05	2026-05-17 12:00:00-05	41	\N	Interes alto en la zona y el precio	2	Seguimiento por WhatsApp al dia siguiente
72	47	8	2026-05-18 11:00:00-05	\N	\N	\N	\N	\N	\N
73	48	9	2026-05-19 11:00:00-05	2026-05-19 12:00:00-05	43	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
74	49	10	2026-05-20 11:00:00-05	\N	\N	\N	\N	\N	\N
75	50	4	2026-05-21 11:00:00-05	2026-05-21 12:00:00-05	45	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
76	51	5	2026-05-22 11:00:00-05	2026-05-22 12:00:00-05	46	\N	Interes alto en la zona y el precio	2	Seguimiento por WhatsApp al dia siguiente
77	52	6	2026-05-23 11:00:00-05	2026-05-23 12:00:00-05	47	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
78	53	7	2026-05-24 11:00:00-05	2026-05-24 12:00:00-05	48	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
79	54	8	2026-05-25 11:00:00-05	2026-05-25 12:00:00-05	49	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
80	56	10	2026-05-27 11:00:00-05	2026-05-27 12:00:00-05	51	\N	Interes alto en la zona y el precio	2	Seguimiento por WhatsApp al dia siguiente
81	57	4	2026-05-28 11:00:00-05	\N	\N	\N	\N	\N	\N
82	58	5	2026-05-29 11:00:00-05	2026-05-29 12:00:00-05	53	\N	Interes alto en la zona y el precio	4	Seguimiento por WhatsApp al dia siguiente
83	59	6	2026-05-30 11:00:00-05	2026-05-30 12:00:00-05	54	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
84	60	7	2026-05-31 11:00:00-05	2026-05-31 12:00:00-05	55	\N	Interes alto en la zona y el precio	1	Seguimiento por WhatsApp al dia siguiente
85	61	8	2026-06-01 11:00:00-05	2026-06-01 12:00:00-05	56	\N	Interes alto en la zona y el precio	2	Seguimiento por WhatsApp al dia siguiente
86	62	9	2026-06-02 11:00:00-05	2026-06-02 12:00:00-05	57	\N	Interes alto en la zona y el precio	3	Seguimiento por WhatsApp al dia siguiente
87	63	10	2026-06-03 11:00:00-05	\N	\N	\N	\N	\N	\N
88	64	4	2026-06-04 11:00:00-05	2026-06-04 12:00:00-05	59	\N	Interes alto en la zona y el precio	5	Seguimiento por WhatsApp al dia siguiente
\.


--
-- TOC entry 5364 (class 0 OID 0)
-- Dependencies: 220
-- Name: acceso_via_acceso_via_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.acceso_via_acceso_via_id_seq', 3, true);


--
-- TOC entry 5365 (class 0 OID 0)
-- Dependencies: 222
-- Name: campana_propiedades_campana_propiedad_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.campana_propiedades_campana_propiedad_id_seq', 64, true);


--
-- TOC entry 5366 (class 0 OID 0)
-- Dependencies: 224
-- Name: campanas_campana_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.campanas_campana_id_seq', 12, true);


--
-- TOC entry 5367 (class 0 OID 0)
-- Dependencies: 226
-- Name: canales_marketing_canal_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.canales_marketing_canal_id_seq', 5, true);


--
-- TOC entry 5368 (class 0 OID 0)
-- Dependencies: 228
-- Name: ciudades_ciudad_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ciudades_ciudad_id_seq', 10, true);


--
-- TOC entry 5369 (class 0 OID 0)
-- Dependencies: 230
-- Name: detalle_construcciones_detalle_construccion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.detalle_construcciones_detalle_construccion_id_seq', 42, true);


--
-- TOC entry 5370 (class 0 OID 0)
-- Dependencies: 232
-- Name: detalle_terrenos_detalle_terreno_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.detalle_terrenos_detalle_terreno_id_seq', 21, true);


--
-- TOC entry 5371 (class 0 OID 0)
-- Dependencies: 234
-- Name: empleados_empleado_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.empleados_empleado_id_seq', 10, true);


--
-- TOC entry 5372 (class 0 OID 0)
-- Dependencies: 236
-- Name: estado_conservacion_estado_conservacion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.estado_conservacion_estado_conservacion_id_seq', 4, true);


--
-- TOC entry 5373 (class 0 OID 0)
-- Dependencies: 238
-- Name: ofertas_oferta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ofertas_oferta_id_seq', 61, true);


--
-- TOC entry 5374 (class 0 OID 0)
-- Dependencies: 241
-- Name: personas_persona_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.personas_persona_id_seq', 55, true);


--
-- TOC entry 5375 (class 0 OID 0)
-- Dependencies: 243
-- Name: propiedad_propietarios_propiedad_propietario_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.propiedad_propietarios_propiedad_propietario_id_seq', 65, true);


--
-- TOC entry 5376 (class 0 OID 0)
-- Dependencies: 245
-- Name: propiedades_propiedad_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.propiedades_propiedad_id_seq', 52, true);


--
-- TOC entry 5377 (class 0 OID 0)
-- Dependencies: 247
-- Name: publicacion_canales_publicacion_canal_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.publicacion_canales_publicacion_canal_id_seq', 90, true);


--
-- TOC entry 5378 (class 0 OID 0)
-- Dependencies: 249
-- Name: publicaciones_publicacion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.publicaciones_publicacion_id_seq', 60, true);


--
-- TOC entry 5379 (class 0 OID 0)
-- Dependencies: 251
-- Name: rol_empleado_rol_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rol_empleado_rol_id_seq', 3, true);


--
-- TOC entry 5380 (class 0 OID 0)
-- Dependencies: 253
-- Name: solicitudes_propiedad_solicitud_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.solicitudes_propiedad_solicitud_id_seq', 65, true);


--
-- TOC entry 5381 (class 0 OID 0)
-- Dependencies: 255
-- Name: tipos_inmueble_tipo_inmueble_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tipos_inmueble_tipo_inmueble_id_seq', 5, true);


--
-- TOC entry 5382 (class 0 OID 0)
-- Dependencies: 257
-- Name: tipos_operacion_tipo_operacion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tipos_operacion_tipo_operacion_id_seq', 2, true);


--
-- TOC entry 5383 (class 0 OID 0)
-- Dependencies: 259
-- Name: tipos_persona_tipo_persona_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tipos_persona_tipo_persona_id_seq', 2, true);


--
-- TOC entry 5384 (class 0 OID 0)
-- Dependencies: 261
-- Name: transacciones_transaccion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.transacciones_transaccion_id_seq', 19, true);


--
-- TOC entry 5385 (class 0 OID 0)
-- Dependencies: 263
-- Name: uso_suelo_uso_suelo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.uso_suelo_uso_suelo_id_seq', 4, true);


--
-- TOC entry 5386 (class 0 OID 0)
-- Dependencies: 268
-- Name: visitas_visita_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.visitas_visita_id_seq', 88, true);


--
-- TOC entry 5038 (class 2606 OID 19770)
-- Name: acceso_via pk_acceso_via; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acceso_via
    ADD CONSTRAINT pk_acceso_via PRIMARY KEY (acceso_via_id);


--
-- TOC entry 5042 (class 2606 OID 19772)
-- Name: campana_propiedades pk_campana_propiedades; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campana_propiedades
    ADD CONSTRAINT pk_campana_propiedades PRIMARY KEY (campana_propiedad_id);


--
-- TOC entry 5046 (class 2606 OID 19774)
-- Name: campanas pk_campanas; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campanas
    ADD CONSTRAINT pk_campanas PRIMARY KEY (campana_id);


--
-- TOC entry 5048 (class 2606 OID 19776)
-- Name: canales_marketing pk_canales_marketing; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.canales_marketing
    ADD CONSTRAINT pk_canales_marketing PRIMARY KEY (canal_id);


--
-- TOC entry 5052 (class 2606 OID 19778)
-- Name: ciudades pk_ciudades; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ciudades
    ADD CONSTRAINT pk_ciudades PRIMARY KEY (ciudad_id);


--
-- TOC entry 5056 (class 2606 OID 19780)
-- Name: detalle_construcciones pk_detalle_construcciones; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_construcciones
    ADD CONSTRAINT pk_detalle_construcciones PRIMARY KEY (detalle_construccion_id);


--
-- TOC entry 5060 (class 2606 OID 19782)
-- Name: detalle_terrenos pk_detalle_terrenos; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_terrenos
    ADD CONSTRAINT pk_detalle_terrenos PRIMARY KEY (detalle_terreno_id);


--
-- TOC entry 5064 (class 2606 OID 19784)
-- Name: empleados pk_empleados; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empleados
    ADD CONSTRAINT pk_empleados PRIMARY KEY (empleado_id);


--
-- TOC entry 5068 (class 2606 OID 19786)
-- Name: estado_conservacion pk_estado_conservacion; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estado_conservacion
    ADD CONSTRAINT pk_estado_conservacion PRIMARY KEY (estado_conservacion_id);


--
-- TOC entry 5072 (class 2606 OID 19788)
-- Name: ofertas pk_ofertas; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ofertas
    ADD CONSTRAINT pk_ofertas PRIMARY KEY (oferta_id);


--
-- TOC entry 5074 (class 2606 OID 19790)
-- Name: persona_roles pk_persona_roles; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persona_roles
    ADD CONSTRAINT pk_persona_roles PRIMARY KEY (persona_id, tipo_persona_id);


--
-- TOC entry 5076 (class 2606 OID 19792)
-- Name: personas pk_personas; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personas
    ADD CONSTRAINT pk_personas PRIMARY KEY (persona_id);


--
-- TOC entry 5080 (class 2606 OID 19794)
-- Name: propiedad_propietarios pk_propiedad_propietarios; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propiedad_propietarios
    ADD CONSTRAINT pk_propiedad_propietarios PRIMARY KEY (propiedad_propietario_id);


--
-- TOC entry 5084 (class 2606 OID 19796)
-- Name: propiedades pk_propiedades; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propiedades
    ADD CONSTRAINT pk_propiedades PRIMARY KEY (propiedad_id);


--
-- TOC entry 5088 (class 2606 OID 19798)
-- Name: publicacion_canales pk_publicacion_canales; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.publicacion_canales
    ADD CONSTRAINT pk_publicacion_canales PRIMARY KEY (publicacion_canal_id);


--
-- TOC entry 5092 (class 2606 OID 19800)
-- Name: publicaciones pk_publicaciones; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.publicaciones
    ADD CONSTRAINT pk_publicaciones PRIMARY KEY (publicacion_id);


--
-- TOC entry 5094 (class 2606 OID 19802)
-- Name: rol_empleado pk_rol_empleado; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rol_empleado
    ADD CONSTRAINT pk_rol_empleado PRIMARY KEY (rol_id);


--
-- TOC entry 5098 (class 2606 OID 19804)
-- Name: solicitudes_propiedad pk_solicitudes_propiedad; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_propiedad
    ADD CONSTRAINT pk_solicitudes_propiedad PRIMARY KEY (solicitud_id);


--
-- TOC entry 5100 (class 2606 OID 19806)
-- Name: tipos_inmueble pk_tipos_inmueble; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_inmueble
    ADD CONSTRAINT pk_tipos_inmueble PRIMARY KEY (tipo_inmueble_id);


--
-- TOC entry 5104 (class 2606 OID 19808)
-- Name: tipos_operacion pk_tipos_operacion; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_operacion
    ADD CONSTRAINT pk_tipos_operacion PRIMARY KEY (tipo_operacion_id);


--
-- TOC entry 5108 (class 2606 OID 19810)
-- Name: tipos_persona pk_tipos_persona; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_persona
    ADD CONSTRAINT pk_tipos_persona PRIMARY KEY (tipo_persona_id);


--
-- TOC entry 5112 (class 2606 OID 19812)
-- Name: transacciones pk_transacciones; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transacciones
    ADD CONSTRAINT pk_transacciones PRIMARY KEY (transaccion_id);


--
-- TOC entry 5116 (class 2606 OID 19814)
-- Name: uso_suelo pk_uso_suelo; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uso_suelo
    ADD CONSTRAINT pk_uso_suelo PRIMARY KEY (uso_suelo_id);


--
-- TOC entry 5120 (class 2606 OID 19816)
-- Name: visitas pk_visitas; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visitas
    ADD CONSTRAINT pk_visitas PRIMARY KEY (visita_id);


--
-- TOC entry 5040 (class 2606 OID 19818)
-- Name: acceso_via uq_acceso_via_nombre; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acceso_via
    ADD CONSTRAINT uq_acceso_via_nombre UNIQUE (nombre);


--
-- TOC entry 5044 (class 2606 OID 19820)
-- Name: campana_propiedades uq_campana_propiedades_par; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campana_propiedades
    ADD CONSTRAINT uq_campana_propiedades_par UNIQUE (campana_id, propiedad_id);


--
-- TOC entry 5050 (class 2606 OID 19822)
-- Name: canales_marketing uq_canales_marketing_nombre; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.canales_marketing
    ADD CONSTRAINT uq_canales_marketing_nombre UNIQUE (nombre);


--
-- TOC entry 5054 (class 2606 OID 19824)
-- Name: ciudades uq_ciudades_nombre; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ciudades
    ADD CONSTRAINT uq_ciudades_nombre UNIQUE (nombre);


--
-- TOC entry 5058 (class 2606 OID 19826)
-- Name: detalle_construcciones uq_detalle_construcciones_propiedad; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_construcciones
    ADD CONSTRAINT uq_detalle_construcciones_propiedad UNIQUE (propiedad_id);


--
-- TOC entry 5062 (class 2606 OID 19828)
-- Name: detalle_terrenos uq_detalle_terrenos_propiedad; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_terrenos
    ADD CONSTRAINT uq_detalle_terrenos_propiedad UNIQUE (propiedad_id);


--
-- TOC entry 5066 (class 2606 OID 19830)
-- Name: empleados uq_empleados_email; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empleados
    ADD CONSTRAINT uq_empleados_email UNIQUE (email);


--
-- TOC entry 5070 (class 2606 OID 19832)
-- Name: estado_conservacion uq_estado_conservacion_nombre; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estado_conservacion
    ADD CONSTRAINT uq_estado_conservacion_nombre UNIQUE (nombre);


--
-- TOC entry 5078 (class 2606 OID 19834)
-- Name: personas uq_personas_email; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personas
    ADD CONSTRAINT uq_personas_email UNIQUE (email);


--
-- TOC entry 5082 (class 2606 OID 19836)
-- Name: propiedad_propietarios uq_propiedad_propietarios_par; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propiedad_propietarios
    ADD CONSTRAINT uq_propiedad_propietarios_par UNIQUE (persona_id, propiedad_id);


--
-- TOC entry 5086 (class 2606 OID 19838)
-- Name: propiedades uq_propiedades_matricula; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propiedades
    ADD CONSTRAINT uq_propiedades_matricula UNIQUE (matricula_inmobiliaria);


--
-- TOC entry 5090 (class 2606 OID 19840)
-- Name: publicacion_canales uq_publicacion_canales_par; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.publicacion_canales
    ADD CONSTRAINT uq_publicacion_canales_par UNIQUE (publicacion_id, canal_id);


--
-- TOC entry 5096 (class 2606 OID 19842)
-- Name: rol_empleado uq_rol_empleado_nombre; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rol_empleado
    ADD CONSTRAINT uq_rol_empleado_nombre UNIQUE (nombre_rol);


--
-- TOC entry 5102 (class 2606 OID 19844)
-- Name: tipos_inmueble uq_tipos_inmueble_nombre; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_inmueble
    ADD CONSTRAINT uq_tipos_inmueble_nombre UNIQUE (nombre);


--
-- TOC entry 5106 (class 2606 OID 19846)
-- Name: tipos_operacion uq_tipos_operacion_nombre; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_operacion
    ADD CONSTRAINT uq_tipos_operacion_nombre UNIQUE (nombre);


--
-- TOC entry 5110 (class 2606 OID 19848)
-- Name: tipos_persona uq_tipos_persona_nombre; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_persona
    ADD CONSTRAINT uq_tipos_persona_nombre UNIQUE (nombre);


--
-- TOC entry 5114 (class 2606 OID 19850)
-- Name: transacciones uq_transacciones_oferta; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transacciones
    ADD CONSTRAINT uq_transacciones_oferta UNIQUE (oferta_id);


--
-- TOC entry 5118 (class 2606 OID 19852)
-- Name: uso_suelo uq_uso_suelo_nombre; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uso_suelo
    ADD CONSTRAINT uq_uso_suelo_nombre UNIQUE (nombre);


--
-- TOC entry 5151 (class 2620 OID 19853)
-- Name: ofertas trg_oferta_aceptada_en_negociacion; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_oferta_aceptada_en_negociacion AFTER INSERT OR UPDATE OF estado_oferta ON public.ofertas FOR EACH ROW EXECUTE FUNCTION public.fn_oferta_aceptada_en_negociacion();


--
-- TOC entry 5152 (class 2620 OID 19854)
-- Name: propiedades trg_propiedades_actualizado; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_propiedades_actualizado BEFORE UPDATE ON public.propiedades FOR EACH ROW EXECUTE FUNCTION public.fn_set_actualizado_en();


--
-- TOC entry 5153 (class 2620 OID 19855)
-- Name: publicaciones trg_publicaciones_actualizado; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_publicaciones_actualizado BEFORE UPDATE ON public.publicaciones FOR EACH ROW EXECUTE FUNCTION public.fn_set_actualizado_en();


--
-- TOC entry 5154 (class 2620 OID 19856)
-- Name: solicitudes_propiedad trg_solicitud_motivo_descarte; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_solicitud_motivo_descarte BEFORE INSERT OR UPDATE ON public.solicitudes_propiedad FOR EACH ROW EXECUTE FUNCTION public.fn_solicitud_motivo_descarte();


--
-- TOC entry 5155 (class 2620 OID 19857)
-- Name: solicitudes_propiedad trg_solicitud_no_es_dueno; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_solicitud_no_es_dueno BEFORE INSERT OR UPDATE OF persona_id, propiedad_id ON public.solicitudes_propiedad FOR EACH ROW EXECUTE FUNCTION public.fn_solicitud_no_es_dueno();


--
-- TOC entry 5156 (class 2620 OID 19858)
-- Name: solicitudes_propiedad trg_solicitudes_actualizado; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_solicitudes_actualizado BEFORE UPDATE ON public.solicitudes_propiedad FOR EACH ROW EXECUTE FUNCTION public.fn_set_actualizado_en();


--
-- TOC entry 5157 (class 2620 OID 19859)
-- Name: transacciones trg_validar_y_aplicar_transaccion; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validar_y_aplicar_transaccion BEFORE INSERT ON public.transacciones FOR EACH ROW EXECUTE FUNCTION public.fn_validar_y_aplicar_transaccion();


--
-- TOC entry 5123 (class 2606 OID 19860)
-- Name: campanas fk_campanas_canal; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campanas
    ADD CONSTRAINT fk_campanas_canal FOREIGN KEY (canal_id) REFERENCES public.canales_marketing(canal_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5121 (class 2606 OID 19865)
-- Name: campana_propiedades fk_cp_campana; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campana_propiedades
    ADD CONSTRAINT fk_cp_campana FOREIGN KEY (campana_id) REFERENCES public.campanas(campana_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- TOC entry 5122 (class 2606 OID 19870)
-- Name: campana_propiedades fk_cp_propiedad; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campana_propiedades
    ADD CONSTRAINT fk_cp_propiedad FOREIGN KEY (propiedad_id) REFERENCES public.propiedades(propiedad_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5124 (class 2606 OID 19875)
-- Name: detalle_construcciones fk_dc_estado; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_construcciones
    ADD CONSTRAINT fk_dc_estado FOREIGN KEY (estado_conservacion_id) REFERENCES public.estado_conservacion(estado_conservacion_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5125 (class 2606 OID 19880)
-- Name: detalle_construcciones fk_dc_propiedad; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_construcciones
    ADD CONSTRAINT fk_dc_propiedad FOREIGN KEY (propiedad_id) REFERENCES public.propiedades(propiedad_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- TOC entry 5126 (class 2606 OID 19885)
-- Name: detalle_terrenos fk_dt_acceso; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_terrenos
    ADD CONSTRAINT fk_dt_acceso FOREIGN KEY (acceso_via_id) REFERENCES public.acceso_via(acceso_via_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5127 (class 2606 OID 19890)
-- Name: detalle_terrenos fk_dt_propiedad; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_terrenos
    ADD CONSTRAINT fk_dt_propiedad FOREIGN KEY (propiedad_id) REFERENCES public.propiedades(propiedad_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- TOC entry 5128 (class 2606 OID 19895)
-- Name: detalle_terrenos fk_dt_uso; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_terrenos
    ADD CONSTRAINT fk_dt_uso FOREIGN KEY (uso_suelo_id) REFERENCES public.uso_suelo(uso_suelo_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5129 (class 2606 OID 19900)
-- Name: empleados fk_empleados_rol; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empleados
    ADD CONSTRAINT fk_empleados_rol FOREIGN KEY (rol_id) REFERENCES public.rol_empleado(rol_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5130 (class 2606 OID 19905)
-- Name: ofertas fk_ofertas_solicitud; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ofertas
    ADD CONSTRAINT fk_ofertas_solicitud FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_propiedad(solicitud_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- TOC entry 5139 (class 2606 OID 19910)
-- Name: publicacion_canales fk_pc_canal; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.publicacion_canales
    ADD CONSTRAINT fk_pc_canal FOREIGN KEY (canal_id) REFERENCES public.canales_marketing(canal_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5140 (class 2606 OID 19915)
-- Name: publicacion_canales fk_pc_publicacion; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.publicacion_canales
    ADD CONSTRAINT fk_pc_publicacion FOREIGN KEY (publicacion_id) REFERENCES public.publicaciones(publicacion_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- TOC entry 5131 (class 2606 OID 19920)
-- Name: persona_roles fk_persona_roles_persona; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persona_roles
    ADD CONSTRAINT fk_persona_roles_persona FOREIGN KEY (persona_id) REFERENCES public.personas(persona_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- TOC entry 5132 (class 2606 OID 19925)
-- Name: persona_roles fk_persona_roles_tipo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persona_roles
    ADD CONSTRAINT fk_persona_roles_tipo FOREIGN KEY (tipo_persona_id) REFERENCES public.tipos_persona(tipo_persona_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5133 (class 2606 OID 19930)
-- Name: personas fk_personas_ciudad; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personas
    ADD CONSTRAINT fk_personas_ciudad FOREIGN KEY (ciudad_id) REFERENCES public.ciudades(ciudad_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5134 (class 2606 OID 19935)
-- Name: propiedad_propietarios fk_pp_persona; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propiedad_propietarios
    ADD CONSTRAINT fk_pp_persona FOREIGN KEY (persona_id) REFERENCES public.personas(persona_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5135 (class 2606 OID 19940)
-- Name: propiedad_propietarios fk_pp_propiedad; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propiedad_propietarios
    ADD CONSTRAINT fk_pp_propiedad FOREIGN KEY (propiedad_id) REFERENCES public.propiedades(propiedad_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5136 (class 2606 OID 19945)
-- Name: propiedades fk_propiedades_ciudad; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propiedades
    ADD CONSTRAINT fk_propiedades_ciudad FOREIGN KEY (ciudad_id) REFERENCES public.ciudades(ciudad_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5137 (class 2606 OID 19950)
-- Name: propiedades fk_propiedades_responsable; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propiedades
    ADD CONSTRAINT fk_propiedades_responsable FOREIGN KEY (responsable_id) REFERENCES public.empleados(empleado_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5138 (class 2606 OID 19955)
-- Name: propiedades fk_propiedades_tipo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propiedades
    ADD CONSTRAINT fk_propiedades_tipo FOREIGN KEY (tipo_inmueble_id) REFERENCES public.tipos_inmueble(tipo_inmueble_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5141 (class 2606 OID 19960)
-- Name: publicaciones fk_publicaciones_propiedad; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.publicaciones
    ADD CONSTRAINT fk_publicaciones_propiedad FOREIGN KEY (propiedad_id) REFERENCES public.propiedades(propiedad_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5142 (class 2606 OID 19965)
-- Name: publicaciones fk_publicaciones_tipo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.publicaciones
    ADD CONSTRAINT fk_publicaciones_tipo FOREIGN KEY (tipo_operacion_id) REFERENCES public.tipos_operacion(tipo_operacion_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5143 (class 2606 OID 19970)
-- Name: solicitudes_propiedad fk_sol_campana; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_propiedad
    ADD CONSTRAINT fk_sol_campana FOREIGN KEY (campana_id) REFERENCES public.campanas(campana_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5144 (class 2606 OID 19975)
-- Name: solicitudes_propiedad fk_sol_empleado; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_propiedad
    ADD CONSTRAINT fk_sol_empleado FOREIGN KEY (empleado_id) REFERENCES public.empleados(empleado_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5145 (class 2606 OID 19980)
-- Name: solicitudes_propiedad fk_sol_persona; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_propiedad
    ADD CONSTRAINT fk_sol_persona FOREIGN KEY (persona_id) REFERENCES public.personas(persona_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5146 (class 2606 OID 19985)
-- Name: solicitudes_propiedad fk_sol_propiedad; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_propiedad
    ADD CONSTRAINT fk_sol_propiedad FOREIGN KEY (propiedad_id) REFERENCES public.propiedades(propiedad_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5147 (class 2606 OID 19990)
-- Name: transacciones fk_transacciones_empleado; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transacciones
    ADD CONSTRAINT fk_transacciones_empleado FOREIGN KEY (empleado_id) REFERENCES public.empleados(empleado_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5148 (class 2606 OID 19995)
-- Name: transacciones fk_transacciones_oferta; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transacciones
    ADD CONSTRAINT fk_transacciones_oferta FOREIGN KEY (oferta_id) REFERENCES public.ofertas(oferta_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- TOC entry 5149 (class 2606 OID 20000)
-- Name: visitas fk_visitas_empleado; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visitas
    ADD CONSTRAINT fk_visitas_empleado FOREIGN KEY (empleado_id) REFERENCES public.empleados(empleado_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 5150 (class 2606 OID 20005)
-- Name: visitas fk_visitas_solicitud; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visitas
    ADD CONSTRAINT fk_visitas_solicitud FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_propiedad(solicitud_id) ON UPDATE RESTRICT ON DELETE CASCADE;


-- Completed on 2026-11-17 15:11:22

--
-- PostgreSQL database dump complete
--

\unrestrict qZiw7Bu6C0lGHbQqtfF06ts40lOAbA0mIeVfAhvpiCtJgvkRiEmcDICbZt9NsBg


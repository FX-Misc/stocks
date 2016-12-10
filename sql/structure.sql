--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.4
-- Dumped by pg_dump version 9.5.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: part; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE part AS ENUM (
    'w1',
    'w2',
    'w3',
    'w4',
    'w5',
    'a',
    'b',
    'c',
    'd',
    'e',
    'w',
    'x',
    'y',
    'x2',
    'z'
);


--
-- Name: wave; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE wave AS ENUM (
    'impulse',
    'leading',
    'ending',
    'correction',
    'zigzag',
    'flat',
    'triangle',
    'combo',
    'triple'
);


--
-- Name: f_comm(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION f_comm(qua bigint) RETURNS numeric
    LANGUAGE sql
    AS $$
SELECT GREATEST(1.5, qua * .005);
$$;


--
-- Name: f_comm_qua(numeric, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION f_comm_qua(amt numeric, dist numeric) RETURNS bigint
    LANGUAGE sql
    AS $$
SELECT CASE
       WHEN dist > 0
         THEN FLOOR(LEAST((amt - 1.5) / dist, amt / (dist + 0.005))) :: BIGINT
       ELSE CEIL(GREATEST((amt - 1.5) / dist, amt / (dist - 0.005))) :: BIGINT
       END
$$;


--
-- Name: f_corrections(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION f_corrections() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  ru INT DEFAULT 1;
BEGIN

    UPDATE
      waves
    SET
      wave = 'correction'::wave
    FROM
      waves w
      JOIN waves sw ON
                      w.symbol = sw.symbol
                      AND w.id != sw.id
                      AND sw.start_dt >= w.start_dt
                      AND sw.finish_dt <= w.finish_dt
                      AND w.degree = sw.degree + 1
    WHERE
      w.id = waves.id
      AND w.wave = 'impulse'
      AND sw.part = 'b';

    WHILE ru != 0 LOOP
        WITH times AS (
        UPDATE
          waves
        SET
          wave = CASE
                 WHEN sw.wave IN ('impulse', 'leading', 'ending')
                   THEN 'zigzag' :: wave
                 ELSE 'flat' :: wave
                 END
        FROM
          waves w
          JOIN waves sw ON
                          w.symbol = sw.symbol
                          AND w.id != sw.id
                          AND sw.start_dt >= w.start_dt
                          AND sw.finish_dt <= w.finish_dt
                          AND w.degree = sw.degree + 1
        WHERE
          w.id = waves.id
          AND w.wave = 'correction'
          AND sw.part = 'a'
        RETURNING 1
      )
      SELECT count(*) INTO ru from times;
    END LOOP;
END
$$;


--
-- Name: f_pos_adj(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION f_pos_adj(risk_balance numeric) RETURNS TABLE(symbol integer, qua bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(c.symbol, n.symbol)            AS symbol,
    COALESCE(n.qua, 0) - COALESCE(c.qua, 0) AS adjust
  FROM
    positions c
    FULL OUTER JOIN f_pos_next(risk_balance) n ON c.symbol = n.symbol
  WHERE
    COALESCE(n.qua, 0) - COALESCE(c.qua, 0) != 0;
END;
$$;


--
-- Name: f_pos_next(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION f_pos_next(risk_balance numeric) RETURNS TABLE(symbol integer, qua bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  WITH risk_curr AS (
    SELECT
      s.symbol,
      ABS(p.qua * (sl-price)) risk_curr,
      p.qua curr_qua
    FROM
      v_sltp s
      LEFT JOIN positions p ON p.symbol = s.symbol
  ), risk_dist AS (
    SELECT
      s.symbol,
      CASE
          WHEN bid > sl THEN ask - sl
          ELSE bid - sl
      END risk_dist
    FROM
      v_sltp s
      LEFT JOIN symbols q ON s.symbol = q.id
    WHERE
      s.sl IS NOT NULL AND s.tp IS NOT NULL
  ), calc AS (
    SELECT
      s.symbol,
      COALESCE(CASE
        WHEN risk_fut.risk > risk_curr THEN f_comm_qua(risk_fut.risk - risk_curr, risk_dist) + curr_qua
        WHEN risk_fut.risk < risk_curr THEN trunc(curr_qua * risk_fut.risk / risk_curr)::BIGINT
        WHEN risk_fut.risk = risk_curr THEN curr_qua
      END, f_comm_qua(risk_fut.risk, risk_dist)) qua
    FROM
      v_sltp s
      LEFT JOIN f_risk(risk_balance) risk_fut ON s.symbol = risk_fut.symbol
      LEFT JOIN risk_curr ON s.symbol = risk_curr.symbol
      LEFT JOIN risk_dist ON s.symbol = risk_dist.symbol
    WHERE
      sl IS NOT NULL AND tp IS NOT NULL
  )
  SELECT
    calc.symbol,
    calc.qua
  FROM
      calc
  WHERE
    calc.qua != 0;
END;
$$;


--
-- Name: f_risk(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION f_risk(risk_balance numeric) RETURNS TABLE(symbol integer, risk numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.symbol,
    trunc(risk_balance * s.lvg / SUM(s.lvg) OVER ()) risk
  FROM
    v_sltp s
  WHERE
    sl IS NOT NULL AND tp IS NOT NULL;
END;
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: degrees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE degrees (
    id integer NOT NULL,
    title character varying(50) NOT NULL
);


--
-- Name: COLUMN degrees.title; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN degrees.title IS 'EWA degrees';


--
-- Name: degrees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE degrees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: degrees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE degrees_id_seq OWNED BY degrees.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE orders (
    id character varying(50) NOT NULL,
    symbol integer NOT NULL,
    price numeric NOT NULL,
    qua integer NOT NULL
);


--
-- Name: positions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE positions (
    symbol integer NOT NULL,
    qua integer NOT NULL,
    price numeric NOT NULL
);


--
-- Name: TABLE positions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE positions IS 'Positions';


--
-- Name: sltp; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sltp (
    symbol integer NOT NULL,
    dt timestamp with time zone DEFAULT now() NOT NULL,
    sl numeric(10,5),
    tp numeric(10,5),
    lvg numeric DEFAULT 1 NOT NULL
);


--
-- Name: symbols; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE symbols (
    id integer NOT NULL,
    title character varying(10) NOT NULL,
    bid numeric,
    ask numeric
);


--
-- Name: TABLE symbols; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE symbols IS 'Symbols';


--
-- Name: symbols_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE symbols_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: symbols_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE symbols_id_seq OWNED BY symbols.id;


--
-- Name: v_pnl; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW v_pnl AS
 SELECT p.symbol,
    s.title,
        CASE
            WHEN (p.qua > 0) THEN ((p.qua)::numeric * (s.bid - p.price))
            ELSE ((p.qua)::numeric * (s.ask - p.price))
        END AS pnl
   FROM (positions p
     LEFT JOIN symbols s ON ((p.symbol = s.id)));


--
-- Name: v_sltp; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW v_sltp AS
 SELECT DISTINCT ON (sltp.symbol) sltp.symbol,
    sltp.sl,
    sltp.tp,
    sltp.lvg
   FROM sltp
  ORDER BY sltp.symbol, sltp.dt DESC;


--
-- Name: waves; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE waves (
    id integer NOT NULL,
    symbol integer NOT NULL,
    mw_id integer DEFAULT 0 NOT NULL,
    mw_parent integer NOT NULL,
    degree integer NOT NULL,
    wave wave,
    part part,
    start_dt timestamp without time zone NOT NULL,
    start_price numeric NOT NULL,
    finish_dt timestamp without time zone,
    finish_price numeric
);


--
-- Name: waves_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE waves_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: waves_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE waves_id_seq OWNED BY waves.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY degrees ALTER COLUMN id SET DEFAULT nextval('degrees_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY symbols ALTER COLUMN id SET DEFAULT nextval('symbols_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY waves ALTER COLUMN id SET DEFAULT nextval('waves_id_seq'::regclass);


--
-- Name: degrees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY degrees
    ADD CONSTRAINT degrees_pkey PRIMARY KEY (id);


--
-- Name: orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: positions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY positions
    ADD CONSTRAINT positions_pkey PRIMARY KEY (symbol);


--
-- Name: symbols_id_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY symbols
    ADD CONSTRAINT symbols_id_pk PRIMARY KEY (id);


--
-- Name: waves_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY waves
    ADD CONSTRAINT waves_pkey PRIMARY KEY (id);


--
-- Name: degrees_title_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX degrees_title_uindex ON degrees USING btree (title);


--
-- Name: symbols_title_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX symbols_title_uindex ON symbols USING btree (title);


--
-- Name: waves_start_dt_start_price_finish_price_finish_dt_symbol_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX waves_start_dt_start_price_finish_price_finish_dt_symbol_uindex ON waves USING btree (start_dt, start_price, finish_price, finish_dt, symbol);


--
-- Name: positions_symbols_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY positions
    ADD CONSTRAINT positions_symbols_id_fk FOREIGN KEY (symbol) REFERENCES symbols(id);


--
-- Name: sltp_symbols_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sltp
    ADD CONSTRAINT sltp_symbols_id_fk FOREIGN KEY (symbol) REFERENCES symbols(id);


--
-- Name: trades_symbols_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY orders
    ADD CONSTRAINT trades_symbols_id_fk FOREIGN KEY (symbol) REFERENCES symbols(id);


--
-- Name: waves_degrees_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY waves
    ADD CONSTRAINT waves_degrees_id_fk FOREIGN KEY (degree) REFERENCES degrees(id);


--
-- Name: waves_symbols_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY waves
    ADD CONSTRAINT waves_symbols_id_fk FOREIGN KEY (symbol) REFERENCES symbols(id);


--
-- PostgreSQL database dump complete
--


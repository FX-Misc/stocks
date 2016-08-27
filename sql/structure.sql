--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.1
-- Dumped by pg_dump version 9.5.1

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
    v_pos c
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
      v_sltp.symbol,
      ABS(v_pos.qua * (sl-price)) risk_curr,
      v_pos.qua curr_qua
    FROM
      v_sltp
      LEFT JOIN v_pos ON v_pos.symbol = v_sltp.symbol
  ), risk_dist AS (
    SELECT
      s.symbol,
      CASE
          WHEN bid > sl THEN ask - sl
          ELSE bid - sl
      END risk_dist
    FROM
      v_sltp s
      LEFT JOIN v_quotes q ON s.symbol = q.symbol
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
-- Name: quotes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE quotes (
    id integer NOT NULL,
    symbol integer NOT NULL,
    dt timestamp with time zone NOT NULL,
    bid numeric NOT NULL,
    ask numeric
);


--
-- Name: TABLE quotes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE quotes IS 'Time series';


--
-- Name: quotes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE quotes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quotes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE quotes_id_seq OWNED BY quotes.id;


--
-- Name: sltp; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sltp (
    symbol integer NOT NULL,
    dt timestamp with time zone DEFAULT now() NOT NULL,
    sl numeric(10,5) NOT NULL,
    tp numeric(10,5),
    lvg numeric DEFAULT 1 NOT NULL
);


--
-- Name: symbols; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE symbols (
    id integer NOT NULL,
    title character varying(10) NOT NULL
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
-- Name: trades; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE trades (
    id character varying(50) NOT NULL,
    symbol integer NOT NULL,
    dt timestamp with time zone NOT NULL,
    price numeric NOT NULL,
    qua integer NOT NULL,
    comm numeric DEFAULT 0 NOT NULL
);


--
-- Name: trades_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE trades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE trades_id_seq OWNED BY trades.id;


--
-- Name: v_pos; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW v_pos AS
 WITH RECURSIVE pos AS (
         SELECT starting.id,
            starting.symbol,
            starting.dt,
            starting.price,
            starting.qua,
            starting.comm,
            starting.pnl,
            starting.pos,
            starting.p_price
           FROM ( SELECT DISTINCT ON (t.symbol) t.id,
                    t.symbol,
                    t.dt,
                    t.price,
                    t.qua,
                    t.comm,
                    (0)::numeric AS pnl,
                    t.qua AS pos,
                    t.price AS p_price
                   FROM trades t
                  ORDER BY t.symbol, t.dt) starting
        UNION ALL
         SELECT n.id,
            n.symbol,
            n.dt,
            n.price,
            n.qua,
            n.comm,
            c.pnl,
            (p.pos + n.qua),
                CASE
                    WHEN ((p.pos > 0) AND (n.qua > 0)) THEN (((p.p_price * (p.pos)::numeric) + (n.price * (n.qua)::numeric)) / ((p.pos + n.qua))::numeric)
                    WHEN ((p.pos < 0) AND (n.qua < 0)) THEN (((p.p_price * (p.pos)::numeric) + (n.price * (n.qua)::numeric)) / ((p.pos + n.qua))::numeric)
                    WHEN (((p.pos / n.qua) < 0) AND (p.pos > n.qua)) THEN p.p_price
                    WHEN (((p.pos / n.qua) < 0) AND (p.pos < n.qua)) THEN n.price
                    ELSE (0)::numeric
                END AS "case"
           FROM pos p,
            LATERAL ( SELECT t.id,
                    t.symbol,
                    t.dt,
                    t.price,
                    t.qua,
                    t.comm
                   FROM trades t
                  WHERE ((t.symbol = p.symbol) AND (t.dt > p.dt))
                  ORDER BY t.dt
                 LIMIT 1) n,
            LATERAL ( SELECT
                        CASE
                            WHEN ((p.pos < 0) AND (n.qua > 0) AND ((- p.pos) > n.qua)) THEN ((n.qua)::numeric * (p.p_price - n.price))
                            WHEN ((p.pos < 0) AND (n.qua > 0) AND ((- p.pos) < n.qua)) THEN ((p.pos)::numeric * (p.p_price - n.price))
                            WHEN ((p.pos > 0) AND (n.qua < 0) AND (p.pos > (- n.qua))) THEN ((n.qua)::numeric * (p.p_price - n.price))
                            WHEN ((p.pos > 0) AND (n.qua < 0) AND (p.pos < (- n.qua))) THEN ((p.pos)::numeric * (p.p_price - n.price))
                            ELSE (0)::numeric
                        END AS pnl,
                    ((p.pos)::numeric * p.price) AS cb) c
        )
 SELECT tmp.symbol,
    (tmp.qua)::bigint AS qua,
    tmp.price
   FROM ( SELECT DISTINCT ON (pos.symbol) pos.symbol,
            pos.pos AS qua,
            pos.p_price AS price
           FROM pos
          WHERE (pos.qua <> 0)
          ORDER BY pos.symbol, pos.dt DESC) tmp
  WHERE (tmp.qua <> 0);


--
-- Name: v_quotes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW v_quotes AS
 SELECT DISTINCT ON (quotes.symbol) quotes.symbol,
    quotes.bid,
    quotes.ask
   FROM quotes
  ORDER BY quotes.symbol, quotes.dt DESC;


--
-- Name: v_pnl; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW v_pnl AS
 SELECT p.symbol,
        CASE
            WHEN (p.qua > 0) THEN ((p.qua)::numeric * (q.bid - p.price))
            ELSE ((p.qua)::numeric * (q.ask - p.price))
        END AS pnl
   FROM (v_pos p
     LEFT JOIN v_quotes q ON ((p.symbol = q.symbol)));


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

ALTER TABLE ONLY quotes ALTER COLUMN id SET DEFAULT nextval('quotes_id_seq'::regclass);


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
-- Name: quotes_id_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY quotes
    ADD CONSTRAINT quotes_id_pk PRIMARY KEY (id);


--
-- Name: symbols_id_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY symbols
    ADD CONSTRAINT symbols_id_pk PRIMARY KEY (id);


--
-- Name: trades_id_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY trades
    ADD CONSTRAINT trades_id_pk PRIMARY KEY (id);


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
-- Name: quotes_symbols_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY quotes
    ADD CONSTRAINT quotes_symbols_id_fk FOREIGN KEY (symbol) REFERENCES symbols(id);


--
-- Name: sltp_symbols_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sltp
    ADD CONSTRAINT sltp_symbols_id_fk FOREIGN KEY (symbol) REFERENCES symbols(id);


--
-- Name: trades_symbols_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY trades
    ADD CONSTRAINT trades_symbols_id_fk FOREIGN KEY (symbol) REFERENCES symbols(id);


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


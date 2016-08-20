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
    degree integer NOT NULL,
    start integer NOT NULL,
    finish integer
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
-- Name: waves_ts_id2_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY waves
    ADD CONSTRAINT waves_ts_id2_fk FOREIGN KEY (finish) REFERENCES quotes(id);


--
-- Name: waves_ts_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY waves
    ADD CONSTRAINT waves_ts_id_fk FOREIGN KEY (start) REFERENCES quotes(id);


--
-- PostgreSQL database dump complete
--


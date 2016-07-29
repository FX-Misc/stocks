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
-- Name: f_pos_adj(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION f_pos_adj(risk_balance numeric) RETURNS TABLE(symbol character varying, qua bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(c.symbol, n.symbol)            AS symbol,
    COALESCE(n.qua, 0) - COALESCE(c.qua, 0) AS adjust
  FROM
    v_pos c
    FULL JOIN f_pos_next(risk_balance) n ON c.symbol = n.symbol;
END;
$$;


--
-- Name: f_pos_next(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION f_pos_next(risk_balance numeric) RETURNS TABLE(symbol character varying, qua integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.symbol,
    ROUND(risk_balance / (q.bid - s.sl) / count(*) OVER ())::INT AS qua
  FROM
    v_sltp s
    JOIN v_quotes q ON s.symbol = q.symbol
  WHERE
    s.sl IS NOT NULL AND s.tp IS NOT NULL;
END;
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: quotes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE quotes (
    symbol character varying(10) NOT NULL,
    bid numeric NOT NULL,
    ask numeric NOT NULL,
    dt timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sltp; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sltp (
    dt timestamp with time zone DEFAULT now() NOT NULL,
    symbol character varying(10) NOT NULL,
    sl numeric,
    tp numeric
);


--
-- Name: trades; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE trades (
    id character varying(255) NOT NULL,
    symbol character varying(10) NOT NULL,
    price numeric NOT NULL,
    qua integer NOT NULL,
    comm numeric NOT NULL,
    dt timestamp with time zone
);


--
-- Name: v_pos; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW v_pos AS
 SELECT trades.symbol,
    sum(trades.qua) AS qua,
    (sum(((trades.qua)::numeric * trades.price)) / (sum(trades.qua))::numeric) AS price,
    ((sum(((trades.qua)::numeric * trades.price)) + ((2)::numeric * sum(trades.comm))) / (sum(trades.qua))::numeric) AS price_be,
    sum(trades.comm) AS comm
   FROM trades
  GROUP BY trades.symbol
 HAVING (sum(trades.qua) <> 0);


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
    p.qua,
    p.price,
    p.price_be,
    p.comm,
    q.bid,
    q.ask,
    (
        CASE
            WHEN (p.qua > 0) THEN (q.bid - p.price_be)
            ELSE (q.ask - p.price_be)
        END * (p.qua)::numeric) AS pnl
   FROM (v_pos p
     LEFT JOIN v_quotes q ON (((p.symbol)::text = (q.symbol)::text)));


--
-- Name: v_sltp; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW v_sltp AS
 SELECT DISTINCT ON (sltp.symbol) sltp.dt,
    sltp.symbol,
    sltp.sl,
    sltp.tp
   FROM sltp
  ORDER BY sltp.symbol, sltp.dt DESC;


--
-- Name: v_rr; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW v_rr AS
 SELECT p.symbol,
    p.qua,
    p.price,
    p.price_be,
    p.comm,
    s.sl,
    s.tp,
        CASE
            WHEN (p.qua > 0) THEN ((s.sl - p.price_be) * (p.qua)::numeric)
            ELSE ((s.sl - p.price_be) * (p.qua)::numeric)
        END AS risk,
        CASE
            WHEN (p.qua > 0) THEN ((s.tp - p.price_be) * (p.qua)::numeric)
            ELSE ((s.tp - p.price_be) * (p.qua)::numeric)
        END AS reward
   FROM (v_pos p
     LEFT JOIN v_sltp s ON (((p.symbol)::text = (s.symbol)::text)));


--
-- Name: v_trades; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW v_trades AS
 SELECT t.id,
    t.symbol,
    t.price,
    t.qua,
    t.comm,
    t.dt
   FROM ( SELECT trades.id,
            trades.symbol,
            trades.price,
            trades.qua,
            trades.comm,
            trades.dt,
            sum(trades.qua) OVER (PARTITION BY trades.symbol) AS pos_now
           FROM trades) t
  WHERE (t.pos_now <> 0);


--
-- Name: trades_id_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY trades
    ADD CONSTRAINT trades_id_pk PRIMARY KEY (id);


--
-- Name: quotes_symbol_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX quotes_symbol_index ON quotes USING btree (symbol);


--
-- Name: sltp_symbol_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sltp_symbol_index ON sltp USING btree (symbol);


--
-- Name: trades_symbol_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trades_symbol_index ON trades USING btree (symbol);


--
-- PostgreSQL database dump complete
--


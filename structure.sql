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
    FULL OUTER JOIN f_pos_next(risk_balance) n ON c.symbol = n.symbol
  WHERE
    COALESCE(n.qua, 0) - COALESCE(c.qua, 0) != 0;
END;
$$;


--
-- Name: f_pos_next(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION f_pos_next(risk_balance numeric) RETURNS TABLE(symbol character varying, qua bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  WITH risk_curr AS (
    SELECT
      v_pos.symbol,
       ABS(v_pos.qua * (sl-price)) risk_curr,
      v_pos.qua curr_qua
    FROM
      v_pos
      LEFT JOIN v_sltp ON v_pos.symbol = v_sltp.symbol
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

CREATE FUNCTION f_risk(risk_balance numeric) RETURNS TABLE(symbol character varying, risk numeric)
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
    tp numeric,
    lvg numeric DEFAULT 1 NOT NULL
);


--
-- Name: trades; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE trades (
    id character varying(255) NOT NULL,
    symbol character varying(10) NOT NULL,
    price numeric NOT NULL,
    qua integer NOT NULL,
    dt timestamp with time zone,
    comm numeric DEFAULT 0 NOT NULL
);


--
-- Name: v_pos; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW v_pos AS
 WITH RECURSIVE pos AS (
         SELECT starting.id,
            starting.symbol,
            starting.price,
            starting.qua,
            starting.dt,
            starting.comm,
            starting.pnl,
            starting.pos,
            starting.p_price
           FROM ( SELECT DISTINCT ON (t.symbol) t.id,
                    t.symbol,
                    t.price,
                    t.qua,
                    t.dt,
                    t.comm,
                    (0)::numeric AS pnl,
                    t.qua AS pos,
                    t.price AS p_price
                   FROM trades t
                  ORDER BY t.symbol, t.dt) starting
        UNION ALL
         SELECT n.id,
            n.symbol,
            n.price,
            n.qua,
            n.dt,
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
                    t.price,
                    t.qua,
                    t.dt,
                    t.comm
                   FROM trades t
                  WHERE (((t.symbol)::text = (p.symbol)::text) AND (t.dt > p.dt))
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
     LEFT JOIN v_quotes q ON (((p.symbol)::text = (q.symbol)::text)));


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


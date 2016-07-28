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
-- Name: plcoffee; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plcoffee WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plcoffee; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plcoffee IS 'PL/CoffeeScript (v8) trusted procedural language';


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
-- Name: quotes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE quotes (
    symbol character varying(10) NOT NULL,
    bid numeric NOT NULL,
    ask numeric NOT NULL,
    dt timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: lq; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW lq AS
 SELECT DISTINCT ON (quotes.symbol) quotes.symbol,
    quotes.bid,
    quotes.ask
   FROM quotes
  ORDER BY quotes.symbol, quotes.dt DESC;


--
-- Name: sltp; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sltp (
    dt timestamp with time zone DEFAULT now() NOT NULL,
    symbol character varying(10) NOT NULL,
    sl numeric NOT NULL,
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


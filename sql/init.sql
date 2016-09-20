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

SET search_path = public, pg_catalog;

--
-- Data for Name: degrees; Type: TABLE DATA; Schema: public; Owner: -
--

COPY degrees (id, title) FROM stdin;
1	PICO
2	SUBNANO
3	NANO
4	MINISCULE
5	SUBMICRO
6	MICRO
7	SUBMINUETTE
8	MINUETTE
9	MINUTE
10	MINOR
11	INTERMEDIATE
12	PRIMARY
\.


--
-- Name: degrees_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('degrees_id_seq', 12, true);


--
-- PostgreSQL database dump complete
--


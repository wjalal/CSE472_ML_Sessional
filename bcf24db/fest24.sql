--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4
-- Dumped by pg_dump version 16.4 (Debian 16.4-1.pgdg120+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: Event; Type: TABLE; Schema: public; Owner: doadmin
--

CREATE TABLE public."Event" (
    id text NOT NULL,
    name text,
    "registrationLink" text,
    "ruleBookLink" text,
    "discordLink" text,
    "kaggleLink" text
);


ALTER TABLE public."Event" OWNER TO doadmin;

--
-- Name: PrizeMoney; Type: TABLE; Schema: public; Owner: doadmin
--

CREATE TABLE public."PrizeMoney" (
    id text NOT NULL,
    label text,
    prize text,
    "eventId" text
);


ALTER TABLE public."PrizeMoney" OWNER TO doadmin;

--
-- Name: TimeLine; Type: TABLE; Schema: public; Owner: doadmin
--

CREATE TABLE public."TimeLine" (
    id text NOT NULL,
    event text,
    location text,
    date text,
    "eventId" text
);


ALTER TABLE public."TimeLine" OWNER TO doadmin;

--
-- Name: _prisma_migrations; Type: TABLE; Schema: public; Owner: doadmin
--

CREATE TABLE public._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


ALTER TABLE public._prisma_migrations OWNER TO doadmin;

--
-- Data for Name: Event; Type: TABLE DATA; Schema: public; Owner: doadmin
--

COPY public."Event" (id, name, "registrationLink", "ruleBookLink", "discordLink", "kaggleLink") FROM stdin;
\.


--
-- Data for Name: PrizeMoney; Type: TABLE DATA; Schema: public; Owner: doadmin
--

COPY public."PrizeMoney" (id, label, prize, "eventId") FROM stdin;
\.


--
-- Data for Name: TimeLine; Type: TABLE DATA; Schema: public; Owner: doadmin
--

COPY public."TimeLine" (id, event, location, date, "eventId") FROM stdin;
\.


--
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: doadmin
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
baa39a40-c463-4063-8fdf-5dde22391331	47aceadf6606d32b299b06bfb50ebaef18206730e72f8c85561df1c328e9bfcd	2024-09-29 06:43:14.306243+00	20240929064313_	\N	\N	2024-09-29 06:43:14.037861+00	1
\.


--
-- Name: Event Event_pkey; Type: CONSTRAINT; Schema: public; Owner: doadmin
--

ALTER TABLE ONLY public."Event"
    ADD CONSTRAINT "Event_pkey" PRIMARY KEY (id);


--
-- Name: PrizeMoney PrizeMoney_pkey; Type: CONSTRAINT; Schema: public; Owner: doadmin
--

ALTER TABLE ONLY public."PrizeMoney"
    ADD CONSTRAINT "PrizeMoney_pkey" PRIMARY KEY (id);


--
-- Name: TimeLine TimeLine_pkey; Type: CONSTRAINT; Schema: public; Owner: doadmin
--

ALTER TABLE ONLY public."TimeLine"
    ADD CONSTRAINT "TimeLine_pkey" PRIMARY KEY (id);


--
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: doadmin
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- Name: PrizeMoney PrizeMoney_eventId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: doadmin
--

ALTER TABLE ONLY public."PrizeMoney"
    ADD CONSTRAINT "PrizeMoney_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES public."Event"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: TimeLine TimeLine_eventId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: doadmin
--

ALTER TABLE ONLY public."TimeLine"
    ADD CONSTRAINT "TimeLine_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES public."Event"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--


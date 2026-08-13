SET session_replication_role = replica;

--
-- PostgreSQL database dump
--

-- \restrict je3wCjwLuqjbruStJhpMh2QzDvmKDbnS2OViBvbkzoBIwkXI3Pq8hUMt3eGDSi8

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

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
-- Data for Name: groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."groups" ("id", "created_at", "name", "description") VALUES
	('42c7e606-9c28-4fa3-9eb2-8a4e2fc704ae', '2026-02-26 16:14:40.325214+00', 'Beginners', 'Every new user starts as a member in beginners group.'),
	('9aadabb4-7f75-4d8e-8df3-74f0afd617cd', '2026-05-28 10:18:16.864993+00', 'Sandbox', 'A group that exists just for testing purposes.');


--
-- Data for Name: userprofiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."userprofiles" ("id", "created_at", "firstname", "lastname", "nickname") VALUES
	('4c43fe8a-08f3-4f05-bc36-8d38f17ad9d4', '2026-05-26 13:24:09.00069+00', 'Yewa', 'Pop', 'ypop'),
	('96e061c7-7506-42aa-91c6-b627c5952d7d', '2026-02-27 14:49:33.629197+00', 'Silento', 'Sharko', 'SilentShark42'),


-- Set ypop, SilentShark to group admins.
INSERT INTO "public"."privileges" ("id", "created_at", "is_group_admin") VALUES
	('4c43fe8a-08f3-4f05-bc36-8d38f17ad9d4', '2026-05-26 13:24:09.00069+00', true),


--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."memberships" ("id", "joined_at", "groupid", "userid") VALUES
	('d1e79737-fe5e-48b5-89fb-369cb5a3e78f', '2026-05-26 13:26:30.657403+00', '42c7e606-9c28-4fa3-9eb2-8a4e2fc704ae', '4c43fe8a-08f3-4f05-bc36-8d38f17ad9d4'),
	('72b57909-90ed-4850-b252-cd83ca815a81', '2026-05-28 11:13:10.922148+00', '9aadabb4-7f75-4d8e-8df3-74f0afd617cd', '96e061c7-7506-42aa-91c6-b627c5952d7d'),


--
-- Data for Name: photometadata; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- PostgreSQL database dump complete
--

-- \unrestrict je3wCjwLuqjbruStJhpMh2QzDvmKDbnS2OViBvbkzoBIwkXI3Pq8hUMt3eGDSi8

RESET ALL;

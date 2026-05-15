--
-- PostgreSQL database dump
--

\restrict boLNS7PWUnAYqcD6HCRgddwuqEvw0uYMbBFofgkj7an2rWObnxXh6QfDurJd7J1

-- Dumped from database version 18.2
-- Dumped by pg_dump version 18.2

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documents (
    id text NOT NULL,
    project_id text,
    project_address text,
    name text NOT NULL,
    mime_type text,
    size_bytes bigint,
    version integer DEFAULT 1 NOT NULL,
    type text,
    storage_path text NOT NULL,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL,
    uploaded_by text,
    client_user_id text
);


--
-- Name: finance_expenses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finance_expenses (
    id text NOT NULL,
    project_id text NOT NULL,
    created_by text,
    category text NOT NULL,
    amount double precision DEFAULT 0 NOT NULL,
    expense_date date NOT NULL,
    note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: home_assistant_connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.home_assistant_connections (
    id text NOT NULL,
    user_id text NOT NULL,
    house_id text,
    base_url text NOT NULL,
    access_token text NOT NULL,
    refresh_token text NOT NULL,
    client_id text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    status text DEFAULT 'connected'::text NOT NULL,
    last_checked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: journal_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journal_entries (
    id text NOT NULL,
    project_id text NOT NULL,
    entry_type text NOT NULL,
    description text NOT NULL,
    specialist text,
    entry_date date NOT NULL,
    photo_url text,
    created_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: maintenance_notification_hidden; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.maintenance_notification_hidden (
    task_id text NOT NULL,
    user_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: maintenance_request_notification_hidden; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.maintenance_request_notification_hidden (
    request_id text NOT NULL,
    user_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: maintenance_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.maintenance_requests (
    id text NOT NULL,
    project_id text NOT NULL,
    task_id text,
    client_user_id text,
    system_type text,
    description text,
    preferred_date date,
    specialist_name text,
    status text DEFAULT 'new'::text NOT NULL,
    created_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: maintenance_tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.maintenance_tasks (
    id text NOT NULL,
    project_id text NOT NULL,
    title text NOT NULL,
    notes text,
    scheduled_date date NOT NULL,
    status text DEFAULT 'scheduled'::text NOT NULL,
    created_by text,
    completed_at timestamp with time zone,
    completed_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    system_type text,
    specialist_name text,
    report_notes text,
    report_photo_url text
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id text NOT NULL,
    client_fio text NOT NULL,
    client_contacts text,
    client_email text,
    client_user_id text,
    construction_address text NOT NULL,
    project_type text NOT NULL,
    area_sqm double precision DEFAULT 0 NOT NULL,
    estimated_cost double precision DEFAULT 0 NOT NULL,
    contract_amount double precision,
    paid_amount double precision,
    next_payment_date text,
    last_payment_date text,
    status text NOT NULL,
    start_date text,
    planned_end_date text,
    actual_end_date text,
    camera_url text,
    stages jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    client_phone text,
    thumbnail_url text,
    materials text
);


--
-- Name: stage_comment_notification_hidden; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stage_comment_notification_hidden (
    notification_id text NOT NULL,
    user_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: stage_comment_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stage_comment_notifications (
    id text NOT NULL,
    client_user_id text NOT NULL,
    project_id text NOT NULL,
    stage_id text NOT NULL,
    stage_name text NOT NULL,
    comment_text text NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: support_message_notification_hidden; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.support_message_notification_hidden (
    message_id text NOT NULL,
    user_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: support_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.support_messages (
    id text NOT NULL,
    client_user_id text NOT NULL,
    sender_user_id text NOT NULL,
    message_text text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_read_by_admin boolean DEFAULT false NOT NULL
);


--
-- Name: user_push_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_push_tokens (
    id text NOT NULL,
    user_id text NOT NULL,
    token text NOT NULL,
    platform text DEFAULT 'unknown'::text NOT NULL,
    app_version text,
    locale text,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id text NOT NULL,
    email text NOT NULL,
    password_hash text NOT NULL,
    fio text NOT NULL,
    role text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_archived boolean DEFAULT false NOT NULL,
    avatar_url text,
    two_factor_enabled boolean DEFAULT false NOT NULL,
    two_factor_secret text
);


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.documents (id, project_id, project_address, name, mime_type, size_bytes, version, type, storage_path, uploaded_at, uploaded_by, client_user_id) FROM stdin;
664bb7da-fd7b-4276-b7f3-cc4ae05d8c93	\N		Рассадка МФЗ - основная трибуна.docx	application/vnd.openxmlformats-officedocument.wordprocessingml.document	12945	1	Проект	/uploads/documents/1774557966953-f2a1eaa6-b1dd-4ac3-8d28-38f2fbd036f0.docx	2026-03-27 00:46:07.118323+04	828b8ac4-5120-42e7-adb4-482c371e3712	6651e321-d1a7-42ba-b88b-524e844c3e4a
92ce25b9-6984-490f-9090-d9b8a16a46d1	\N		Дом120кв Новый проект.pdf	application/pdf	91256	1	Сертификаты	/uploads/documents/1774558058242-ad5fa994-c93b-4802-b664-3c0e313ba145.pdf	2026-03-27 00:47:38.25821+04	828b8ac4-5120-42e7-adb4-482c371e3712	6651e321-d1a7-42ba-b88b-524e844c3e4a
d88c1746-9ebf-4895-9808-b0f93c093e3a	\N		ChatGPT Image 2 мая 2026 г.pdf	application/pdf	158785	1	Проект	/uploads/documents/1778292346031-eaf78ee0-9d89-4e6c-b10c-c2765662781c.pdf	2026-05-09 06:05:46.105749+04	828b8ac4-5120-42e7-adb4-482c371e3712	6651e321-d1a7-42ba-b88b-524e844c3e4a
\.


--
-- Data for Name: finance_expenses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.finance_expenses (id, project_id, created_by, category, amount, expense_date, note, created_at) FROM stdin;
\.


--
-- Data for Name: home_assistant_connections; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.home_assistant_connections (id, user_id, house_id, base_url, access_token, refresh_token, client_id, expires_at, status, last_checked_at, created_at, updated_at) FROM stdin;
da4b8b43-afb7-4a80-b1d5-f769b2cb769e	6651e321-d1a7-42ba-b88b-524e844c3e4a	\N	http://192.168.180.128:8123	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIxNDE1NzM2NDFkMTk0ODQ0OTAzNDE3YWY1ZTYyMjQ1NyIsImlhdCI6MTc3ODQxMzY5NCwiZXhwIjoxNzc4NDE1NDk0fQ.rih60-jnGcA5cZ6jOsuUiYvojpv4EPrRf2WqHlIXAX4	0f0ebd64e4263b8f7be929f175afa9304b5ebf3665aad01c73f218f076546d820c83bf52811225ffd636d6bb0ebcc3fc92f4c97c394020d8b661ff6feb8af802	http://192.168.0.109:4000/ha-oauth-client	2026-05-10 15:18:32.525+04	connected	2026-05-10 14:48:32.527038+04	2026-05-10 09:09:51.412287+04	2026-05-10 14:48:32.527038+04
\.


--
-- Data for Name: journal_entries; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.journal_entries (id, project_id, entry_type, description, specialist, entry_date, photo_url, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: maintenance_notification_hidden; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.maintenance_notification_hidden (task_id, user_id, created_at) FROM stdin;
\.


--
-- Data for Name: maintenance_request_notification_hidden; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.maintenance_request_notification_hidden (request_id, user_id, created_at) FROM stdin;
\.


--
-- Data for Name: maintenance_requests; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.maintenance_requests (id, project_id, task_id, client_user_id, system_type, description, preferred_date, specialist_name, status, created_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: maintenance_tasks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.maintenance_tasks (id, project_id, title, notes, scheduled_date, status, created_by, completed_at, completed_by, created_at, system_type, specialist_name, report_notes, report_photo_url) FROM stdin;
\.


--
-- Data for Name: projects; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.projects (id, client_fio, client_contacts, client_email, client_user_id, construction_address, project_type, area_sqm, estimated_cost, contract_amount, paid_amount, next_payment_date, last_payment_date, status, start_date, planned_end_date, actual_end_date, camera_url, stages, created_at, updated_at, client_phone, thumbnail_url, materials) FROM stdin;
c19848a3-ab96-45da-aa0d-2433f36d8f1f	Смирнов Илья Иванович	jhkhjghkghkhgjkhjg	reunion@mail.ru	6651e321-d1a7-42ba-b88b-524e844c3e4a	hjfhgjghhjkg	hgfjhgfg	0	0	0	0	\N	\N	in_progress	2026-03-31	2026-03-26	\N	\N	[{"id": "stage-1", "name": "Подготовка участка", "status": "not_started", "comments": "ебланfsdfssdf", "photoUrls": ["/uploads/stage-photos/1778303846772-7994fc59-72ca-406a-b533-116329ae61e5.png", "/uploads/stage-photos/1778303846784-c70fe139-d3e5-4f3c-b027-01580aa5fbf7.png", "/uploads/stage-photos/1778303846790-f3300fa4-1e4b-4322-83db-d97cda105c59.jpg", "/uploads/stage-photos/1778303852663-be67e50a-1efa-4c7f-ac04-e238009b0c6d.png", "/uploads/stage-photos/1778303911705-eb9d68d7-c467-40f0-981f-b2b25df2320a.png", "/uploads/stage-photos/1778303911705-a321a2c7-70c0-4afd-8b63-02f83b98d874.png", "/uploads/stage-photos/1778303911718-9b8fb110-0343-45cc-afe5-57b0f6e3adf1.png", "/uploads/stage-photos/1778303911723-40d24c47-e095-4d5a-a0b6-8dc2ead79039.jpg"], "plannedEnd": "2026-03-31", "plannedStart": "2026-03-09", "stageComment": "andrey"}, {"id": "stage-2", "name": "Подготовка участка", "status": "in_progress", "comments": "jhgjhgh", "photoUrls": ["/uploads/stage-photos/1778200680699-4ed3707f-ce83-4e84-84ee-2739ba944728.png"], "plannedEnd": "2026-05-30", "plannedStart": "2026-05-22", "stageComment": "hghjg"}, {"id": "stage-3", "name": "Стены", "status": "in_progress", "comments": "hhfdhпаапр", "photoUrls": ["/uploads/stage-photos/1778304528328-89d50f2c-7553-44f2-bc55-e50e8df782c7.png", "/uploads/stage-photos/1778306071283-a0283d2f-ec9f-49ae-907a-3bb36410badb.png", "/uploads/stage-photos/1778306071283-58c90ae2-d141-4e61-9bfa-743333f1b198.png", "/uploads/stage-photos/1778306071290-9a858d4e-37ba-4378-9a9b-e3b01ffd37d9.png"], "plannedEnd": "2026-05-31", "plannedStart": "2026-05-09", "stageComment": "jgjhh"}, {"id": "stage-4", "name": "Кровля", "status": "in_progress", "comments": "gdggdgsd", "photoUrls": ["/uploads/stage-photos/1778305862212-e31ecf4b-b990-4ca2-8e28-51b8b370739d.png"], "plannedEnd": "2026-05-31", "plannedStart": "2026-05-26", "stageComment": "gdfgdg"}]	2026-03-27 00:42:58.606+04	2026-05-09 09:54:34.529+04	jhkhjghkghkhgjkhjg	\N	hjgjkh
\.


--
-- Data for Name: stage_comment_notification_hidden; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.stage_comment_notification_hidden (notification_id, user_id, created_at) FROM stdin;
\.


--
-- Data for Name: stage_comment_notifications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.stage_comment_notifications (id, client_user_id, project_id, stage_id, stage_name, comment_text, is_read, created_at) FROM stdin;
eccc4faf-4f74-47c4-8030-04e4665d4bfb	6651e321-d1a7-42ba-b88b-524e844c3e4a	c19848a3-ab96-45da-aa0d-2433f36d8f1f	stage-1	Подготовка участка	andrey	t	2026-03-27 00:43:45.382874+04
87b9c31c-e4ad-4185-befb-c9568f361593	6651e321-d1a7-42ba-b88b-524e844c3e4a	c19848a3-ab96-45da-aa0d-2433f36d8f1f	stage-2	Подготовка участка	hghjg	t	2026-05-08 04:37:17.706429+04
3af8ebe8-7508-41c2-8afa-e0b059154b1a	6651e321-d1a7-42ba-b88b-524e844c3e4a	c19848a3-ab96-45da-aa0d-2433f36d8f1f	stage-3	Стены	jgjhh	t	2026-05-09 09:09:15.377559+04
fa5540ad-16ae-4b18-ba5f-982457ab9d94	6651e321-d1a7-42ba-b88b-524e844c3e4a	c19848a3-ab96-45da-aa0d-2433f36d8f1f	stage-4	Кровля	gdfgdg	t	2026-05-09 09:46:53.365388+04
88f76202-1d9d-4833-8def-e43822d54497	6651e321-d1a7-42ba-b88b-524e844c3e4a	c19848a3-ab96-45da-aa0d-2433f36d8f1f	stage-4	Кровля	Добавлено фото: +1	t	2026-05-09 09:51:02.241667+04
bd3e8ff5-338d-478d-9459-374a77d0a120	6651e321-d1a7-42ba-b88b-524e844c3e4a	c19848a3-ab96-45da-aa0d-2433f36d8f1f	stage-3	Стены	Добавлено фото: +3	t	2026-05-09 09:54:31.301954+04
\.


--
-- Data for Name: support_message_notification_hidden; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.support_message_notification_hidden (message_id, user_id, created_at) FROM stdin;
\.


--
-- Data for Name: support_messages; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.support_messages (id, client_user_id, sender_user_id, message_text, created_at, is_read_by_admin) FROM stdin;
cec1ab20-12f8-4f03-9d28-4a183566e692	6651e321-d1a7-42ba-b88b-524e844c3e4a	828b8ac4-5120-42e7-adb4-482c371e3712	hjkggkhgh	2026-03-13 00:53:43.474735+04	t
552f1bfe-9196-4fa5-831f-ee75788be0e3	6651e321-d1a7-42ba-b88b-524e844c3e4a	6651e321-d1a7-42ba-b88b-524e844c3e4a	памагите	2026-03-12 15:29:42.158713+04	t
c4bd9786-ef0a-425d-97c3-bd190a702660	6651e321-d1a7-42ba-b88b-524e844c3e4a	6651e321-d1a7-42ba-b88b-524e844c3e4a	пососи	2026-03-12 15:52:35.534731+04	t
b2eaccb5-5b4a-4fbb-a387-42784da263ec	6651e321-d1a7-42ba-b88b-524e844c3e4a	6651e321-d1a7-42ba-b88b-524e844c3e4a	kflyj	2026-03-12 17:11:50.4429+04	t
7ac37b31-339c-4a71-adf9-23ac564c964b	6651e321-d1a7-42ba-b88b-524e844c3e4a	6651e321-d1a7-42ba-b88b-524e844c3e4a	hjgjgh	2026-03-13 00:47:31.754406+04	t
7d86f073-e760-413c-9652-8dc675c3c686	6651e321-d1a7-42ba-b88b-524e844c3e4a	6651e321-d1a7-42ba-b88b-524e844c3e4a	😂😂😂😂😂	2026-03-13 00:53:25.981679+04	t
bdff8026-e7e4-46ca-8ee1-41c125ccc208	6651e321-d1a7-42ba-b88b-524e844c3e4a	6651e321-d1a7-42ba-b88b-524e844c3e4a	jhfgkjgh	2026-03-13 01:05:31.783993+04	t
72d56f7c-327b-45d5-95a9-317f17f02a7d	6651e321-d1a7-42ba-b88b-524e844c3e4a	6651e321-d1a7-42ba-b88b-524e844c3e4a	🫠🫠	2026-05-10 05:10:59.864043+04	f
948dc912-3f68-45e4-b5e5-71078891839f	6651e321-d1a7-42ba-b88b-524e844c3e4a	6651e321-d1a7-42ba-b88b-524e844c3e4a	ээййй тыыы	2026-05-10 08:07:25.143526+04	f
3c073548-263a-4c86-95e3-2bdea1b8a944	6651e321-d1a7-42ba-b88b-524e844c3e4a	828b8ac4-5120-42e7-adb4-482c371e3712	чем	2026-03-12 15:31:29.033759+04	t
9ec59f57-9d9c-41ec-b91f-6943c033d1b8	6651e321-d1a7-42ba-b88b-524e844c3e4a	828b8ac4-5120-42e7-adb4-482c371e3712	нет	2026-03-12 15:53:19.365894+04	t
36b29946-1567-475e-9cee-9d24a3d6a9ea	6651e321-d1a7-42ba-b88b-524e844c3e4a	828b8ac4-5120-42e7-adb4-482c371e3712	сам соси	2026-03-12 15:53:32.331751+04	t
\.


--
-- Data for Name: user_push_tokens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_push_tokens (id, user_id, token, platform, app_version, locale, last_seen_at, created_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, email, password_hash, fio, role, created_at, is_active, is_archived, avatar_url, two_factor_enabled, two_factor_secret) FROM stdin;
828b8ac4-5120-42e7-adb4-482c371e3712	admin@admin.ru	$2a$10$m82WbHhbVsSzvB5uk3Mtjue7ecOdeTj62wHHtN8DhlI40udu0Ps9i	Администратор	admin	2026-02-19 20:44:41.682167+04	t	f	/uploads/avatars/1778204458850-3f0401a7-f5ef-472a-a045-ba64d374c68f.png	f	\N
6651e321-d1a7-42ba-b88b-524e844c3e4a	reunion@mail.ru	$2a$10$J/9hh4x/K.wzkePFkzLUNeP7vXmLRdLK5zlKhHkgc8yO/vRENR7eC	Смирнов Илья Иванович	client	2026-03-12 15:07:16.280347+04	t	f	/uploads/avatars/1773316809962-29f6a4cf-f8c3-4926-b114-c953709773ef.jpg	f	HRYFMAIRP5YCMZYV
\.


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: finance_expenses finance_expenses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_expenses
    ADD CONSTRAINT finance_expenses_pkey PRIMARY KEY (id);


--
-- Name: home_assistant_connections home_assistant_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.home_assistant_connections
    ADD CONSTRAINT home_assistant_connections_pkey PRIMARY KEY (id);


--
-- Name: home_assistant_connections home_assistant_connections_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.home_assistant_connections
    ADD CONSTRAINT home_assistant_connections_user_id_key UNIQUE (user_id);


--
-- Name: journal_entries journal_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entries
    ADD CONSTRAINT journal_entries_pkey PRIMARY KEY (id);


--
-- Name: maintenance_notification_hidden maintenance_notification_hidden_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_notification_hidden
    ADD CONSTRAINT maintenance_notification_hidden_pkey PRIMARY KEY (task_id, user_id);


--
-- Name: maintenance_request_notification_hidden maintenance_request_notification_hidden_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_request_notification_hidden
    ADD CONSTRAINT maintenance_request_notification_hidden_pkey PRIMARY KEY (request_id, user_id);


--
-- Name: maintenance_requests maintenance_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_requests
    ADD CONSTRAINT maintenance_requests_pkey PRIMARY KEY (id);


--
-- Name: maintenance_tasks maintenance_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_tasks
    ADD CONSTRAINT maintenance_tasks_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: stage_comment_notification_hidden stage_comment_notification_hidden_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_comment_notification_hidden
    ADD CONSTRAINT stage_comment_notification_hidden_pkey PRIMARY KEY (notification_id, user_id);


--
-- Name: stage_comment_notifications stage_comment_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_comment_notifications
    ADD CONSTRAINT stage_comment_notifications_pkey PRIMARY KEY (id);


--
-- Name: support_message_notification_hidden support_message_notification_hidden_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.support_message_notification_hidden
    ADD CONSTRAINT support_message_notification_hidden_pkey PRIMARY KEY (message_id, user_id);


--
-- Name: support_messages support_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.support_messages
    ADD CONSTRAINT support_messages_pkey PRIMARY KEY (id);


--
-- Name: user_push_tokens user_push_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_push_tokens
    ADD CONSTRAINT user_push_tokens_pkey PRIMARY KEY (id);


--
-- Name: user_push_tokens user_push_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_push_tokens
    ADD CONSTRAINT user_push_tokens_token_key UNIQUE (token);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_documents_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_documents_project_id ON public.documents USING btree (project_id);


--
-- Name: idx_finance_expenses_expense_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_finance_expenses_expense_date ON public.finance_expenses USING btree (expense_date);


--
-- Name: idx_finance_expenses_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_finance_expenses_project_id ON public.finance_expenses USING btree (project_id);


--
-- Name: idx_home_assistant_connections_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_home_assistant_connections_user_id ON public.home_assistant_connections USING btree (user_id);


--
-- Name: idx_journal_entries_entry_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_journal_entries_entry_date ON public.journal_entries USING btree (entry_date);


--
-- Name: idx_journal_entries_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_journal_entries_project_id ON public.journal_entries USING btree (project_id);


--
-- Name: idx_maintenance_notification_hidden_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_maintenance_notification_hidden_user_id ON public.maintenance_notification_hidden USING btree (user_id);


--
-- Name: idx_maintenance_request_notification_hidden_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_maintenance_request_notification_hidden_user_id ON public.maintenance_request_notification_hidden USING btree (user_id);


--
-- Name: idx_maintenance_requests_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_maintenance_requests_project_id ON public.maintenance_requests USING btree (project_id);


--
-- Name: idx_maintenance_requests_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_maintenance_requests_status ON public.maintenance_requests USING btree (status);


--
-- Name: idx_maintenance_tasks_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_maintenance_tasks_project_id ON public.maintenance_tasks USING btree (project_id);


--
-- Name: idx_maintenance_tasks_scheduled_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_maintenance_tasks_scheduled_date ON public.maintenance_tasks USING btree (scheduled_date);


--
-- Name: idx_projects_client_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projects_client_user_id ON public.projects USING btree (client_user_id);


--
-- Name: idx_stage_comment_notification_hidden_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stage_comment_notification_hidden_user_id ON public.stage_comment_notification_hidden USING btree (user_id);


--
-- Name: idx_stage_comment_notifications_client_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stage_comment_notifications_client_user_id ON public.stage_comment_notifications USING btree (client_user_id);


--
-- Name: idx_stage_comment_notifications_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stage_comment_notifications_created_at ON public.stage_comment_notifications USING btree (created_at);


--
-- Name: idx_stage_comment_notifications_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stage_comment_notifications_project_id ON public.stage_comment_notifications USING btree (project_id);


--
-- Name: idx_support_message_notification_hidden_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_support_message_notification_hidden_user_id ON public.support_message_notification_hidden USING btree (user_id);


--
-- Name: idx_support_messages_client_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_support_messages_client_user_id ON public.support_messages USING btree (client_user_id);


--
-- Name: idx_support_messages_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_support_messages_created_at ON public.support_messages USING btree (created_at);


--
-- Name: idx_user_push_tokens_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_push_tokens_user_id ON public.user_push_tokens USING btree (user_id);


--
-- Name: documents documents_client_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_client_user_id_fkey FOREIGN KEY (client_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: documents documents_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: documents documents_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: finance_expenses finance_expenses_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_expenses
    ADD CONSTRAINT finance_expenses_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: finance_expenses finance_expenses_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_expenses
    ADD CONSTRAINT finance_expenses_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: home_assistant_connections home_assistant_connections_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.home_assistant_connections
    ADD CONSTRAINT home_assistant_connections_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: journal_entries journal_entries_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entries
    ADD CONSTRAINT journal_entries_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: journal_entries journal_entries_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entries
    ADD CONSTRAINT journal_entries_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: maintenance_notification_hidden maintenance_notification_hidden_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_notification_hidden
    ADD CONSTRAINT maintenance_notification_hidden_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.maintenance_tasks(id) ON DELETE CASCADE;


--
-- Name: maintenance_notification_hidden maintenance_notification_hidden_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_notification_hidden
    ADD CONSTRAINT maintenance_notification_hidden_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: maintenance_request_notification_hidden maintenance_request_notification_hidden_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_request_notification_hidden
    ADD CONSTRAINT maintenance_request_notification_hidden_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.maintenance_requests(id) ON DELETE CASCADE;


--
-- Name: maintenance_request_notification_hidden maintenance_request_notification_hidden_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_request_notification_hidden
    ADD CONSTRAINT maintenance_request_notification_hidden_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: maintenance_requests maintenance_requests_client_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_requests
    ADD CONSTRAINT maintenance_requests_client_user_id_fkey FOREIGN KEY (client_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: maintenance_requests maintenance_requests_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_requests
    ADD CONSTRAINT maintenance_requests_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: maintenance_requests maintenance_requests_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_requests
    ADD CONSTRAINT maintenance_requests_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: maintenance_requests maintenance_requests_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_requests
    ADD CONSTRAINT maintenance_requests_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.maintenance_tasks(id) ON DELETE SET NULL;


--
-- Name: maintenance_tasks maintenance_tasks_completed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_tasks
    ADD CONSTRAINT maintenance_tasks_completed_by_fkey FOREIGN KEY (completed_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: maintenance_tasks maintenance_tasks_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_tasks
    ADD CONSTRAINT maintenance_tasks_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: maintenance_tasks maintenance_tasks_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_tasks
    ADD CONSTRAINT maintenance_tasks_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: projects projects_client_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_client_user_id_fkey FOREIGN KEY (client_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: stage_comment_notification_hidden stage_comment_notification_hidden_notification_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_comment_notification_hidden
    ADD CONSTRAINT stage_comment_notification_hidden_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES public.stage_comment_notifications(id) ON DELETE CASCADE;


--
-- Name: stage_comment_notification_hidden stage_comment_notification_hidden_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_comment_notification_hidden
    ADD CONSTRAINT stage_comment_notification_hidden_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: stage_comment_notifications stage_comment_notifications_client_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_comment_notifications
    ADD CONSTRAINT stage_comment_notifications_client_user_id_fkey FOREIGN KEY (client_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: stage_comment_notifications stage_comment_notifications_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_comment_notifications
    ADD CONSTRAINT stage_comment_notifications_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: support_message_notification_hidden support_message_notification_hidden_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.support_message_notification_hidden
    ADD CONSTRAINT support_message_notification_hidden_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.support_messages(id) ON DELETE CASCADE;


--
-- Name: support_message_notification_hidden support_message_notification_hidden_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.support_message_notification_hidden
    ADD CONSTRAINT support_message_notification_hidden_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: support_messages support_messages_client_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.support_messages
    ADD CONSTRAINT support_messages_client_user_id_fkey FOREIGN KEY (client_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: support_messages support_messages_sender_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.support_messages
    ADD CONSTRAINT support_messages_sender_user_id_fkey FOREIGN KEY (sender_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_push_tokens user_push_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_push_tokens
    ADD CONSTRAINT user_push_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict boLNS7PWUnAYqcD6HCRgddwuqEvw0uYMbBFofgkj7an2rWObnxXh6QfDurJd7J1


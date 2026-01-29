--
-- PostgreSQL database dump
--

\restrict jXJ0wvkwL6JbPY9XvizxdvJag2OyryKLlt9XYtGbsWFDkmHaRxvzyMVOHNZazdc

-- Dumped from database version 17.7 (Homebrew)
-- Dumped by pg_dump version 17.7 (Homebrew)

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
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_users (
    id uuid NOT NULL,
    role character varying(255) DEFAULT 'member'::character varying NOT NULL,
    user_id uuid NOT NULL,
    account_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255),
    status character varying(255) DEFAULT 'active'::character varying NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: api_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_keys (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(255) DEFAULT 'public'::character varying NOT NULL,
    token_prefix character varying(255) NOT NULL,
    token_hash character varying(255) NOT NULL,
    status character varying(255) DEFAULT 'active'::character varying NOT NULL,
    last_used_at timestamp(0) without time zone,
    expires_at timestamp(0) without time zone,
    account_user_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    scopes character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL
);


--
-- Name: issues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.issues (
    id uuid NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    type character varying(20) NOT NULL,
    status character varying(20) DEFAULT 'new'::character varying NOT NULL,
    priority character varying(20) DEFAULT 'medium'::character varying NOT NULL,
    submitter_email character varying(255),
    project_id uuid NOT NULL,
    submitter_id uuid NOT NULL,
    archived_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    number integer NOT NULL
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    account_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    prefix character varying(255) NOT NULL,
    issue_counter integer DEFAULT 1
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    email public.citext NOT NULL,
    hashed_password character varying(255),
    confirmed_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: users_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token bytea NOT NULL,
    context character varying(255) NOT NULL,
    sent_to character varying(255),
    authenticated_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: account_users account_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_users
    ADD CONSTRAINT account_users_pkey PRIMARY KEY (id);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: api_keys api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);


--
-- Name: issues issues_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issues
    ADD CONSTRAINT issues_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users_tokens users_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens
    ADD CONSTRAINT users_tokens_pkey PRIMARY KEY (id);


--
-- Name: account_users_account_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX account_users_account_id_index ON public.account_users USING btree (account_id);


--
-- Name: account_users_user_id_account_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX account_users_user_id_account_id_index ON public.account_users USING btree (user_id, account_id);


--
-- Name: account_users_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX account_users_user_id_index ON public.account_users USING btree (user_id);


--
-- Name: accounts_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX accounts_slug_index ON public.accounts USING btree (slug);


--
-- Name: api_keys_account_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_keys_account_user_id_index ON public.api_keys USING btree (account_user_id);


--
-- Name: api_keys_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_keys_status_index ON public.api_keys USING btree (status);


--
-- Name: api_keys_token_hash_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX api_keys_token_hash_index ON public.api_keys USING btree (token_hash);


--
-- Name: api_keys_token_prefix_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_keys_token_prefix_index ON public.api_keys USING btree (token_prefix);


--
-- Name: issues_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issues_project_id_index ON public.issues USING btree (project_id);


--
-- Name: issues_project_id_number_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX issues_project_id_number_index ON public.issues USING btree (project_id, number);


--
-- Name: issues_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issues_status_index ON public.issues USING btree (status);


--
-- Name: issues_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issues_type_index ON public.issues USING btree (type);


--
-- Name: projects_account_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_account_id_index ON public.projects USING btree (account_id);


--
-- Name: projects_account_id_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX projects_account_id_name_index ON public.projects USING btree (account_id, name);


--
-- Name: projects_account_id_prefix_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX projects_account_id_prefix_index ON public.projects USING btree (account_id, prefix);


--
-- Name: users_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_index ON public.users USING btree (email);


--
-- Name: users_tokens_context_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_tokens_context_token_index ON public.users_tokens USING btree (context, token);


--
-- Name: users_tokens_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_tokens_user_id_index ON public.users_tokens USING btree (user_id);


--
-- Name: account_users account_users_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_users
    ADD CONSTRAINT account_users_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- Name: account_users account_users_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_users
    ADD CONSTRAINT account_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: api_keys api_keys_account_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_account_user_id_fkey FOREIGN KEY (account_user_id) REFERENCES public.account_users(id) ON DELETE CASCADE;


--
-- Name: issues issues_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issues
    ADD CONSTRAINT issues_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE RESTRICT;


--
-- Name: issues issues_submitter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.issues
    ADD CONSTRAINT issues_submitter_id_fkey FOREIGN KEY (submitter_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: projects projects_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- Name: users_tokens users_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens
    ADD CONSTRAINT users_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict jXJ0wvkwL6JbPY9XvizxdvJag2OyryKLlt9XYtGbsWFDkmHaRxvzyMVOHNZazdc

INSERT INTO public."schema_migrations" (version) VALUES (20260127132805);
INSERT INTO public."schema_migrations" (version) VALUES (20260127132930);
INSERT INTO public."schema_migrations" (version) VALUES (20260127132931);
INSERT INTO public."schema_migrations" (version) VALUES (20260127132932);
INSERT INTO public."schema_migrations" (version) VALUES (20260127143419);
INSERT INTO public."schema_migrations" (version) VALUES (20260127163826);
INSERT INTO public."schema_migrations" (version) VALUES (20260127165000);
INSERT INTO public."schema_migrations" (version) VALUES (20260127165749);
INSERT INTO public."schema_migrations" (version) VALUES (20260127191110);
INSERT INTO public."schema_migrations" (version) VALUES (20260127200000);
INSERT INTO public."schema_migrations" (version) VALUES (20260127221202);
INSERT INTO public."schema_migrations" (version) VALUES (20260127235420);
INSERT INTO public."schema_migrations" (version) VALUES (20260129161314);
INSERT INTO public."schema_migrations" (version) VALUES (20260129161315);
INSERT INTO public."schema_migrations" (version) VALUES (20260129161316);
INSERT INTO public."schema_migrations" (version) VALUES (20260129161317);

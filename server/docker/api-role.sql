-- The API's own login: table data only, so a compromised API cannot change the
-- schema, read server files or reach other roles. Runs after every migrate,
-- which also covers new tables and databases restored without their grants.
\set ON_ERROR_STOP on
\set VERBOSITY terse
\getenv api_password API_PASSWORD

SELECT 'CREATE ROLE rune_nexus_api'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rune_nexus_api') \gexec

ALTER ROLE rune_nexus_api WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
    NOREPLICATION NOBYPASSRLS PASSWORD :'api_password';

GRANT CONNECT ON DATABASE :"DBNAME" TO rune_nexus_api;
GRANT USAGE ON SCHEMA public TO rune_nexus_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO rune_nexus_api;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rune_nexus_api;
REVOKE ALL ON public.schema_version FROM rune_nexus_api;

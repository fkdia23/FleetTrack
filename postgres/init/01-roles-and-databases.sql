SET log_statement = 'none';
SET log_min_duration_statement = -1;

\set ON_ERROR_STOP on
\set app_pw `cat /run/secrets/app_db_password`
\set kc_pw `cat /run/secrets/keycloak_db_password`
\set gf_pw `cat /run/secrets/grafana_db_password`

CREATE ROLE fleettrack_app LOGIN PASSWORD :'app_pw';
CREATE ROLE keycloak_app   LOGIN PASSWORD :'kc_pw';
CREATE ROLE grafana_ro     LOGIN PASSWORD :'gf_pw';

CREATE DATABASE fleettrack OWNER fleettrack_app;
CREATE DATABASE keycloak   OWNER keycloak_app;

REVOKE ALL ON DATABASE fleettrack FROM PUBLIC;
REVOKE ALL ON DATABASE keycloak   FROM PUBLIC;
GRANT CONNECT ON DATABASE fleettrack TO grafana_ro;

\connect fleettrack

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO grafana_ro;
ALTER DEFAULT PRIVILEGES FOR ROLE fleettrack_app IN SCHEMA public
  GRANT SELECT ON TABLES TO grafana_ro;

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
-- Written by the recipe postgresql-database-and-role. Values arrive as psql variables, which psql quotes (:"x" is an
-- identifier, :'x' a string): none of them is pasted into SQL text.
\set ON_ERROR_STOP on
\set VERBOSITY terse
\set role '${role}'
\set database '${database}'

-- The password reaches the server inside ALTER ROLE. Nothing of this session may be logged, whatever the server's own
-- settings say (log_statement = 'all', log_min_duration_statement = 0, a failing statement): no statement, no duration,
-- no statement text in an error. The password itself is read from its file, never typed here.
SET log_statement = 'none';
SET log_min_duration_statement = -1;
SET log_min_error_statement = panic;
SET log_duration = off;
\set pw `cat /usr/local/etc/pgsetup/${database}.password`

-- an empty password would remove the password: stop instead
SELECT length(:'pw') = 0 AS no_password \gset
\if :no_password
  SELECT 1/0 AS "the password file is empty";
\endif

SELECT NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'role') AS role_missing \gset
\if :role_missing
  CREATE ROLE :"role" LOGIN;
\endif
ALTER ROLE :"role" WITH LOGIN PASSWORD :'pw';

SELECT NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'database') AS database_missing \gset
\if :database_missing
  CREATE DATABASE :"database" OWNER :"role";
\endif

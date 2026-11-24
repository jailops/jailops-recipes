# postgresql-database-and-role

One database, one role that owns it, and the rule that lets that role connect from one network. Applied again with other values it adds the next database; each has files of its own.

Title: PostgreSQL database and role
Summary: One database, the role that owns it, and the rule that lets that role connect from one network; apply again for the next database.
Category: Databases
Requires JailOps >= 0.9.5.

## When to use

- An application needs its own database and its own login. Also to **rotate the password** of an existing role: apply again with the new password.

## Assumes

- A server set up by `small-postgresql-server` (or any PostgreSQL 16 or later whose `pg_hba.conf` has the line `include_dir pg_hba.d`). The recipe checks the line and stops with the reason if it is missing,
  so a rule is never written where the server would not read it.
- `database` and `role` are plain names: letters, digits and `_`. Anything else is refused before something is written.
- The password is a file on the machine where you run `jailops`; it is a secret variable and appears only in a file in the jail. If a step fails, JailOps withholds the output of every step of the run
  (it could contain the password), so the report names the step and its exit status only. To read the reason, run the SQL by hand: `jailops exec db -- su postgres -c 'psql -X -f /usr/local/etc/pgsetup/DATABASE.sql'` (the file holds no password; it does what the step does, including setting the password).

## Infrastructure

None. The firewall policy of the server jail must let the client reach port 5432.

## Apply

    cp recipes/postgresql-database-and-role/config.example appdb.vars       # database, role, client_network
    jailops jail apply db -f recipes/postgresql-database-and-role/ --dry-run --vars appdb.vars --set-file db_password=appdb.secret
    jailops jail apply db -f recipes/postgresql-database-and-role/ --vars appdb.vars --set-file db_password=appdb.secret

`db_password` is a secret variable: only `--set-file`, never on the command line and never in `appdb.vars`.

## What it does

| In the jail | What |
|---|---|
| `/usr/local/etc/pgsetup/DATABASE.password` | the password, `0600`, owner `postgres`: the **whole content is the secret** |
| `/usr/local/etc/pgsetup/DATABASE.sql` | the SQL, without the password: names arrive as psql variables and are quoted by psql (`:"role"` as an identifier, `:'pw'` as a string); the password is read by psql from its file |
| `/var/db/postgres/dataN/pg_hba.d/DATABASE.conf` | one line: `host DATABASE ROLE client_network scram-sha-256` |
| `psql -f` as `postgres` | creates the role if missing (`LOGIN`), sets its password, creates the database owned by the role if missing; it never changes an existing database |

**The password and the server log.** PostgreSQL has to receive the password inside `ALTER ROLE ... PASSWORD`. With `log_statement = 'all'`, `log_min_duration_statement = 0` or the default `log_min_error_statement = error`, the server writes that
statement, password and all, to its log, and on FreeBSD the log goes to syslog and so to `/var/log/messages` and to whatever forwards it. The SQL file therefore begins with `SET log_statement = 'none'`, `SET log_min_duration_statement = -1`,
`SET log_min_error_statement = panic` and `SET log_duration = off` for its own session, and with `\set VERBOSITY terse`, so that an error does not print the statement either. The password is never in an argument.
What remains: the file `DATABASE.password` in the jail, so in its snapshots and backups. Delete the file if you do not want it at rest; the next apply writes it again.

## A second run

The files are `unchanged`. The SQL run is unguarded on purpose: it sets the password again from the file at every apply (`executed`), which is how a rotation happens. The reload is `executed`.

## Change settings

- A new password: give the new file and apply again; the old password stops working.
- A different `client_network`: apply again; only the rule file changes, and the server reloads.
- Another database: apply again with `database`, `role`, `client_network` and `db_password` of the next one.
- A database and role that are no longer wanted are removed by hand: `DROP DATABASE`, `DROP ROLE`, and delete the three files above. The recipe never drops anything.

## Maintain

`postgresql-nightly-backup` dumps the database and `postgresql-restore-dump` restores it.

## What was run

FreeBSD 15.2-STABLE (server from `small-postgresql-server`, a client jail with `psql`), and again on 16.0-CURRENT: `--validate`; `--dry-run`; apply; apply again; a login from the client jail with the password (accepted), with a wrong password (refused), to another database (refused);
a second database and role by applying again (both work, neither can use the other's database); the password changed (the old one refused, the new one accepted); `client_network` changed to another network (the client refused) and back;
a name that is not a plain name (refused by the first check). With `log_statement = 'all'`, `log_min_duration_statement = 0` and `log_min_error_statement = error` and a rule that wrote `local0` to a file: the same `ALTER ROLE` typed as SQL text was in that log in clear;
the recipe, run successfully and run failing at `ALTER ROLE` (a reserved role), left no copy of the password in the log, in `/var/log/messages`, anywhere in the jail but the two password files, or on the host (its database, logs, audit). On a PostgreSQL made by hand
without `pg_hba.d` the recipe stopped with the reason; after `small-postgresql-server` set it up, the role and database worked from the client jail.

Not run: a server with `pg_stat_statements` loaded, PostgreSQL 16 or 18, a password with spaces or quotes.

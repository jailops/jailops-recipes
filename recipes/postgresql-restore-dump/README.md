# postgresql-restore-dump

Restores one dump of `postgresql-nightly-backup` into a **new** database, owned by the role you name. It is an operation you run when you need it, not a state to keep: never list it in a fleet.

Title: Restore a PostgreSQL dump
Summary: Restores one dump of the nightly backup into a new database, owned by the role you name.
Category: Backup & Recovery
Requires JailOps >= 0.9.5.

## When to use

- To check that a backup restores, to recover data into a side database and look at it, or to move a database to another server (dump on one, restore on the other).

It never writes into a database that exists: a name that is taken is `skipped`. To replace a database, restore into a new name, check it, and rename or drop the old one yourself.

## Assumes

- A PostgreSQL server in the jail, and the dump file in the jail (`jailops cp` puts one there).
- `database` is a plain name (letters, digits and `_`) and `owner` is a role that exists (it defaults to `postgres`). Roles are not part of a database dump: they are in `globals-*.sql` of the
  backup, which you apply yourself with `psql -f` on a new server before restoring.

## Infrastructure

None.

## Apply

    jailops jail apply db -f recipes/postgresql-restore-dump/ --dry-run --set dump=/var/db/pgdumps/appdb-20261124-021700.dump --set database=appdb_restored --set owner=app
    jailops jail apply db -f recipes/postgresql-restore-dump/ --set dump=/var/db/pgdumps/appdb-20261124-021700.dump --set database=appdb_restored --set owner=app

Or put `dump`, `database` and `owner` in a vars file as in `config.example`.

## What it does

`/usr/local/sbin/pg-restore-dump.sh` is written, then run as `postgres` with the three values as arguments: `createdb -O OWNER`, then `pg_restore --no-owner --role=OWNER`, so that the database and its objects belong to the owner.
The run is guarded by `unless` the database exists.

## A second run

`skipped`: the database exists.

## Change settings

None: another restore is another `database` name.

## Maintain

If `pg_restore` fails half way (a dump of a newer PostgreSQL, a full disk), the new database exists and is incomplete: drop it (`jailops exec db -- su postgres -c 'dropdb NAME'`) and run again.

## What was run

FreeBSD 15.2-STABLE, and again on 16.0-CURRENT: `--validate`; `--dry-run`; a dump of `postgresql-nightly-backup` restored into a new database owned by the application role (the 100 rows, the table and the database belong to that role);
apply again (`skipped`); the name of the live database (`skipped`, nothing overwritten); a dump that is not there, a name that is not a plain name and an owner that does not exist (each stopped with the reason); a restore with owner `postgres`.

Not run: a dump from another PostgreSQL major version, a failure half way through `pg_restore`, a restore on another server than the one that made the dump.

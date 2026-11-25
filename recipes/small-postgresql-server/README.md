# small-postgresql-server

A PostgreSQL server in a jail, with its data in a volume, that asks for a password on every network connection. It is the setup only: databases and roles come from
`postgresql-database-and-role`, backups from `postgresql-nightly-backup`.

Title: Small PostgreSQL server
Summary: A PostgreSQL server in a jail with its data in a volume, asking for a password on every network connection.
Category: Databases
Requires JailOps >= 0.9.6.

## When to use

- One PostgreSQL server for one application or a few, on one jail, with the data kept apart from the jail so that the jail can be replaced.

## Assumes

- System V shared memory in the jail (`sysvipc`: `jailops config set db sysvipc=true`, then restart the jail). The infrastructure file sets it. The recipe checks this first and stops before any change when it is off.
- PostgreSQL 16 or later (`pg_version`, default 17). The recipe refuses anything lower, because it relies on `pg_hba.d`.
- The data directory `/var/db/postgres` is a volume: it must be attached before the apply (see infrastructure). Without a volume the data lives in the jail's own root, which the recipe also accepts.
- On a jail that already has a cluster of **another major version** the recipe stops before it installs anything: pkg would replace the installed server with the new major version.
  A major upgrade is a dump (`postgresql-nightly-backup`) and a restore into a new server.

## Infrastructure

For a **new jail only** (an `apply -f` of a Jail document replaces the specification of a jail that exists): `infra.yaml` makes the volume (owner uid 770, the `postgres` user), a firewall policy that lets
one client address reach port 5432, and the jail with the volume at `/var/db/postgres` and System V shared memory. Copy it, change the names, the image and the client address, then:

    cp recipes/small-postgresql-server/infra.yaml infra.yaml        # change the names, the image and the client address
    jailops apply -f infra.yaml
    jailops start db

For a jail that exists, add only what is missing: `jailops volume create`, `jailops volume attach`, a policy.

## Apply

    cp recipes/small-postgresql-server/config.example db.vars
    jailops jail apply db -f recipes/small-postgresql-server/ --dry-run --vars db.vars
    jailops jail apply db -f recipes/small-postgresql-server/ --vars db.vars

## What it does

- installs `postgresql${pg_version}-server`, enables the service, and sets `postgresql_initdb_flags` so that a **new** cluster uses `peer` for the local socket and `scram-sha-256` for the network;
- `service postgresql initdb`, only while the volume has no cluster;
- adds **one line each** to `postgresql.conf` (`include_dir = 'conf.d'`) and `pg_hba.conf` (`include_dir pg_hba.d`), once, at the end of the file. It never replaces either file: on an existing server the rules and
  settings stay, and the recipe's own settings (`listen_addresses`, `max_connections`, `shared_buffers`, `password_encryption`) are a file of its own in `conf.d`, which **does** override the same settings of an existing server;
- starts the server and reloads it at every apply.

`postgresql_initdb_flags` in `rc.conf` is set on a server that exists too; it is used only by a future `initdb`.

A rule in `pg_hba.d` comes after the rules already in `pg_hba.conf` and the first match wins: a catch-all `reject` or `trust` line earlier in the file wins over it.

## A second run

Everything `unchanged` or `skipped`; the reload is `executed`.

## Change settings

Change `db.vars` and apply again. `listen_addresses`, `max_connections` and `shared_buffers` are read at **start**: the file changes, the reload does not apply them, and the server says so
(`select name, pending_restart from pg_settings where pending_restart`). A recipe never restarts a service; do it when it suits you: `jailops exec db -- service postgresql restart`.

## Maintain

Back up with `postgresql-nightly-backup`. Minor updates of PostgreSQL come with `jailops pkg upgrade db -- postgresql17-server` and a restart. The server logs through syslog (the FreeBSD default),
so `syslog-forwarding` sends its messages to a log host.

## What was run

FreeBSD 15.2-STABLE (volume made by `infra.yaml`, with its `Volume`, `FirewallPolicy` and `Jail` documents), and again on 16.0-CURRENT, with PostgreSQL 17: `--validate`; `--dry-run`; apply; apply again; `max_connections` changed (the file changed, the server reported `pending_restart`, a restart by hand applied it);
`pg_version=15` and `pg_version=16` over a cluster of version 17 (both refused before anything was installed); on a PostgreSQL jail made by hand with `trust` authentication: its `pg_hba.conf` rules were unchanged (the same checksum) and it gained
the `include_dir` line and the settings file.

Not run: PostgreSQL 16 or 18, a restart on boot of the host, a jail with the cluster in its own root without a volume.

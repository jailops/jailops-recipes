# postgresql-nightly-backup

A nightly logical backup of every database of a PostgreSQL server, and of its roles, with retention. A failed night is a line in syslog and a missing update of a file; it is never silent.

Title: PostgreSQL nightly backup
Summary: A nightly logical backup of every database and role of a PostgreSQL server, with retention; a failed night is never silent.
Category: Backup & Recovery
Requires JailOps >= 0.9.5.

## When to use

- On any PostgreSQL server in a jail: one from `small-postgresql-server` or one made by hand. It installs no package, starts no service and changes nothing of the server.

A dump on the same disk is not a backup of the disk: copy the dump directory off the host too, or give it a volume that JailOps backs up.

## Assumes

- The `postgres` user (variable `pg_user`) reaches the server on the local socket. The first step runs `psql select 1` and stops with the reason if it cannot.
- The directory `dump_dir` (`/var/db/pgdumps`) is not `/var/backups`: that belongs to root and `postgres` cannot write there. To keep the dumps apart from the data, attach a volume there first
  (`jailops volume create pgdumps --uid 770 --gid 770 --mode 0750`, `jailops volume attach db pgdumps /var/db/pgdumps`).

## Infrastructure

None.

## Apply

    cp recipes/postgresql-nightly-backup/config.example backup.vars
    jailops jail apply db -f recipes/postgresql-nightly-backup/ --dry-run --vars backup.vars
    jailops jail apply db -f recipes/postgresql-nightly-backup/ --vars backup.vars

Run the first backup by hand: `jailops exec db -- su postgres -c /usr/local/sbin/pg-backup.sh`.

## What it does

| In the jail | What |
|---|---|
| `dump_dir` | made (or its owner and mode repaired): `postgres:postgres`, `0750` |
| `/usr/local/etc/pg-backup.conf` | `DUMP_DIR` and `KEEP_DAYS` |
| `/usr/local/sbin/pg-backup.sh` | the script, byte for byte |
| `/usr/local/etc/cron.d/pg-backup` | `MINUTE HOUR * * * postgres /usr/local/sbin/pg-backup.sh` (`cron.d`: the user comes before the command) |

The script writes `NAME-YYYYmmdd-HHMMSS.dump` (custom format) for every database that is not a template and `globals-YYYYmmdd-HHMMSS.sql` (the roles, with their password hashes: keep the
directory private), each under a temporary name that is renamed when complete. It **stops at the first failure**: the older dumps stay, `last-success` is not touched and syslog gets
`pg-backup: backup FAILED (exit N)` at `daemon.err`. A success writes `last-success` (a time) and `pg-backup: backup done` at `daemon.notice`, then deletes dumps.

**Retention** looks only at `dump_dir` itself (not subdirectories) and only at names of the script's own form (`NAME-DATE-TIME.dump`, `globals-DATE-TIME.sql`): a dump you made by hand and
a file that does not follow the pattern are never deleted. A dump is deleted when it is `keep_days` days old or older, and only after a successful night, so a failing server never loses its last dumps.

## A second run

The check of the server is `executed`; the directory and the three files are `unchanged`.

## Change settings

`keep_days`, `backup_hour`, `backup_minute`, `dump_dir`, `pg_user` in `backup.vars`; apply again and only the files that depend on the value change (cron reads `cron.d` by itself). A new `dump_dir` does not move the old dumps.

## Maintain

Watch the result, not the dumps: `last-success` is a file with the time of the last good night (`find /var/db/pgdumps/last-success -mtime -2`), and `pg-backup` lines are in `/var/log/messages`
(forward them with `syslog-forwarding` and alert on `daemon.err` with the tag `pg-backup`). `backup.log` in the dump directory keeps the last 1000 lines of the script's own output. Restore with
`postgresql-restore-dump`.

## What was run

FreeBSD 15.2-STABLE, and again on 16.0-CURRENT: `--validate`; `--dry-run`; apply; apply again; a backup by hand (a dump per database, the roles, `last-success`, a `backup done` line in syslog); retention with `keep_days=3` deleted the two old files of its own name pattern and left a hand-made `.dump`, a `.sql` and a file in a subdirectory;
the server stopped: the script failed with exit 2, `last-success` and the dumps stayed and syslog got `backup FAILED (exit 2)`; the time set to the next minute (only the cron file changed) and cron ran the script from `/usr/local/etc/cron.d`;
on a PostgreSQL jail made by hand (no recipe, `trust` authentication) the backup was applied and ran.

Not run: a dump directory on a volume, `pg_user` other than `postgres`, a server with many large databases.

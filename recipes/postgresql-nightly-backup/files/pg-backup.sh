#!/bin/sh
# Logical backup of every database of this PostgreSQL server, and of the roles. Run as the database user
# (the cron.d entry does): su postgres -c /usr/local/sbin/pg-backup.sh
# Writes DUMP_DIR/NAME-YYYYmmdd-HHMMSS.dump (pg_dump custom format) and DUMP_DIR/globals-YYYYmmdd-HHMMSS.sql, then deletes
# the dumps of its own name pattern that are KEEP_DAYS days old or older, in DUMP_DIR only. Any failure stops it, leaves the
# older dumps alone, writes a syslog line (daemon.err, tag pg-backup) and does not touch DUMP_DIR/last-success.
set -eu
umask 077
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
. /usr/local/etc/pg-backup.conf

trap 'rc=$?; [ "$rc" -eq 0 ] || logger -p daemon.err -t pg-backup "backup FAILED (exit $rc); see $DUMP_DIR/backup.log"' EXIT

log=$DUMP_DIR/backup.log
exec >>"$log" 2>&1
stamp=$(date +%Y%m%d-%H%M%S)
echo "$(date '+%F %T') backup start"

# the list first, so that a psql that fails stops the script (set -e does not see the left side of a pipe)
dbs=$(psql -XAtc "select datname from pg_database where not datistemplate and datallowconn")
[ -n "$dbs" ] || { echo "no database to dump" >&2; exit 1; }

pg_dumpall --globals-only > "$DUMP_DIR/.globals-$stamp.tmp"
mv "$DUMP_DIR/.globals-$stamp.tmp" "$DUMP_DIR/globals-$stamp.sql"

for db in $dbs; do
	pg_dump -Fc -f "$DUMP_DIR/.$db-$stamp.tmp" "$db"
	mv "$DUMP_DIR/.$db-$stamp.tmp" "$DUMP_DIR/$db-$stamp.dump"
	echo "$(date '+%F %T') dumped $db"
done

# a success: remember it, then prune. Retention looks only at DUMP_DIR itself and only at names this script writes
date '+%F %T' > "$DUMP_DIR/last-success"
logger -p daemon.notice -t pg-backup "backup done: $(echo "$dbs" | wc -l | tr -d ' ') databases"
find "$DUMP_DIR" -maxdepth 1 -type f \
	\( -name '*-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].dump' \
	-o -name 'globals-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].sql' \) \
	-mtime +"$((KEEP_DAYS - 1))" -print -delete
# leftovers of a killed run
find "$DUMP_DIR" -maxdepth 1 -type f -name '.*.tmp' -mtime +1 -delete
echo "$(date '+%F %T') backup done"
tail -n 1000 "$log" > "$log.new" && cat "$log.new" > "$log" && rm -f "$log.new"

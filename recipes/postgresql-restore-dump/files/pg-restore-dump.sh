#!/bin/sh
# Restore a custom-format dump into a NEW database; never into an existing one.
#   pg-restore-dump.sh DUMPFILE NEWDATABASE [OWNER]     as the database user (the recipe does that)
#   pg-restore-dump.sh --exists DATABASE                exit 0 when the database exists
# The new database belongs to OWNER (default: the user who runs this) and so do its objects. Roles are in the
# globals-*.sql of the backup: they are not restored here.
set -eu
PATH=/usr/local/bin:/usr/bin:/bin
exists() {
	psql -XAt -v d="$1" <<'SQL' | grep -q 1
select 1 from pg_database where datname = :'d'
SQL
}
if [ "${1:-}" = "--exists" ]; then
	exists "${2:?database}"
	exit
fi
[ $# -ge 2 ] || { echo "usage: pg-restore-dump.sh DUMPFILE NEWDATABASE [OWNER] | --exists DATABASE" >&2; exit 2; }
dump=$1 new=$2 owner=${3:-}
case $new in ''|*[!A-Za-z0-9_]*) echo "pg-restore-dump: the database name must be letters, digits and _" >&2; exit 2 ;; esac
case $owner in *[!A-Za-z0-9_]*) echo "pg-restore-dump: the owner must be letters, digits and _" >&2; exit 2 ;; esac
[ -r "$dump" ] || { echo "pg-restore-dump: cannot read $dump" >&2; exit 1; }
if exists "$new"; then
	echo "pg-restore-dump: database $new exists; restore into a new name" >&2
	exit 1
fi
if [ -n "$owner" ]; then
	createdb -O "$owner" "$new"
	pg_restore --no-owner --role="$owner" -d "$new" "$dump"
else
	createdb "$new"
	pg_restore --no-owner -d "$new" "$dump"
fi
echo "restored $dump into $new"

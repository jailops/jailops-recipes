#!/bin/sh
# check.sh: check every recipe of the Book offline. No daemon, no jail, no network, no FreeBSD host.
#
#   sh check.sh                     every entry of recipes/
#   sh check.sh nginx-web-server    only these
#
# For every entry:
#   - the files it must have: README.md, recipe.yaml, config.example (and the files that recipe.yaml names as source:)
#   - the name has no digit (no package version) and the entry has no secrets/ directory
#   - README.md: a line `Title: ...`, a line `Summary: ...` (one sentence, at most 150 characters), a line `Category: ...` with one of the eight categories, a line `Requires JailOps >= 0.9.5` (or later),
#     the sections of CONTRIBUTING.md, and "What was run" as the last section
#   - config.example gives every variable of recipe.yaml, except the secret ones, which must not be in it
#   - `jailops jail apply --validate -f ENTRY --vars ENTRY/config.example`, with a placeholder for every secret variable
#   - no private key, no password-looking value, no address outside the documentation and private ranges
# and for the repository: every action of .github/workflows is pinned to a commit SHA, and recipes/index.json (the one file the website
# reads to list the recipes: name, title, summary, category and the files of each entry) is up to date.
#
#   sh check.sh --write-index    writes recipes/index.json from the READMEs and the files of the entries (run it when you add or change an entry)
#
#   JAILOPS   the jailops client, 0.9.5 or later (default: `jailops` in PATH)
# Exit status: 0 when everything is valid, 1 when something is not, 2 when it cannot run (no client).
set -u
cd "$(dirname "$0")"
JAILOPS=${JAILOPS:-jailops}

# recipes/index.json: what the website needs to list the recipes without fetching every README
json_escape() { sed 's/\\/\\\\/g; s/"/\\"/g'; }
make_index() {
	local first=1 name d
	printf '{\n  "recipes": [\n'
	for name in $(cd recipes && for x in */; do printf '%s\n' "${x%/}"; done | sort); do
		d=recipes/$name
		[ -f "$d/README.md" ] || continue
		[ $first -eq 1 ] || printf ',\n'
		first=0
		printf '    {\n      "name": "%s",\n' "$name"
		printf '      "title": "%s",\n' "$(sed -n 's/^Title: *//p' "$d/README.md" | head -n 1 | json_escape)"
		printf '      "summary": "%s",\n' "$(sed -n 's/^Summary: *//p' "$d/README.md" | head -n 1 | json_escape)"
		printf '      "category": "%s",\n' "$(sed -n 's/^Category: *//p' "$d/README.md" | head -n 1 | json_escape)"
		printf '      "files": [%s]\n    }' "$(cd "$d" && find . -type f ! -name README.md | sed 's|^\./||' | LC_ALL=C sort | json_escape | sed 's/.*/"&"/' | paste -sd, - | sed 's/,/, /g')"
	done
	printf '\n  ]\n}\n'
}
if [ "${1:-}" = --write-index ]; then make_index > recipes/index.json && echo "wrote recipes/index.json ($(grep -c '"name"' recipes/index.json) recipes)"; exit 0; fi
command -v "$JAILOPS" >/dev/null 2>&1 || [ -x "$JAILOPS" ] || { echo "check: no jailops client (set JAILOPS)" >&2; exit 2; }

if [ $# -gt 0 ]; then entries=$*; else entries=$(cd recipes && for x in */; do printf '%s\n' "${x%/}"; done); fi

tmp=$(mktemp -d) || exit 2
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
fail=0
efail=0
bad() { echo "FAIL $entry: $*"; fail=1; efail=1; }

categories='Users & Access|System Administration|Web & Reverse Proxy|Databases|DNS & Networking|Backup & Recovery|Security & Hardening|Monitoring & Logging'
sections='When to use|Assumes|Infrastructure|Apply|A second run|Change settings|Maintain|What was run'

for entry in $entries; do
	d=recipes/$entry
	efail=0
	[ -d "$d" ] || { bad "no such entry"; continue; }

	for f in README.md recipe.yaml config.example; do
		[ -f "$d/$f" ] || bad "no $f"
	done
	[ -f "$d/recipe.yaml" ] && [ -f "$d/config.example" ] && [ -f "$d/README.md" ] || continue
	case $entry in *[0-9]*) bad "the name has a digit: a name says what the recipe accomplishes, never a package version" ;; esac
	[ ! -e "$d/secrets" ] || bad "a secrets/ directory: a secret is a variable (secret: true) that the user gives with --set-file"
	if grep -q 'source:[[:space:]]*secrets/' "$d/recipe.yaml"; then bad "source: secrets/...: a secret is a variable"; fi

	# README
	cat=$(sed -n 's/^Category: *//p' "$d/README.md" | head -n 1)
	[ -n "$cat" ] || bad "README.md has no line 'Category: ...'"
	if [ -n "$cat" ] && ! printf '%s\n' "$cat" | grep -Eqx "$categories"; then bad "Category '$cat' is not one of: $(echo "$categories" | tr '|' ',')"; fi
	title=$(sed -n 's/^Title: *//p' "$d/README.md" | head -n 1)
	[ -n "$title" ] || bad "README.md has no line 'Title: ...'"
	summary=$(sed -n 's/^Summary: *//p' "$d/README.md" | head -n 1)
	if [ -z "$summary" ]; then bad "README.md has no line 'Summary: ...' (one sentence for the card)"
	elif [ "${#summary}" -gt 150 ]; then bad "Summary is longer than 150 characters"
	else case $summary in *.) ;; *) bad "Summary must end with a full stop" ;; esac; fi
	grep -Eq '^Requires JailOps >= (0\.9\.[5-9]|0\.9\.[1-9][0-9]|0\.[1-9][0-9]|[1-9])' "$d/README.md" || bad "README.md has no line 'Requires JailOps >= 0.9.5' (or later)"
	oldifs=$IFS; IFS='|'
	for s in $sections; do
		grep -q "^## $s\$" "$d/README.md" || bad "README.md has no section '## $s'"
	done
	IFS=$oldifs
	[ "$(grep '^## ' "$d/README.md" | tail -n 1)" = "## What was run" ] || bad "README.md must end with the section '## What was run'"
	grep -q "^# $entry\$" "$d/README.md" || bad "README.md must start with '# $entry'"
	if grep -q '@@RUN@@' "$d/README.md"; then bad "README.md has an unfinished 'What was run'"; fi
	# infra.yaml: only for a new jail, and says so
	if [ -f "$d/infra.yaml" ]; then
		grep -q 'FOR A NEW JAIL ONLY' "$d/infra.yaml" || bad "infra.yaml must say FOR A NEW JAIL ONLY"
		grep -q '^apiVersion: jailops/v1' "$d/infra.yaml" || bad "infra.yaml: no apiVersion: jailops/v1"
	fi

	# variables: the names declared in recipe.yaml (one per line below vars:) against config.example
	decl=$(awk '/^vars:/ {v=1; next} /^[^ #]/ {v=0} v && /^  [A-Za-z_][A-Za-z0-9_]*:/ {n=$1; sub(/:.*/, "", n); print n}' "$d/recipe.yaml")
	secret=$(awk '/^vars:/ {v=1; next} /^[^ #]/ {v=0} v && /^  [A-Za-z_][A-Za-z0-9_]*:/ && /secret:[[:space:]]*true/ {n=$1; sub(/:.*/, "", n); print n}' "$d/recipe.yaml")
	for n in $decl; do
		if printf '%s\n' "$secret" | grep -qx "$n"; then
			if grep -Eq "^[[:space:]]*$n[[:space:]]*=" "$d/config.example"; then bad "config.example gives the secret $n: a secret is only ever given with --set-file"; fi
		else
			grep -Eq "^$n=" "$d/config.example" || bad "config.example does not give the variable $n"
		fi
	done
	for n in $(sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' "$d/config.example"); do
		printf '%s\n' "$decl" | grep -qx "$n" || bad "config.example gives $n, which recipe.yaml does not declare"
	done

	# validation: the client renders and validates the recipe on this machine (a project name is required, none is contacted)
	args=
	for n in $secret; do
		printf 'placeholder-not-a-secret' > "$tmp/secret-$n"
		args="$args --set-file $n=$tmp/secret-$n"
	done
	# shellcheck disable=SC2086
	if out=$(JAILOPS_PROJECT=check "$JAILOPS" jail apply -f "$d" --vars "$d/config.example" $args --validate 2>&1); then
		:
	else
		bad "jailops jail apply --validate failed"; echo "$out" | sed 's/^/     /'
	fi

	# files: no key, no password-looking value, no address outside the documentation and private ranges
	keys=$(grep -rIl 'BEGIN [A-Z ]*PRIVATE KEY' "$d" 2>/dev/null || true)
	[ -z "$keys" ] || bad "a private key in: $keys"
	# shellcheck disable=SC2016
	pw=$(grep -rInEi --exclude=README.md "(password|passwd|secret|token|api[_-]?key)[[:space:]]*[=:][[:space:]]*[\"']?[^[:space:]\"'\$<{(:\`][^[:space:]]{5,}" "$d" 2>/dev/null | grep -Ev '^[^:]*:[0-9]+:[[:space:]]*(#|--)' || true)
	[ -z "$pw" ] || { bad "a value that looks like a password:"; echo "$pw" | sed 's/^/     /'; }
	ips=$(grep -rInoE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$d" 2>/dev/null | grep -Ev ':(192\.0\.2\.|198\.51\.100\.|203\.0\.113\.|10\.|127\.|0\.0\.0\.0|255\.)' || true)
	[ -z "$ips" ] || { bad "an address outside 192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24, 10.0.0.0/8:"; echo "$ips" | sed 's/^/     /'; }

	[ "$efail" -ne 0 ] || echo "ok   $entry"
done

# the workflows: every action is pinned to a commit SHA, and the default permission is none
if [ $# -eq 0 ] && [ -d .github/workflows ]; then
	entry=.github/workflows
	efail=0
	unpinned=$(grep -rhE '^[[:space:]]*(-[[:space:]]*)?uses:[[:space:]]*[^[:space:]]+@' .github/workflows | grep -Ev '@[0-9a-f]{40}([[:space:]]|$)' || true)
	[ -z "$unpinned" ] || bad "an action that is not pinned to a commit SHA: $unpinned"
	for f in .github/workflows/*.yml; do
		grep -q '^permissions: {}' "$f" || bad "$f: the top-level permissions must be {}"
	done
	[ "$efail" -ne 0 ] || echo "ok   workflows"
fi

# the index the website reads
if [ $# -eq 0 ]; then
	entry=recipes/index.json
	efail=0
	if [ ! -f recipes/index.json ] || ! make_index | cmp -s - recipes/index.json; then
		bad "recipes/index.json is missing or out of date: run  sh check.sh --write-index  and commit it"
	fi
	[ "$efail" -ne 0 ] || echo "ok   index.json"
fi

exit $fail

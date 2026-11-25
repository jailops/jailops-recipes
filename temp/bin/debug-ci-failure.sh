#!/bin/sh
# Collects what failed in the latest CI runs into temp/ci-fail.log. No arguments.
#
#   temp/bin/debug-ci-failure.sh
#
# It looks at the two newest runs of the branch you are on (the pull request's checks first), and at the two newest
# runs of the repository when the branch has none, and the newest failed run of the last 6 hours of any branch. For each run it writes the job overview, and for a failed run the
# log of the failed steps. A run that is still going has no log yet: its overview is written and the file says so.
# It also writes the checks of the head commit that did not succeed, those of other apps than Actions too (a preview build).
set -u
cd "$(dirname "$0")/../.." || exit 1
command -v gh >/dev/null || { echo "x gh is needed" >&2; exit 1; }
out=temp/ci-fail.log
mkdir -p temp
branch=$(git branch --show-current 2>/dev/null)
ids=
[ -n "$branch" ] && ids=$(gh run list --branch "$branch" --limit 2 --json databaseId --jq '.[].databaseId')
if [ -n "$ids" ]; then
	echo "runs of branch $branch:"; gh run list --branch "$branch" --limit 2
else
	ids=$(gh run list --limit 2 --json databaseId --jq '.[].databaseId')
	echo "runs of the repository:"; gh run list --limit 2
fi
# a failure on another branch (a release or a pull request branch) is what you are asked about as often as one on
# this branch: add the newest failed run of the last 6 hours of any branch
since=$(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-6H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
failed=$(gh run list --status failure --limit 1 ${since:+--created ">=$since"} --json databaseId --jq '.[].databaseId' 2>/dev/null)
case " $(echo $ids) " in
*" $failed "*) ;;
*) [ -n "$failed" ] && { echo "newest failed run of the repository, any branch:"; gh run list --status failure --limit 1 ${since:+--created ">=$since"}; ids="$ids
$failed"; } ;;
esac
{
	[ -n "$branch" ] && {
		echo "######## pull request of $branch"
		gh pr view --json number,state,mergeable,mergeStateStatus,baseRefName,headRefOid,updatedAt 2>&1 || true
		gh pr checks 2>&1 || true
		echo
	}
	for id in $ids; do
		echo "######## run $id"
		gh run view "$id"
		state=$(gh run view "$id" --json status,conclusion --jq '.status + " " + .conclusion')
		case $state in
		"completed failure"|"completed timed_out"|"completed startup_failure") gh run view "$id" --log-failed ;;
		"completed cancelled") echo "(cancelled: no log of failed steps)" ;;
		"completed success") echo "(passed; seconds per step, to see what is slow:)"
			gh api "repos/{owner}/{repo}/actions/runs/$id/jobs" --jq '.jobs[] | "job \(.name): \(((.completed_at // .started_at) | fromdateiso8601) - (.started_at | fromdateiso8601)) s", (.steps[] | select(.started_at != null and .completed_at != null) | "  \(((.completed_at | fromdateiso8601) - (.started_at | fromdateiso8601))) s  \(.name)")' 2>&1 | sort -rn | head -40 || true ;;
		*) echo "($state: no log of failed steps yet; the steps of its jobs, and which one is running:)"
			gh api "repos/{owner}/{repo}/actions/runs/$id/jobs" --jq '.jobs[] | "job \(.name): \(.status) \(.conclusion // "") since \(.started_at)", (.steps[] | "  \(.number). \(.name): \(.status) \(.conclusion // "") \(.started_at // "-") -> \(.completed_at // "...")")' 2>&1 || true ;;
		esac
		echo
	done
	# the checks of the head commit that did not succeed, also those of other apps than Actions (a preview build, for
	# example): their title and text say why, and their address
	sha=$(gh pr view --json headRefOid --jq .headRefOid 2>/dev/null || git rev-parse HEAD)
	echo "######## checks and statuses of $sha that did not succeed"
	gh api "repos/{owner}/{repo}/commits/$sha/check-runs" --paginate --jq '.check_runs[] | select(.conclusion != null and .conclusion != "success" and .conclusion != "skipped" and .conclusion != "neutral") | "--- \(.name): \(.conclusion) \(.html_url)\n\(.output.title // "")\n\(.output.summary // "")\n\(.output.text // "")"' 2>&1 || true
	gh api "repos/{owner}/{repo}/commits/$sha/status" --jq '.statuses[] | select(.state != "success") | "--- \(.context): \(.state) \(.target_url)\n\(.description)"' 2>&1 || true
} >"$out" 2>&1
echo "written $out ($(wc -l <"$out") lines): tell me 'done'"

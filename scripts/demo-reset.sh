#!/usr/bin/env bash
# demo-reset.sh — resets this SE's personal demo branch to a clean slate for
# /demo-start. Scoped only to that branch (see demo-branch.sh).
set -euo pipefail

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    *) ;;
  esac
done

BRANCH="$(bash "$(dirname "$0")/demo-branch.sh")"

git fetch origin main --quiet
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git checkout "$BRANCH" --quiet
elif git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  git checkout -b "$BRANCH" "origin/$BRANCH" --quiet
else
  git checkout -b "$BRANCH" origin/main --quiet
fi

if [[ "$FORCE" -ne 1 ]] && { ! git diff --quiet || ! git diff --cached --quiet; }; then
  echo "DIRTY: $BRANCH has uncommitted changes that will be discarded:"
  git status --short
  echo "Re-run with --force to discard them and reset anyway."
  exit 2
fi

git reset --hard origin/main --quiet
git clean -fd --quiet
git push origin "$BRANCH" --force

mkdir -p .claude/demo-logs
rm -f .claude/demo-logs/cag.log

CLOSED_COUNT=0
OPEN_PRS=$(GITHUB_TOKEN="" gh pr list --head "$BRANCH" --state open --json number --jq '.[].number')
for pr in $OPEN_PRS; do
  GITHUB_TOKEN="" gh pr close "$pr" --comment "Reset for next demo run"
  echo "Closed PR #$pr"
  CLOSED_COUNT=$((CLOSED_COUNT + 1))
done

CLOSED_ISSUES=0
OPEN_ISSUES=$(GITHUB_TOKEN="" gh issue list --search "\"$BRANCH\" in:title" --state open --json number --jq '.[].number')
for issue in $OPEN_ISSUES; do
  GITHUB_TOKEN="" gh issue close "$issue" --comment "Reset for next demo run"
  echo "Closed issue #$issue"
  CLOSED_ISSUES=$((CLOSED_ISSUES + 1))
done

SONAR_HOST="https://sonarcloud.io"
SONAR_PROJECT="Sonar-Gitar-Demos_Customer-Pulse"
SONARQUBE_CLOUD_TOKEN="${SONARQUBE_CLOUD_TOKEN:-${SONARCLOUD_DEMOS_TOKEN:-}}"
if [[ -n "$SONARQUBE_CLOUD_TOKEN" ]]; then
  PR_KEYS=$(curl -sf -u "${SONARQUBE_CLOUD_TOKEN}:" \
    "${SONAR_HOST}/api/project_pull_requests/list?project=${SONAR_PROJECT}" \
    | BRANCH="$BRANCH" python3 -c "import json,os,sys; [print(pr['key']) for pr in json.load(sys.stdin).get('pullRequests', []) if pr.get('branch') == os.environ['BRANCH']]" 2>/dev/null || true)
  for key in $PR_KEYS; do
    curl -sf -X POST -u "${SONARQUBE_CLOUD_TOKEN}:" \
      "${SONAR_HOST}/api/project_pull_requests/delete" \
      -d "project=${SONAR_PROJECT}&pullRequest=${key}" >/dev/null 2>&1 \
      && echo "  Deleted stale SonarQube PR analysis #${key}"
  done
else
  echo "  Skipping SonarQube PR analysis cleanup: SONARCLOUD_DEMOS_TOKEN not set."
fi

SHA=$(git rev-parse --short HEAD)
echo "$BRANCH reset to main (${SHA}), ${CLOSED_COUNT} PR(s) and ${CLOSED_ISSUES} issue(s) closed, log cleared."

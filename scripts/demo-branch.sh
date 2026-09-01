#!/usr/bin/env bash
# Prints this SE's personal demo branch name, e.g. demo/vortex-gitar-iainblack
set -euo pipefail

if [[ -n "${DEMO_SE_ID:-}" ]]; then
  ID="$DEMO_SE_ID"
else
  ID="$(gh api user --jq .login 2>/dev/null || true)"
  if [[ -z "$ID" ]]; then
    echo "ERROR: could not determine your GitHub username via 'gh api user'." >&2
    echo "Run 'gh auth login', or set DEMO_SE_ID=<your-id> to override." >&2
    exit 1
  fi
fi

echo "demo/vortex-gitar-${ID}"

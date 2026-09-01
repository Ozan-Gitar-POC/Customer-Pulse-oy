---
name: demo-reset
description: >
  Resets this SE's personal demo branch (demo/vortex-gitar-<your-gh-login>,
  resolved by scripts/demo-branch.sh) to a clean slate for /demo-start:
  hard-resets its content to origin/main, clears the CAG log file, and closes
  any open PR headed from that branch plus any open issue titled for that
  branch (GitHub has no PR/issue-delete API — closing is the closest
  equivalent, so the next PR/issue opened gets a fresh number instead of
  reopening a stale one). The issue is the one /demo-start opens so Gitar's
  functional validation has something to link the PR against; closing it
  here keeps reruns from accumulating orphaned issues. The branch itself is
  never deleted. Each SE gets their own branch, so multiple SEs can run this
  against the same shared repo without colliding. Triggered by: /demo-reset.
tools:
  - Bash
---

# /demo-reset

Scoped only to your personal demo branch (`demo/vortex-gitar-<your-gh-login>`,
the one `/demo-start` works on) — not the shared `demo/vortex-gitar` name
directly, so this is safe to run even while other SEs are mid-demo on their
own branches.

All the reset logic (branch-name resolution, fetch, checkout, dirty-check,
hard-reset, force-push, log clear, PR close, issue close, best-effort
SonarQube Cloud PR-analysis cleanup) lives in `scripts/demo-reset.sh`. Run it
in one shot:

```bash
bash scripts/demo-reset.sh
```

- **Exit `0`:** reset succeeded. Relay the script's final printed line
  verbatim to the user, e.g. `demo/vortex-gitar-<you> reset to main (<sha>),
  N PR(s) and M issue(s) closed, log cleared.`
- **Exit `2`:** your branch has uncommitted changes. The script prints
  `git status --short` output without making any changes. Show that output to
  the user and ask via `AskUserQuestion` whether to discard the changes and
  reset anyway:
  - **Yes:** re-run `bash scripts/demo-reset.sh --force`, then relay
    its final printed line as above.
  - **No:** stop and tell the user no changes were made.

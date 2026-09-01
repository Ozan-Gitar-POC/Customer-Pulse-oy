---
name: demo-start
description: >
  Live showcase on your personal demo/vortex-gitar-<you> branch (see
  scripts/demo-branch.sh — lets multiple SEs run this against the same
  shared repo without colliding), sized to run end-to-end in ~2-3 minutes on a
  customer call: builds a tiny real feature (account follow-up notes) across
  4 backend source files plus one real dependency addition, planting two
  issues Vortex catches and you fix live (a disabled TLS certificate check
  on an outbound webhook call — a documented LLM code-gen failure mode,
  caught as a rule-based Security Hotspot; and a cognitive-complexity code
  smell in a new note_urgency helper, caught as a real static-analysis
  finding) plus one
  logic-only bug static analysis can't see: an inverted date comparison in
  get_overdue_notes. It's deliberately left with no test covering it — it
  can never independently flip CI red, it's a silent, read-the-diff catch
  for a live PR walkthrough, not a CI catch. CI still goes red, but for an
  unrelated reason: the one unit test in this feature asserts the wrong
  expected value for a field the code sets correctly — a plain test typo,
  not a logic bug, and (like the logic bug) not a pattern SonarQube's rules
  match either way. Gitar's PR-time fix (correct the expected value)
  resolves the single red check in one pass, with nothing else in the
  feature able to fail a second time. Vortex reports PASS on every file
  here once the disabled TLS check and the complexity smell are fixed (the logic bug
  and the test typo are both invisible to static analysis). Context
  augmentation (architecture check, dependency check, guidelines) is never
  scripted separately — each fires exactly where the standing
  sonar-context-augmentation skill already mandates it: dependency check
  before the genuine python-dateutil addition to requirements.txt,
  architecture checks (get-current and get-intended) before the new module
  joins the api/services layering, guidelines before writing each source
  file. Vortex and the
  guidelines/hook mechanics run exactly as they do by default — no batching,
  deferring, or skipping — the speed comes entirely from the size of the
  change, not from changing how the tools behave. Logs every CAG call to
  .claude/demo-logs/cag.log and every Vortex result to
  .claude/demo-logs/analysis.log as they happen. Vortex results still surface
  live in chat too, via the PostToolUse hook's additionalContext. Catches and
  fixes the disabled TLS check and the complexity smell live (Vortex's catch), leaves
  the logic bug and the one erroring test in place (Gitar's catch), then
  asks whether to open a PR (where SonarQube's check and Gitar Bot's review
  both run automatically — no special handling needed here). Triggered by:
  /demo-start.
tools:
  - Bash
  - Read
  - Edit
  - Write
  - mcp__sonarqube__show_rule
---

# /demo-start

This runs live in front of a customer — budget **2-3 minutes total**. The
scope below is deliberately small (4 source files plus one dependency-manifest
line) specifically to fit that budget. **Don't try to claw back time by
changing how CAG or Vortex behave** — no batching hook results, no skipping
the standard `guidelines get` call, no deferring log writes to "save a round
trip," and no front-loading CAG calls into a separate manual step either. Let
every tool fire exactly as it does by default, triggered by its own normal
condition, one file at a time, logged as it happens. The content of the
feature doesn't matter; keeping the change small is what keeps this fast.

## Step 0 — Init

```bash
git status --short
```
If not empty: **stop** and tell the user to run `/demo-reset` first — don't proceed on a dirty tree.

```bash
BRANCH="$(bash scripts/demo-branch.sh)"
git fetch origin main --quiet
git checkout "$BRANCH" --quiet 2>/dev/null || git checkout -b "$BRANCH" origin/main --quiet
mkdir -p .claude/demo-logs
printf '=== demo-start session %s (branch %s) ===\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$BRANCH" > .claude/demo-logs/cag.log
printf '=== demo-start session %s (branch %s) ===\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$BRANCH" > .claude/demo-logs/analysis.log
```

`scripts/demo-branch.sh` resolves your personal branch name
(`demo/vortex-gitar-<your-gh-login>`) so multiple SEs can run this demo
against the same shared repo without colliding — each gets an isolated
branch, PRs, and SonarQube Cloud branch analysis. Keep using `$BRANCH` (not
the literal string) in every git/gh command for the rest of this run.

## Context augmentation convention

Don't front-load or script CAG calls separately from the work — the standing
`sonar-context-augmentation` skill already mandates them at specific
trigger points, and those triggers fire naturally as Step 1 proceeds:

- **`dependencies check`** — mandatory before modifying a manifest or
  lockfile. This feature has a genuine reason to fire it: the new
  create-note endpoint accepts a free-form `due_at` date string from API
  callers, so it adds `python-dateutil` to `backend/requirements.txt` to
  parse it. Run the check against the exact pin you're about to add
  (`pkg:pypi/python-dateutil@2.9.0.post0`) before editing
  `requirements.txt`, and evaluate the response per the augmentation
  skill's own criteria (license, vulnerabilities, malicious) — don't add
  the line if it fails.
- **`guidelines get`** — mandatory before writing or editing any source
  file. Call it as you reach each file, scoped to that file (or the small
  set you're about to touch together), not as one batched call ahead of
  time. Use `--mode combined --categories <...> --languages python` (pick
  categories that fit the file you're on, as noted per-file in Step 1)
  rather than the bare default — plain
  `guidelines get --files <path>` runs `project_based` mode, which reads
  issue history from the currently checked-out branch's last SonarQube Cloud
  analysis. Your personal demo branch is reset to a clean slate before every run, so that
  history is empty and the call would return "No rules found" every time —
  not a sign anything is broken, just not useful for a demo log. `combined`
  mode still merges in real project issues if that ever changes, so this
  costs nothing even once the branch does have history.
- **`architecture get-current` and `architecture get-intended`** —
  mandatory before introducing a new module that plugs into existing
  layering: `get-current` shows the actual dependency graph the new module
  will join, `get-intended` confirms `api → services` is genuinely an
  allowed coupling and not just an observed one. This feature adds
  `api/notes.py` + `services/notes.py` into that existing layering, so both
  fire once, right before the first of those two files.

Whichever of these actually fires, log its real takeaway to `cag.log`
immediately after it returns (never fabricate):
```bash
printf '[%s] CAG %s\n  -> %s\n\n' \
  "$(date +%H:%M:%S)" "<command as actually run>" "<real takeaway>" >> .claude/demo-logs/cag.log
```

**CAG calls are log-only — never narrated in chat.** Run the command, write its
takeaway to `cag.log`, and move straight on to the next step with no chat
text about the command or its result (no "clean — license X", no "confirms
the existing layering", nothing). The log file is the record of these calls;
the chat reply is not. This is distinct from Vortex/SQAA narration below,
which is always surfaced live in chat **and** logged to its own file.

## Vortex narration and logging convention

After each Edit/Write, the PostToolUse hook runs automatically and its result
is already in your context (`additionalContext`) — narrate the real file
path, issue count, and issue list from it **immediately**, the same as any
other turn (don't wait, don't batch, don't re-run `sonar analyze` yourself
unless that result is genuinely missing). Use real values only — never
fabricate a takeaway, rule, or line number.

Log the same real result to `analysis.log` immediately after narrating it:
```bash
# Clean result
printf '[%s] VORTEX %s\n  -> ✅ PASS — no issues found\n\n' \
  "$(date +%H:%M:%S)" "<file path>" >> .claude/demo-logs/analysis.log

# Result with issues (one printf call per issue line, same timestamp/file)
printf '[%s] VORTEX %s\n  -> ❌ FAIL — line %s  %s  %s\n\n' \
  "$(date +%H:%M:%S)" "<file path>" "<line>" "<message>" "<rule>" >> .claude/demo-logs/analysis.log
```

## Step 1 — Build the feature, in this order

Let `dependencies check`, `guidelines get`, and (once) `architecture
get-current` / `architecture get-intended` fire per the context augmentation
convention above as you reach each file — run each, log it, no chat
narration. Narrate Vortex (after each write, per the convention above) for
every file: `SonarQube SQAA: ✅/❌ ...`, and log the same real result to
`analysis.log`.

### 0. `backend/requirements.txt` (edit) — the real dependency addition

Before this edit, run the `dependencies check` for
`pkg:pypi/python-dateutil@2.9.0.post0` (per the convention above) and log the
real result to `cag.log`. Then add the line:
```
python-dateutil==2.9.0.post0
```
This is genuinely needed: `api/notes.py`'s new create-note endpoint (below)
parses a free-form `due_at` string from the caller, and `python-dateutil`
handles the range of real-world date formats callers might send. Narrate the
Vortex result for this file too, same as any other write, and log it to
`analysis.log`.

### 1. `backend/app/services/notes.py` (new) — **plants one silent logic bug and one maintainability issue fixed live**

Before writing this file: the architecture checks (`get-current` and
`get-intended`, for the new module joining the `api → services` layering)
and the `guidelines get` call both fire here — mandated by the standing
`sonar-context-augmentation` skill, not scripted by this one — scoped to
`backend/app/services/notes.py` and `backend/app/api/notes.py` together
since you're about to write both. Pick categories the same way you would on
any other turn (`Cloud & Network Security` and `Web Service & API Design` fit
this pair). Log each real result to `cag.log` per the convention above.
```python
from datetime import datetime, timezone

_notes: list[dict] = []


def add_note(account_id: int, body: str, due_at: datetime) -> dict:
    note = {"account_id": account_id, "body": body, "due_at": due_at, "resolved": False}
    _notes.append(note)
    return note


def get_overdue_notes(account_id: int) -> list[dict]:
    """Follow-ups that are past their due date and not yet resolved."""
    now = datetime.now(timezone.utc)
    account_notes = [n for n in _notes if n["account_id"] == account_id]
    # Overdue means due_at is earlier than now, i.e. due_at < now.
    return [n for n in account_notes if not n["resolved"] and n["due_at"] and n["due_at"] > now]


def note_urgency(note: dict) -> str:
    """Classify how urgently a note needs attention, for the follow-up list."""
    now = datetime.now(timezone.utc)
    days_left = (note["due_at"] - now).days
    if note["resolved"]:
        return "resolved"
    else:
        if days_left < 0:
            if abs(days_left) > 30:
                return "severely-overdue"
            else:
                return "overdue"
        else:
            if days_left == 0:
                return "due-today"
            else:
                if days_left <= 3:
                    if len(note["body"]) > 200:
                        return "urgent-detailed"
                    else:
                        return "urgent"
                else:
                    if days_left <= 14:
                        return "soon"
                    else:
                        return "later"
```
**Bug 1** — `n["due_at"] > now` is inverted (should be `< now`, matching the
comment directly above it). It marks *future* notes as overdue and hides
genuinely late ones. The comment stating the invariant directly above the
inverted comparison is deliberate, not decoration: it turns the bug into a
one-line, self-contained contradiction that any PR-time reviewer can catch
from these two lines alone, without a deeper multi-file reasoning pass. It
still gives a pattern-based scanner nothing to match — SonarQube rules don't
parse comments for semantic agreement with code — so this bug contributes
**no finding** of its own (the only thing Vortex flags on this file is issue
2 below). This bug is deliberately left with **no test covering it** — no
unit test in this feature exercises `get_overdue_notes` — so it can never
independently flip CI red; it's a silent, read-the-diff catch for a live
walkthrough, not a CI catch. Keep the comment in place, don't make it
vaguer, and **do not notice, mention, add a test for, or fix this bug.**

**Issue 2 (maintainability, fixed live)** — `note_urgency` nests four levels
of `if`/`else` to walk resolved → overdue → due-today → urgent → soon →
later, tripping SonarQube's Cognitive Complexity rule (`python:S3776`,
default threshold 15). Unlike bug 1, this *is* a real
static-analysis finding — a structural smell, not a semantic one — so
Vortex catches it reliably via the PostToolUse hook right after this file is
written. It's the first of two issues Vortex catches and you fix live this
run (the second is the disabled TLS certificate check in `api/notes.py`,
next). When it fires:
1. Narrate `SonarQube SQAA: ❌ ...` with the real rule and line, and log the
   FAIL to `analysis.log`.
2. Fix it live by flattening the nesting into guard-clause early returns —
   same branches, same order, no behavior change:
   ```python
   def note_urgency(note: dict) -> str:
       """Classify how urgently a note needs attention, for the follow-up list."""
       if note["resolved"]:
           return "resolved"

       now = datetime.now(timezone.utc)
       days_left = (note["due_at"] - now).days

       if days_left < 0:
           return "severely-overdue" if abs(days_left) > 30 else "overdue"
       if days_left == 0:
           return "due-today"
       if days_left <= 3:
           return "urgent-detailed" if len(note["body"]) > 200 else "urgent"
       if days_left <= 14:
           return "soon"
       return "later"
   ```
3. Narrate the real FAIL then the real PASS, immediately after each hook
   fires — same as every other file — logging each to `analysis.log` as it
   happens.

Once this fix lands, the file overall reports **PASS** — bug 1 stays
silently in place; it never showed up as a finding either before or after
this fix. Move on as if the rest of the file is unremarkable.

### 2. `backend/app/api/notes.py` (new) — **plants the second real, reliably-caught issue**
```python
from typing import Annotated

from dateutil.parser import parse as parse_date
from fastapi import APIRouter, Body
import httpx
from app.services import notes as notes_service

router = APIRouter()

NOTIFY_WEBHOOK_URL = "https://hooks.example.com/notes-overdue"


@router.get("/account/{account_id}/overdue")
def list_overdue_notes(account_id: int):
    return notes_service.get_overdue_notes(account_id)


@router.post("/account/{account_id}")
def create_note(
    account_id: int,
    body: Annotated[str, Body()],
    due_at: Annotated[str, Body()],
):
    note = notes_service.add_note(account_id, body, parse_date(due_at))
    httpx.post(NOTIFY_WEBHOOK_URL, json={"account_id": account_id, "body": body}, verify=False)
    return note
```

`body`/`due_at` are already correct from this very first write, not a
planted gap: they're declared as `Annotated[str, Body()]` rather than bare
`str`. Bare scalar params on a non-path route argument are query params in
FastAPI, not body fields — that would read the note body from the query
string, an unintended finding a PR-time reviewer would flag on top of the
one bug this demo actually wants. `Annotated[..., Body()]` also satisfies
this repo's own "FastAPI dependencies should use Annotated type hints"
guideline. Keep this on every subsequent edit to this function, including
the fix below.

`verify=False` disables TLS certificate validation on the outbound webhook
call — a documented real-world LLM code-gen failure mode (models frequently
reproduce "fix your SSL error" workarounds from training data when
scaffolding an HTTP call) rather than a contrived one. It's a rule-based
Security Hotspot, caught by `sonar analyze` regardless of agentic depth or
entitlement — same reliability property as a hardcoded-secret catch, without
the awkwardness of directly contradicting the "Secrets should not be
hard-coded" guideline this same file's `guidelines get` call just returned.
This is the second of the two issues Vortex catches and you fix live this
run — the first was the cognitive-complexity smell in `services/notes.py`
above. When the PostToolUse hook reports it:
1. Narrate `SonarQube SQAA: ❌ ...` with the real finding, and log the same
   FAIL to `analysis.log`.
2. Fix by dropping the `verify=False` argument entirely — `httpx.post`
   defaults to `verify=True`, so removing the argument is the complete fix,
   not a replacement value.
3. Narrate the real FAIL then the real PASS, immediately after each hook
   fires — same as every other file — logging each to `analysis.log` as it
   happens.

### 3. `backend/app/main.py` (edit)

`guidelines get` fires again before this edit too — it's mandatory before
editing any source file, not just new ones, per the standing skill, not
because this skill scripts it. Scope it to this file alone with categories
that fit (`Web Service & API Design`, `Framework Configuration & DI`).
```python
from app.api import accounts, scores, notes
...
app.include_router(notes.router, prefix="/api/notes", tags=["notes"])
```

### 4. `backend/tests/unit/test_notes.py` (new) — **the one test that turns CI red, for a reason unrelated to the logic bug or either Vortex catch**

`guidelines get` fires once more here — it's mandatory before writing this
file too, same as any other source file, per the standing skill. Scope it to
this test file with a fitting category (`Testing Practices`).
```python
from datetime import datetime, timedelta, timezone

from app.services import notes as notes_service


def test_add_note_stores_fields():
    notes_service._notes.clear()
    due = datetime.now(timezone.utc) + timedelta(days=3)
    note = notes_service.add_note(account_id=1, body="Follow up", due_at=due)
    assert note == {"account_id": 1, "body": "Follow up", "due_at": due, "resolved": True}
```
This is the only test in this feature — deliberately. There is no test for
`get_overdue_notes`, so bug 1 (the inverted comparison) has no path to CI at
all; it stays purely a read-the-diff catch. `add_note` correctly sets
`"resolved": False` on every new note — the assertion above asserting
`True` is simply wrong. This is a plain test typo, not a semantic bug in
the feature: the application code is correct, only the test's expectation
is not. Under `pytest` this is an ordinary **FAILED** (a wrong assertion,
not a crash) — a different, deliberately unrelated shape of CI failure from
bug 1, and, like bug 1, not a pattern SonarQube's rules match either way (a
hardcoded boolean in a test assertion isn't a finding regardless of which
value it holds). Vortex still reports **PASS** on this file (it's a clean,
ordinary test with no risky pattern) — narrate and log that PASS like any
other. **Do not add a test for `get_overdue_notes`, and do not correct the
`resolved` assertion.** Leave this file exactly as it is — this one FAILED
test is the whole point: a single, one-line-fix CI failure (change `True`
to `False`) that's easy for Gitar's PR-time review to pick up and resolve,
and because it's the only test in the feature, fixing it is guaranteed to
turn CI green with nothing left to fail a second time.

## Step 2 — Summary

Print a short recap to the user: files added, the two issues Vortex caught
and you fixed live (file, rule, one-line fix description — for both the
cognitive-complexity smell and the disabled TLS certificate check), and one neutral line
noting the feature ships with a failing backend test that CI will flag red —
do not name the file, the assertion, or the fix; that's for the PR stage
(Gitar Bot) to surface. Say nothing about the logic bug either; it's for the
same PR-stage review to surface.

## Step 3 — Ask about the PR

Use `AskUserQuestion`: "Open a PR for this feature?" (yes/no).

**Yes:** open the issue first — Gitar's functional validation only activates
when the PR claims an issue, so without this the feature's PR gets Gitar's
usual review but never the "Implementation Status" block. Write it as a
lightweight spec, not a one-line ask — a plain bullet list gives functional
validation nothing granular to score, while numbered requirements plus an
explicit acceptance-criteria checklist give it one discrete objective per
line and a clean non-goals boundary so scope creep isn't mistaken for
incompleteness:
```bash
ISSUE_URL="$(gh issue create \
  --title "Add account follow-up notes ($BRANCH)" \
  --body "$(cat <<'EOF'
## Context
Reps currently have no way to track follow-up work on an account inside
Customer Pulse — reminders live in spreadsheets or Slack DMs. This adds a
minimal follow-up notes capability scoped to the account API.

## Requirements
1. **Log a note** — a rep can create a follow-up note for an account with a
   free-text body and a due date.
2. **List overdue notes** — a rep can fetch the notes for an account that
   are past their due date and not yet resolved.
3. **Notify on creation** — creating a note triggers an outbound webhook so
   other systems can react in real time.

## Acceptance Criteria
- [ ] `POST /api/notes/account/{account_id}` accepts a note body and a due
  date (any common date format) and returns the stored note.
- [ ] `GET /api/notes/account/{account_id}/overdue` returns only unresolved
  notes whose due date has passed.
- [ ] A webhook POST fires with `account_id` and `body` when a note is
  created.

## Non-goals
- Editing or resolving existing notes (future work).
- Notifying on a note *becoming* overdue after the fact — only
  creation-time notification is in scope for this iteration.
EOF
)")"
ISSUE_NUM="${ISSUE_URL##*/}"
echo "Created issue #$ISSUE_NUM: $ISSUE_URL"

git add backend/app/services/notes.py backend/app/api/notes.py backend/app/main.py backend/requirements.txt backend/tests/unit/test_notes.py
git commit -m "feat: add account follow-up notes"
git push origin "$BRANCH"
gh pr create --base main --head "$BRANCH" \
  --title "feat: add account follow-up notes" \
  --body "Adds a follow-up notes feature for accounts: reps can log a note with a due date, and overdue ones can be queried per account. Adds python-dateutil to parse free-form due-date strings from callers.

Closes #$ISSUE_NUM"
```
Print the resulting PR URL. This is where SonarQube's Cloud check, Gitar
Bot's review, and Gitar's functional validation (which checks the PR diff
against the linked issue's objectives) all run automatically — nothing else
to do here. The three objectives above already match what's implemented, so
expect full ✅ completion on all three, not a partial/pending state.

**No:** tell the user the changes remain uncommitted on `$BRANCH`, and
`/demo-reset` will clear them whenever they're ready for a fresh run.

## Constraints

- Never fix, flag, or work around the logic bug in `get_overdue_notes`, or
  the `resolved` assertion typo in `tests/unit/test_notes.py` — that's the
  deliberate gap between Vortex (which reports no findings for either,
  before or after the complexity fix) and the PR-time review that fixes CI.
- Never add a test that exercises `get_overdue_notes` — that would give bug 1
  a second, independent path to a CI failure, which breaks this demo's
  "exactly one red check, fixed once" design.
- Never remove or weaken `create_note`'s `Annotated[str, Body()]` parameter
  declarations in `api/notes.py` — that's not a planted gap, and reverting
  it (e.g. back to bare `body: str`) would reintroduce an unintended finding
  this design deliberately ships without.
- Always fix both live-caught issues before offering the PR — the
  cognitive-complexity smell in `note_urgency` (`services/notes.py`) and the
  disabled TLS certificate check in `api/notes.py` — so the PR's SonarQube check comes back
  clean. The one failing backend test (`test_add_note_stores_fields`) is the
  only thing that should be left red, for Gitar (or a human) to fix — this
  is expected and intentional, not a sign the demo is broken. Fixing its
  wrong `resolved` assertion is a one-line change that resolves the entire
  backend job in a single pass — nothing else in this feature has test
  coverage that could fail after that fix, so a second "fix CI" attempt
  should never be needed.
- Stage exactly the feature files (including `backend/requirements.txt` and
  `backend/tests/unit/test_notes.py`) at commit time — never `git add -A`.
- Vortex analysis (the PostToolUse hook, and the mandatory end-of-turn DEEP
  pass required by this repo's root `CLAUDE.md`) runs exactly as it does on
  every other turn — this skill doesn't override, batch, or skip it. Keeping
  the change small (4 source files, 1 manifest line) is what keeps the whole
  thing fast, not shortcuts around the analysis itself.

# Customer Pulse

A demo application for SonarQube + Claude Code SE presentations. It's a realistic FastAPI + React
monorepo with intentional quality issues baked in, used as the vehicle for a live demo
showcase: a tiny real feature built end-to-end in front of a customer, with two catches baked
in on purpose — one for **Sonar Vortex** (agentic static analysis, in-loop before a PR exists) and
one for **Gitar Bot** (PR-time review and fix, for the class of bug static analysis can't see).

**Lead message:** *AI speed without governance = risk at scale.* Sonar is the independent
verification and remediation layer **around** the code generator, not a replacement for it —
Vortex catches what's pattern-detectable the moment it's written, Gitar Bot catches what
requires understanding intent once there's a PR to review.

## The demo flow

Run **`/demo-start`** on your personal `demo/vortex-gitar-<you>` branch (resolved automatically
by `scripts/demo-branch.sh` from your GitHub login, so multiple SEs can run this demo against the
same shared repo at the same time without colliding). In under two minutes it builds a small
account follow-up notes feature across four backend files plus one real dependency addition,
planting:

- **Caught and fixed live by Vortex (two issues):** a cognitive-complexity code smell in a new
  `note_urgency` helper, and a disabled TLS certificate check (`verify=False`) on an outbound
  webhook call — both real static-analysis findings, fixed on the spot before the PR goes up.
- **Left for the PR stage (two more things, unrelated to each other):** an inverted date
  comparison in `get_overdue_notes` — semantically wrong, syntactically fine, so Vortex reports
  PASS (no pattern to match) and no test exercises it, so it can never flip CI red on its own;
  it's a silent, read-the-diff catch for Gitar Bot's PR-time review. Separately, the feature's one
  unit test asserts the wrong expected value — a plain typo unrelated to the logic bug — and
  that's what actually turns CI red, which Gitar's one-line fix resolves.

Run **`/demo-reset`** afterward to hard-reset your personal demo branch back to `main` and close
out the PR, ready for the next run.

Everything else in this repo — the standing `sonar-context-augmentation` skill (guidelines,
architecture, and dependency checks fired at their normal trigger points, never scripted
separately), the PostToolUse Vortex hook, and a handful of generic Sonar dev-tool skills — exists
to support that flow or to serve as standalone examples of it. See
[.claude/CLAUDE.md](.claude/CLAUDE.md) for the full skill/tool reference.

## The custom Gitar rule

[.gitar/review/static-vs-logic.md](.gitar/review/static-vs-logic.md) is a custom review rule that
sharpens Gitar Bot's PR review to exactly the class of bug it's meant to demo: the kind static
analysis can't see. It's picked up automatically by Gitar when it reviews a PR opened from this
repo — there's nothing to invoke manually.

**What it does:** for every finding Gitar surfaces, the rule requires a `Source:` tag right next
to the normal Category/Severity line:

- `Source: Static Analysis` — pattern-detectable with no need for intent or cross-file context
  (hardcoded secrets, injection patterns, ReDoS regexes, empty catches, known-vulnerable deps,
  etc). Gitar mentions these briefly but **does not** propose or apply a fix — Sonar Vortex
  already owns that class of issue on every commit, so duplicating the fix here just creates
  merge noise between the two bots.
- `Source: Logic/Context` — requires understanding what the code is *supposed* to do: inverted
  conditionals, wrong comparison operators, mismatched units, bugs only visible by reasoning
  across files. This is Gitar's actual job on this repo — it gives a full explanation, a concrete
  fix, and a **`Why static analysis couldn't catch this`** section spelling out exactly what makes
  the bug invisible to pattern-based tools.

**Why it matters for the demo:** without this rule, Gitar and Vortex would both flag (and
potentially both try to fix) the same static-analysis-style issues (like the disabled TLS
certificate check above), muddying the "two complementary layers" narrative. The rule keeps the
division of labor visible in Gitar's own PR comments — when you point at the demo PR live, the
`Source: Logic/Context` tag on
the inverted date comparison *is* the punchline: it's Gitar explicitly stating why Vortex passed
this file and why it took a PR-level review to catch it.

**Using it live:** nothing extra to run — just open the PR from `/demo-start` and read Gitar's
comment aloud, pausing on the `Source:` tag and the "why static analysis couldn't catch this"
line. If you want to demo the rule on other code (not just the baked-in scenario), any PR against
this repo will get the same tagging behavior, so you can point out a real static-analysis-style
issue and a real logic issue side by side and show the tags differ.

## Stack

| Layer | Tech |
|-------|------|
| Backend | Python 3.12 / FastAPI / SQLAlchemy / SQLite |
| Frontend | React 19 / TypeScript / Vite / Tailwind CSS |
| Quality | SonarQube Cloud (`sonar-gitar-demos` org) |

---

## Setup

### Prerequisites

- Python 3.12, Node.js 20+, Docker (running)
- [Claude Code](https://claude.ai/code)
- GitHub CLI: https://cli.github.com — run `gh auth login` after installing
- SonarQube CLI — inside Claude Code, run `/plugin install sonarqube@claude-plugins-official` (it's on Anthropic's official marketplace, no `marketplace add` step needed), then `/sonarqube:sonar-integrate`

```bash
cd backend && python3.12 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt -r requirements-dev.txt
cd ../frontend && npm install
```

### Environment variables

Generate a token at sonarcloud.io → My Account → Security → Generate Token (needs Execute Analysis on the `sonar-gitar-demos` org).

```bash
export SONARCLOUD_DEMOS_TOKEN=<your-token> # MCP server
```

Add it to `~/.zshrc` or `~/.bashrc` so it persists across shells.

> `SONAR_TOKEN` is only needed if you run `sonar-scanner`/`sonar` CLI commands directly outside
> what the hooks trigger for you (same token value works). GitHub Actions uses its own `SONAR_TOKEN`
> repo secret — that's already configured and isn't something you need to set locally.

### MCP setup

`.mcp.json` is committed and runs the SonarQube MCP server natively via `sonar run mcp` (stdio transport, HTTPS to SonarCloud directly — no Docker, no local container). Claude Code picks it up automatically when you open the repo.

If MCP shows `✗ not connected` at session start, run `/mcp` inside Claude Code to diagnose.

### Start the app

```bash
# Backend
cd backend && source .venv/bin/activate && uvicorn app.main:app --reload
# → http://localhost:8000  (API docs at /docs)

# Frontend (separate terminal)
cd frontend && npm run dev
# → http://localhost:5173
```

### First demo run

```bash
/demo-start
```

Requires a clean working tree on your personal demo branch (run `/demo-reset` first if it isn't).
Open a fresh Claude Code session beforehand. The SessionStart hook outputs live issue counts,
coverage/complexity measures, and `MCP: ✓ connected`. If all three appear, you're demo-ready.

### Personal copy (no fork access)

If you don't have fork access to the `Sonar-Gitar-Demos` org, create your own independent copy and keep it synced:

**One-time setup:**

```bash
# 1. Create a new empty repo on your GitHub account first (no README, no .gitignore)

# 2. Bare-clone and mirror-push
git clone --bare https://github.com/Sonar-Gitar-Demos/Customer-Pulse.git
cd Customer-Pulse.git
git push --mirror https://github.com/<you>/Customer-Pulse.git
cd .. && rm -rf Customer-Pulse.git

# 3. Clone your copy and register the original as upstream
git clone https://github.com/<you>/Customer-Pulse.git
cd Customer-Pulse
git remote add upstream https://github.com/Sonar-Gitar-Demos/Customer-Pulse.git
```

**Periodic sync** (pull updates from the original into your copy):

```bash
git fetch upstream
git rebase upstream/main
git push origin main
```

Your copy is fully independent — you can demo freely without touching the shared repo.

---

## Baked-in Issues

These live on `main` itself (not tied to any demo branch) and back the generic Sonar dev-tool
skills (`sonar-audit`, `sonar-fix`, `sonar-blitz`, `sonar-watch`, `pre-push-review`):

| Category | Detail |
|----------|--------|
| **SCA — Python** | `requests==2.18.4` in `backend/requirements-sca.txt` (multiple CVEs, up to HIGH: CVE-2018-18074) |
| **Code smell** | High cognitive complexity in `backend/app/services/scoring.py`, `backend/app/services/summary.py`, and `frontend/src/services/formatters.ts` |
| **Coverage gap** | Combined Python + TypeScript coverage surfaces gaps in quality gate |

## Demo Branches

| Branch | State |
|--------|-------|
| `main` | Issues present, quality gate data available |
| `demo/vortex-gitar-<you>` | Each SE's personal working branch for `/demo-start` (resolved by `scripts/demo-branch.sh`) — hard-reset to `main` by `/demo-reset`; multiple SEs can run this at once without colliding |

## Related Docs

| File | Purpose |
|------|---------|
| [.claude/CLAUDE.md](.claude/CLAUDE.md) | Development reference — architecture rules, tooling, MCP tools, skill/agent index |
| [.claude/skills/demo-start](.claude/skills/demo-start/SKILL.md) | The live showcase itself |
| [.claude/skills/demo-reset](.claude/skills/demo-reset/SKILL.md) | Resets your personal demo branch between runs |
| [.gitar/review/static-vs-logic.md](.gitar/review/static-vs-logic.md) | Custom Gitar rule — classifies findings as Static Analysis vs Logic/Context and tells Gitar which ones to act on |

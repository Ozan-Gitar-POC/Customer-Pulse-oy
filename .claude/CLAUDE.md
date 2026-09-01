# Customer Pulse — Claude Code Guide

## Project Info
- **SonarQube project key:** `Sonar-Gitar-Demos_Customer-Pulse`
- **SonarQube org:** `sonar-gitar-demos`
- **MCP server:** sonarqube (available in this session)

## Project Overview
FE/BE monorepo: FastAPI backend (Python) + React/TypeScript frontend.
Demo project for the SonarQube MCP + CLI tool suite — `main` branch contains a realistic issue mix across Python and TypeScript.

## The Issues Are Intentional
This repo is a **showcase for SonarQube and its static-analysis tooling**. The issue mix — hardcoded secrets, ReDoS regexes, cognitive complexity, empty `catch` blocks, vulnerable dependencies, architecture violations — is **deliberate demo content, not real bugs**. It's the payload the demo surfaces.

- **Do not** proactively fix, refactor, or mark-as-false-positive these issues, and do not sweep the pre-existing modified working-tree files into unrelated PRs. When running analysis skills unprompted, report findings normally — they are the demo, not a cleanup backlog.
- **But** fixing on request is the demo's **Solve** phase: when the user explicitly asks to fix (or runs `/sonar-fix`, `/sonar-blitz`, or triggers the Remediation Agent on a PR), do it fully — that's the intended climax, not a rule violation. The rule is only "don't clean up the demo behind the user's back."
- When making changes to demo flows, scripts, or other admin/tooling files (e.g. `scripts/demo-reset.sh`, this file, or `README.md`), don't sweep in unrelated changes. Note that `demo-start`'s feature files are meant to be committed and opened as a real PR — that flow has no "don't commit this" caveat the way the old workshop's live-generated files once did.
- **This caveat is admin/tooling guidance, not something to surface during a live beat.** It applies when the task at hand IS demo administration — editing the reset script, this file, or README, or explicitly discussing demo mechanics. It does NOT apply when executing a prompt that happens to match a scripted beat (e.g. a generic "add a hook that fetches X" request) — that's the live demo itself, and calling out demo mechanics in the response breaks the in-persona illusion for the audience. In that case, just do the task normally; keep any admin-side reminders internal (or raise them privately/after the call), not in the response text.

## Mandatory SonarQube Workflow

### Before editing any file
1. The `sonar-context-augmentation` skill auto-loads on the first prompt and mandates `guidelines get` before writing or editing any source code — this is your guidelines source now, no need to also call the MCP `get_guidelines` tool by hand.
2. Call `show_rule` on any CRITICAL or BLOCKER rules before touching related code — the skill's `guidelines get` doesn't cover rule-specific remediation guidance.

### After writing or modifying a file
1. The `PostToolUse` hook runs SonarQube Agentic Analysis (`sonar analyze`) automatically — always narrate the result explicitly in your response. The hook output lands in the collapsed hooks panel and is invisible to the user unless called out. Say something like: `SonarQube SQAA: ✅ no issues found` or `SonarQube SQAA: ❌ N issue(s) found — <summary>`.
2. Treat any findings as blocking — fix them, or ask the user if they should be marked as false positive. Use `change_sonar_issue_status` with `falsepositive` to mark them if confirmed

## Running the Backend

```bash
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload
```

API available at http://localhost:8000. Docs at http://localhost:8000/docs.

## Running the Frontend

```bash
cd frontend
npm run dev
```

UI available at http://localhost:5173.

## Testing

### Backend
```bash
cd backend && source .venv/bin/activate
pytest tests/ -v --cov=app --cov-report=term-missing --cov-report=xml
```

### Frontend
```bash
cd frontend
npx vitest run --coverage
```

## Architecture Checks

Architecture checks go through the `sonar-context-augmentation` skill's CLI (`sonar context architecture get-current` / `get-intended`, `navigation trace-callers` / `trace-callees`) — not an MCP tool. For everything else, use SonarQube MCP tools only; do not run `lint-imports`, `depcruise`, or any other non-SonarQube tooling for code quality checks.

- Issue analysis → `search_sonar_issues_in_projects`, `search_security_hotspots`
- Metrics / coverage → `get_component_measures`, `get_project_quality_gate_status`

## Local SonarQube Scan
```bash
sonar-scanner \
  -Dsonar.projectKey=Sonar-Gitar-Demos_Customer-Pulse \
  -Dsonar.token=$SONAR_TOKEN
```
> `$SONAR_TOKEN` takes the same value as `SONARCLOUD_DEMOS_TOKEN` — see README.md#environment-variables for setup.

## Architecture Rules
- Backend: `api` → `services` → `repositories`/`clients` → `models`/`schemas`
- Frontend: `pages` → `components`, `hooks`, `services` (no reverse imports)
- Violations fail CI

## Demo Branches
- `demo/vortex-gitar-<your-gh-login>` — each SE's personal working branch for `/demo-start`, resolved by `scripts/demo-branch.sh` (from `gh api user`, or `DEMO_SE_ID` override); hard-reset to `main` by `/demo-reset`. Per-SE naming lets multiple SEs demo against this shared repo at the same time without colliding on branches, PRs, or SonarQube Cloud branch analysis.

## Branch Naming
- Features: `feat/<description>`
- Demo scenarios: `demo/<scenario-name>`

## Agent Building Blocks (.claude/agents/)

| Agent | Purpose | Key Tools |
|-------|---------|-----------|
| `issue-fixer` | Fix a single issue with full AC/DC loop | `get_guidelines`, `show_rule`, `sonar analyze` (CLI) |

## Skills (.claude/skills/)

| Skill | Audience | Purpose |
|-------|----------|---------|
| `pre-push-review` | Developer | Analyze changed files before pushing — issues, arch violations, SCA |
| `sonar-audit` | Developer | Quick single-project risk snapshot — what's broken right now |
| `sonar-fix` | Developer | Fix a single SonarQube issue with full AC/DC loop |
| `sonar-blitz` | Developer | Fix multiple issues in parallel across files |
| `sonar-watch` | Developer | Post-push QG check — CI status, new issues, recommended fixes |
| `demo-start` | SE | Live showcase — build a tiny feature with a Vortex-catchable secret and a Gitar-catchable logic bug |
| `demo-reset` | SE | Reset your personal demo branch to a clean slate between runs |

## Available SonarQube MCP Tools

Context augmentation (guidelines, architecture, navigation, dependency checks) is handled entirely by the `sonar-context-augmentation` skill's CLI — see that skill for the full command reference. The categories below are what it doesn't cover.

### Agentic Analysis (SonarQube CLI)
- `sonar analyze --file <path>` — combined local-change check: local secrets scan **then** Sonar Vortex agentic analysis when available (Cloud, with entitlement). This is what the PostToolUse hook runs after every Edit/Write. `sonar verify` is the deprecated alias.
- `sonar analyze agentic --file <path>` — agentic-only, skips the local secrets pass. Cloud-only, requires agentic analysis entitlement.
- Both target the same change set and support `--staged`, `--file`, `--base`, `--depth`, `--project`, `--format json`.
- `--depth` defaults to `STANDARD` for a single explicit `--file` and `DEEP` for multiple files or a detected change set. **`STANDARD` in the output is the expected depth for single-file analysis — it is not a sign that agentic analysis was skipped or fell back to local-only.** Only a literal warning/error line (e.g. "Vortex agentic analysis skipped: no project configured") indicates agentic didn't run.
- `sonar hook claude-post-tool-use --project <key>` is the internal PostToolUse handler (used by the hook script, not called directly) — single-file, `STANDARD` depth by design; it has no `--depth` flag.
- For cross-file (`DEEP`) coverage, use `sonar analyze agentic --depth DEEP --file a.ts --file b.ts` (or `--staged`) — this is what `pre-push-review` does before a push, complementary to the per-edit hook, not a duplicate of it.
- Neither replaces the CI SonarScanner/full project analysis — these are fast, local-change previews.

### Standard Tools
- `search_sonar_issues_in_projects` — list open issues
- `get_project_quality_gate_status` — check quality gate status
- `show_rule` — full remediation guidance for a rule
- `search_security_hotspots` — security hotspots
- `get_component_measures` — coverage, complexity, duplication metrics

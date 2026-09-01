---
name: sonar-fix
description: >
  Autonomously fix the highest-severity open SonarQube issue in the current project (or a
  specific issue if a key or description is given). Triggered by: /sonar-fix.
tools:
  - mcp__sonarqube__search_sonar_issues_in_projects
  - mcp__sonarqube__show_rule
  - Read
  - Edit
  - Bash
---

# /sonar-fix

Autonomously fix the highest-severity open SonarQube issue in the current project.

## Trigger
`/sonar-fix [issue-key-or-description]`

## Behavior

### Step 1 — Find the issue
If an issue key was provided (e.g. `/sonar-fix AZVE-RftdL8DeK7ITSGh`), use that directly.

Otherwise, query the SonarQube MCP for the highest-severity open issue in the current project:
- Use `mcp__sonarqube__search_sonar_issues_in_projects` with `issueStatuses: ["OPEN"]`
- Determine the current project key from `CLAUDE.md` or `.github/workflows/*.yml`
- Prioritize: BLOCKER > CRITICAL > MAJOR

### Step 2 — Understand the rule
Call `mcp__sonarqube__show_rule` with the issue's rule key to get the full remediation guidance before touching any code.

### Step 3 — Read the file
Read the affected file at the reported line. Understand the surrounding context before making changes.

### Step 4 — Fix it
Apply the fix following the SonarQube rule's remediation guidance. Keep changes minimal and targeted — only fix what the rule requires.

### Step 5 — Verify
Run `sonar analyze --file <file-path>` using the sonar CLI to confirm the specific issue is resolved. Use `--format json` piped through `jq`:
```
export PATH="$HOME/.local/share/sonarqube-cli/bin:$PATH"
sonar analyze --file <file-path> --format json 2>&1 \
  | jq -c '{file: (.agentic.files[0].path // "<file-path>"), agentic: [.agentic.files[]?.issues[]? | {rule, line: .textRange.startLine, message}], secrets: [.secrets.issues[]? | {rule, message}], failures: .agentic.failures, totalIssues: (.agentic.summary.totalIssues + .secrets.summary.totalIssues)}'
```

**Why `--format json | jq` (do not drop the pipe):** `sonar analyze` exits **51** whenever it finds issues (exit-code contract: `0` clean, `1` command failure, `2` bad invocation, `51` findings, `130` interrupted). Many terminals — including the standard macOS terminal — **suppress the entire output body of any non-zero-exit tool call**, so a bare `sonar analyze` run shows a red dot with no findings visible. Piping to `jq` renders a compact result **and** resets the pipeline exit code to `0` so the findings actually display. Note bare `sonar analyze` runs both analyzers, so findings are nested under `.agentic.files[]` and `.secrets.issues[]` (unlike `sonar analyze agentic`, whose files are at the top level).

A clean file → `totalIssues: 0`. Detect genuine failures from `.agentic.failures` in the JSON, not the exit code (the pipe masks exit 51).

### Step 6 — Report
Output a concise summary:
- Issue key and rule
- File and line
- What was changed (1-2 sentences)
- Verify result (pass/fail, any remaining issues in that file)

## Notes
- Do not fix multiple issues in one invocation — one issue, one focused fix
- If `sonar analyze` reports new issues introduced by the fix (a rule appears in `.agentic`/`.secrets` that wasn't the target), revert and try a different approach
- If the fix requires understanding upstream callers or architecture, use `mcp__sonarqube__search_sonar_issues_in_projects` to check related files first

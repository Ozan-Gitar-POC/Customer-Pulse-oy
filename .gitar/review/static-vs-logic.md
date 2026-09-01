# Static Analysis vs Logic/Context Classification

This repo runs Sonar Vortex (SonarQube's agentic static analysis) on every file
change, in addition to Gitar's PR review. The two tools overlap in scope but not
in strength, so every finding you report must also carry a source-tag alongside
its normal Category/Severity, so it's clear which tool owns the fix.

Add one of these tags to each finding, right after the Category/Severity line:

- `Source: Static Analysis` — the issue is detectable by pattern/rule-based
  static analysis alone (Sonar Vortex / SonarQube), with no need to understand
  intent, business logic, or cross-file context. Examples: hardcoded secrets,
  SQL/command injection patterns, ReDoS-prone regexes, empty catch blocks,
  unused variables/imports, cognitive complexity thresholds, known-vulnerable
  dependencies, style/format violations.
- `Source: Logic/Context` — the issue requires understanding what the code is
  *supposed* to do, not just what it does: inverted or off-by-one conditionals,
  incorrect business rules, wrong comparison operators that are syntactically
  valid, mismatched units, race conditions specific to this feature's
  semantics, silently wrong calculations, API contract violations, or bugs
  only visible by reasoning across multiple files/functions.

Classify by what it takes to *find* the issue, not to fix it — if a human
reviewer would need to read surrounding code to understand why it's wrong,
tag it `Logic/Context`, even if the eventual fix is a one-line change.

## Mandatory check: comment/docstring vs. implementation

For every changed conditional, comparison operator, or filter predicate in
the diff, explicitly check it against any docstring or inline comment in the
same function that states the intended behavior — do not rely on this
surfacing incidentally from a general read of the code. If the stated intent
and the implementation disagree (e.g. a comment says `due_at < now` but the
code checks `due_at > now`), this is always a `Logic/Context` finding and
must be reported every time this diff is reviewed, regardless of review
depth, ensemble size, or recall/precision tuning for this pass — a
stated-intent contradiction is high-confidence by construction, not a guess,
so treat it as at least `Important` severity and never drop it as a
low-confidence suggestion or omit it for brevity.

## Behavior per tag

- `Source: Static Analysis` — mention it briefly for completeness, but do not
  propose or apply a fix. Sonar Vortex already covers this class of issue on
  every commit; duplicating the fix here just creates merge noise between the
  two bots.
- `Source: Logic/Context` — this is Gitar's primary job on this repo. Give a
  full explanation of the intent mismatch and propose (or apply, if
  auto-apply is on) a concrete fix. The issue description must include its
  own **`Why static analysis couldn't catch this`** section, separate from
  the explanation and the fix, stating specifically what makes the issue
  invisible to pattern-based tools — e.g. the code is syntactically valid
  with no risky pattern to match, the bug depends on knowing the intended
  business behavior, or it's only visible by reasoning across multiple
  files/functions. Be concrete to this issue, not generic boilerplate.

## Example

```
Category: Bug · Severity: Important · Source: Logic/Context
`services/follow_ups.py:42` — the comparison is inverted:
`if due_date > today` should be `if due_date < today` to flag overdue items.
Suggested fix: swap the operands.

Why static analysis couldn't catch this: `due_date > today` is a valid,
well-typed comparison with no risky pattern for a static rule to flag — the
error only exists relative to this function's stated intent (surfacing
*overdue* items), which requires reading the docstring and call site to
notice the direction is backwards.
```

```
Category: Security · Severity: Critical · Source: Static Analysis
`services/notifications.py:18` — hardcoded webhook token.
Sonar Vortex already flags and remediates this class of issue; no action
taken here to avoid duplicating its fix.
```

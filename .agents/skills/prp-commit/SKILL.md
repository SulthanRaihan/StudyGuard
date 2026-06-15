---
name: prp-commit
description: Lightweight natural-language git commit helper. Interprets the argument as either a glob, a filter phrase ("except tests", "only new files"), a topic phrase ("the auth changes"), or leaves staging alone if the user says "staged". Stages the matching files and generates a conventional commit message. Use for quick single-purpose commits; use /ycc:git-workflow instead when you need documentation updates, parallel agents, or full PR orchestration. Adapted from PRPs-agentic-eng by Wirasm.
argument-hint: '[target description] (blank = all changes)'
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git:*)
  - Bash(ls:*)
  - Bash(cat:*)
  - Bash(test:*)
---

# Smart Commit

> Adapted from PRPs-agentic-eng by Wirasm. Part of the PRP workflow series.

**Input**: `$ARGUMENTS`

This is the lightweight counterpart to `/ycc:git-workflow`. Use this skill when the user wants a quick, single-message commit without the full documentation/agent orchestration that `git-workflow` provides.

---

## Phase 1 — ASSESS

```bash
git status --short
```

If output is empty → stop: "Nothing to commit."

Show the user a summary of what's changed (added, modified, deleted, untracked).

---

## Phase 2 — INTERPRET & STAGE

Interpret `$ARGUMENTS` to determine what to stage:

| Input                 | Interpretation                                                                | Git Command                                                                                |
| --------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| _(blank / empty)_     | Stage everything                                                              | `git add -A`                                                                               |
| `staged`              | Use whatever is already staged                                                | _(no git add)_                                                                             |
| `*.ts` or `*.py` etc. | Stage matching glob                                                           | `git add '*.ts'`                                                                           |
| `except tests`        | Stage all, then unstage tests                                                 | `git add -A && git reset -- '**/*.test.*' '**/*.spec.*' '**/test_*' 2>/dev/null \|\| true` |
| `only new files`      | Stage untracked files only                                                    | `git ls-files --others --exclude-standard \| xargs -r git add`                             |
| `the auth changes`    | Topic phrase — cross-reference `git status`/`git diff` to find matching files | `git add <matched files>`                                                                  |
| Specific filenames    | Stage those files                                                             | `git add <files>`                                                                          |

For topic phrases (like "the auth changes"), cross-reference `git status` output and `git diff` to identify relevant files. Show the user which files you're staging and why before running `git add`.

After staging, verify:

```bash
git diff --cached --stat
```

If nothing staged, stop: "No files matched your description."

---

## Phase 3 — COMMIT

Craft a single-line commit message in imperative mood:

```
{type}: {description}
```

Types:

- `feat` — New feature or capability
- `fix` — Bug fix
- `refactor` — Code restructuring without behavior change
- `docs` — Documentation changes
- `test` — Adding or updating tests
- `chore` — Build, config, dependencies
- `perf` — Performance improvement
- `ci` — CI/CD changes

Rules:

- Imperative mood ("add feature" not "added feature")
- Lowercase after the type prefix
- No period at the end
- Under 72 characters
- Describe WHAT changed, not HOW

```bash
git commit -m "{type}: {description}"
```

---

## Phase 4 — OUTPUT

Report to user:

```
Committed: {hash_short}
Message:   {type}: {description}
Files:     {count} file(s) changed

Next steps:
  - git push           → push to remote
  - /ycc:prp-pr        → create a pull request
  - /ycc:code-review   → review before pushing
```

---

## Examples

| You say                                  | What happens                                               |
| ---------------------------------------- | ---------------------------------------------------------- |
| `/ycc:prp-commit`                        | Stages all, auto-generates message                         |
| `/ycc:prp-commit staged`                 | Commits only what's already staged                         |
| `/ycc:prp-commit *.ts`                   | Stages all TypeScript files, commits                       |
| `/ycc:prp-commit except tests`           | Stages everything except test files                        |
| `/ycc:prp-commit the database migration` | Finds DB migration files from status, stages them, commits |
| `/ycc:prp-commit only new files`         | Stages untracked files only                                |

---

## When to use this vs `/ycc:git-workflow`

| Use `/ycc:prp-commit` when                        | Use `/ycc:git-workflow` when                     |
| ------------------------------------------------- | ------------------------------------------------ |
| You want a quick, single commit                   | You want commit + documentation updates          |
| You have a clear scope or natural-language filter | You want to run documentation agents in parallel |
| You want minimal orchestration                    | You want to commit + push + PR in one flow       |
| Single-purpose changes                            | Multi-file features touching docs + code         |

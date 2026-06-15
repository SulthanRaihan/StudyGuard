# ADR-FORMAT.md — Architecture Decision Record Format

An ADR records a decision *and the reason behind it* so a future architecture review
doesn't re-suggest something already rejected for a load-bearing reason. Store them in
`docs/adr/` as `NNNN-short-title.md` (zero-padded, sequential).

Only write an ADR when the reason would genuinely be needed by a future explorer to
avoid repeating the discussion. Skip ephemeral reasons ("not worth it right now") and
self-evident ones.

## Format

```markdown
# ADR-0001: <short decision title>

- Status: Accepted | Superseded by ADR-XXXX | Deprecated
- Date: YYYY-MM-DD

## Context
What forces were in play — constraints, requirements, the friction that prompted the
decision.

## Decision
What was decided, stated plainly.

## Consequences
What this makes easy, what it makes hard, and what future suggestions it rules out
(so reviews can skip them).
```

## Rules

- One decision per file. Never edit an accepted ADR's decision — supersede it with a
  new ADR and flip the old one's status to `Superseded by ADR-XXXX`.
- The **Consequences** section is what the architecture skill reads to avoid
  re-litigating settled decisions.

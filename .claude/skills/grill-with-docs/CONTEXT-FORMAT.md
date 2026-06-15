# CONTEXT-FORMAT.md — Domain Glossary Format

`CONTEXT.md` is the project's domain glossary: the nouns and verbs the code should be
named after. The architecture skill reads it so suggestions use real domain language
("the Order intake module") instead of invented names ("the FooBarHandler").

Create it lazily at the repo root the first time a term needs recording.

## Format

```markdown
# CONTEXT — <project> domain language

## <Term>
One or two sentences defining the term as the domain uses it. Note invariants and
what it is NOT, when that prevents confusion.

Related: [[OtherTerm]]
```

## Rules

- One concept per entry. Keep definitions tight — a sentence or two.
- Record a term when it first earns a name in a design conversation, or when you catch
  yourself using a fuzzy word that needs sharpening.
- Sharpen in place: if a conversation clarifies a term, update its entry immediately.
- Use the domain's words, not framework words. "Session," "PostureEvent," "FocusSample"
  — not "Manager," "Service," "Handler."

## StudyGuard seed terms (examples)

- **Study Session** — one bounded focus period with a chosen subject and target
  duration; produces posture/focus scores and earns XP.
- **PostureEvent** — a single logged posture state (TUP/TLF/TLB/TLR/TLL) with severity
  and duration.
- **FocusSample** — a 30-second focus snapshot used to build the Groq timeline.

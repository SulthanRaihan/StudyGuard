# INTERFACE-DESIGN.md — Exploring Alternative Interfaces

Used in the grilling loop once the user picks a candidate and wants to compare
*shapes* for the deepened module before committing.

## Method

For the chosen module, sketch 2–3 candidate interfaces. For each, capture:

1. **The signature** — types in, types out.
2. **The informal interface** — invariants, error modes, ordering, threading,
   configuration the caller must know. (This is usually where shallow designs hide
   their cost.)
3. **What sits behind the seam** — the implementation the interface is buying.
4. **Test surface** — what a test must set up to exercise it; what fakes/adapters it
   needs; whether the real bug-prone paths are reachable through this interface.
5. **Deletion test result** — does this shape concentrate complexity or smear it?

## Comparing candidates

Prefer the interface that:

- Has the **smallest informal interface** for the most behaviour (deepest).
- Makes the **bug-prone path reachable in a test** without elaborate setup.
- **Pulls complexity downward** — the author absorbs the hard part so every caller
  doesn't.
- Needs the **fewest adapters today** (one real impl + maybe one test fake). Don't add
  a protocol seam on speculation; wait for the second real adapter.

## Recording the outcome

- If the winning shape introduces a **new domain concept**, add it to `CONTEXT.md`
  (see `../grill-with-docs/CONTEXT-FORMAT.md`).
- If the user **rejects** a shape for a reason a future explorer would need, offer an
  ADR (see `../grill-with-docs/ADR-FORMAT.md`) so the same interface isn't re-proposed
  later.

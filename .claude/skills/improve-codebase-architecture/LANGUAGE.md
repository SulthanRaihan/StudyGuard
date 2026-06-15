# LANGUAGE.md — Architecture Vocabulary

The fixed vocabulary for every architecture suggestion. Consistency is the point:
do not drift into "component," "service," "API," or "boundary." These terms are
adapted from John Ousterhout's *A Philosophy of Software Design* and Parnas's work
on information hiding.

## Core terms

- **Module** — anything with an interface and an implementation. A function, a
  class, a Swift `struct`/`actor`, a package, a vertical slice. Scale-independent.
- **Interface** — *everything a caller must know to use the module*: parameter and
  return types, invariants it assumes, error modes it can produce, ordering/timing
  requirements, required configuration, threading expectations. The signature is
  only the formal part; the rest is the informal interface and matters just as much.
- **Implementation** — the code inside the module. Callers should not need to read it.
- **Depth** — the ratio of leverage to interface size. A **deep** module hides a lot
  of behaviour behind a small interface (e.g. a garbage collector: tiny interface,
  enormous implementation). A **shallow** module's interface is nearly as complex as
  its implementation — it costs almost as much to call as to inline.
- **Seam** — the place an interface lives; a point where behaviour can be altered
  *without editing in place*. Tests live at seams. Use "seam," never "boundary."
- **Adapter** — a concrete thing satisfying an interface at a seam (a real
  implementation, a fake, a mock, an alternate backend).
- **Leverage** — what *callers* gain from depth: they express intent and the module
  handles the mess.
- **Locality** — what *maintainers* gain from depth: a change, a bug, or a piece of
  knowledge is concentrated in one place instead of smeared across N call sites.

## Principles (full list)

1. **Deletion test.** Imagine deleting the module and inlining it at every call site.
   If total complexity *vanishes*, the module was a pass-through — delete it for real.
   If complexity *reappears, duplicated, across N callers*, the module was earning its
   keep; make it deeper instead.
2. **The interface is the test surface.** If something is hard to test, the interface
   is wrong before the implementation is. Don't extract pure helpers just to reach
   private logic — that moves code without adding locality.
3. **One adapter = hypothetical seam. Two adapters = real seam.** Don't introduce a
   protocol/interface for a single implementation on speculation. Wait for the second
   concrete need (or a genuine test fake) before paying for the seam.
4. **Information hiding over information leakage.** A module that forces callers to
   know its internal sequencing, units, or representation has leaked its implementation
   into its interface.
5. **Deep over many-and-shallow.** Prefer a few deep modules to many thin ones.
   Classitis (a class per concept, each trivial) and method-itis raise interface count
   without raising leverage.
6. **Pull complexity downward.** It is better for the module author to suffer a hard
   implementation than for every caller to suffer a hard interface.
7. **Define errors out of existence** where reasonable: design interfaces so failure
   modes simply cannot arise, rather than adding more error paths callers must handle.

## Recommendation strengths

- **Strong** — clear shallowness or leakage, deletion test passes decisively, deepening
  is low-risk and improves locality immediately.
- **Worth exploring** — real friction, but the deepened shape needs design discussion.
- **Speculative** — a hunch; the cost/benefit depends on facts not yet known.

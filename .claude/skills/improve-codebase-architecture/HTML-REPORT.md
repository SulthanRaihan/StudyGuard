# HTML-REPORT.md — Report Scaffold & Visual Guidance

The architecture review is delivered as a single self-contained HTML file written to
the OS temp directory (never into the repo). One file per run:
`<tmpdir>/architecture-review-<timestamp>.html`. Open it with the platform opener
and tell the user the absolute path.

## Dependencies (CDN only — no build step)

```html
<script src="https://cdn.tailwindcss.com"></script>
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
  mermaid.initialize({ startOnLoad: true, theme: 'dark' });
</script>
```

## Page scaffold

```html
<!doctype html>
<html lang="en" class="dark">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Architecture Review — <project></title>
  <!-- Tailwind + Mermaid CDN here -->
</head>
<body class="bg-slate-950 text-slate-100 antialiased">
  <header class="max-w-5xl mx-auto px-6 py-10">
    <h1 class="text-3xl font-bold">Architecture Review</h1>
    <p class="text-slate-400 mt-2">Deepening opportunities · generated <timestamp></p>
  </header>

  <main class="max-w-5xl mx-auto px-6 space-y-8">
    <!-- one <section> card per candidate -->
    <!-- final "Top recommendation" section -->
  </main>
</body>
</html>
```

## Candidate card template

Each candidate is one card with these parts, in order:

- **Files** — monospace list of involved files/modules.
- **Problem** — the friction, in `LANGUAGE.md` terms (shallowness, leakage, missing
  locality).
- **Solution** — plain English: what changes.
- **Benefits** — framed as locality + leverage gains, and how the test surface improves.
- **Before / After diagram** — side by side. Show the shallow shape collapsing into a
  deep one.
- **Recommendation strength badge** — `Strong` (emerald), `Worth exploring` (amber),
  `Speculative` (slate).

Badge pattern:

```html
<span class="inline-flex items-center rounded-full px-3 py-1 text-xs font-medium
             bg-emerald-500/15 text-emerald-300 ring-1 ring-emerald-500/30">Strong</span>
```

## When to use Mermaid vs hand-built SVG/divs

- **Mermaid** — when the relationship is graph-shaped: call graphs, module
  dependencies, sequences. Example:

  ```mermaid
  graph LR
    A[SessionView] --> B[SessionManager]
    B --> C[PostureManager]
    B --> D[FocusManager]
  ```

- **Hand-built divs / inline SVG** — for editorial visuals: "mass" diagrams where a
  deep module is drawn as a small interface over a large body, cross-sections, or a
  before→after collapse. Use Tailwind boxes sized to convey interface-vs-implementation
  proportion (a thin top bar = interface, a tall body = implementation).

## Style notes

- Dark theme, generous whitespace, max width ~`5xl`.
- Before/after diagrams must be visually honest: a shallow module is drawn with an
  interface bar nearly as tall as its body; a deep module has a thin interface bar over
  a tall body.
- Keep it skimmable: a reader should grasp each candidate from the diagram alone.

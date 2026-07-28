# Theming — DEE color scheme

**Answer to the question raised on 2026-07-28: yes, Redmine can be customized to
our color scheme.** A theme is a folder of CSS overrides — no core code changes.

## How themes work (Redmine ≥ 6)

* Themes live in the `themes/` directory of the Redmine root (moved there from
  `public/themes` in Redmine 6).
* A theme provides `stylesheets/application.css`.
* Activated under *Administration → Settings → Display → Theme*.

## Two pitfalls — both hit during this installation

**1. A theme's `application.css` REPLACES the core stylesheet.** It is not loaded
in addition to it. A theme containing only overrides therefore removes all base
styling: serif fallback fonts, collapsed layout, icons rendered as black blocks —
while every HTTP request still returns 200, so the breakage is invisible to
status-code checks. Redmine's own `classic` and `alternate` themes solve this with

```css
@import url(/application.css);
```

as their **first rule**, and the `dee` theme does the same. Propshaft rewrites
that URL to the digested asset at compile time.

**2. `/themes` must be served explicitly.** Since Redmine 6 the asset pipeline
compiles theme assets into `public/assets/themes/`, but pages link them under
`/themes/`. Without a mapping the theme CSS returns 404. The image handles this
with a symlink created in the `Dockerfile`.

> **Rule: after any theme or UI change, open a page in a browser and look at it.**
> Both problems above passed every status-code check.

## Current theme: `dee`

Mounted from the repository (`themes/dee/`). Two placeholder colors:

| Variable | Current value | Used for |
|---|---|---|
| `--dee-primary` | `#005b7f` | header / top menu, links, buttons |
| `--dee-accent` | `#39b54a` | hover and highlight states |

**TODO:** replace with the official DEE corporate colors — ask Alysia or Christian
for the exact color codes. Only these two hex values in
`themes/dee/stylesheets/application.css` need to change; nothing else.

# Confluence → Redmine wiki migration — CONCEPT

Scope (Christian, Jul 14): **research how it works + write a concept.** Do NOT
perform the actual migration now.

## Data to move

- Confluence spaces → Redmine projects (1 space ≈ 1 project wiki)
- Pages (incl. hierarchy/parent-child) + attachments + page history

## Migration paths

1. **Confluence export → transform → Redmine wiki API**
   - Confluence: export space to HTML/XML (or use Confluence REST API).
   - Convert page body (Confluence storage format / HTML) → Textile or Markdown
     (Redmine wiki syntax). Hardest step — Confluence macros don't map 1:1.
   - Push via Redmine REST API (`PUT /projects/:id/wiki/:title.json`).

2. **Existing tooling** — check community scripts before building. Likely partial;
   expect custom glue.

## Hard parts / risks

- Confluence macros (info panels, tables, attachments-inline) → no clean Redmine
  equivalent. Lossy.
- Page hierarchy: Redmine wiki supports parent pages — preserve tree.
- Attachments: re-upload + rewrite links.
- History: Redmine keeps wiki versions but bulk-importing old revisions is awkward —
  probably import latest version only, note history stays in archived Confluence.

## Deliverable

Short concept doc: source format, mapping table (Confluence element → Redmine),
tooling choice, lossy-elements list, rough effort estimate. Not code.

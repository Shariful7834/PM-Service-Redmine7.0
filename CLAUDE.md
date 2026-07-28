# Project context for Claude

Continuation of work previously done in `thesis-projects-reiman/redmine`. This
directory is the clean, authoritative workspace.

## What this is and who wants it

Self-hosted **Redmine 7.0** for the **DEE** research group at FH Dortmund,
evaluated as a replacement for the group's paid **Jira + Confluence**, with login
through the **DEE user service** (central SSO, same pattern as the Academic Wallet).

People: **Prof. Christian Reimann** (supervisor, sets the tasks) · **Alysia**
(coordinator, will test) · **Farhat** (servers, Docker, identity provider) ·
**Torsten/Carsten** (own the OTRS ticket system).

Meeting transcripts garble names — Kristen/Kasan Rayman = Christian Reimann,
Farhad/Farut = Farhat, "OTS" = OTRS, "OOTH" = OAuth.

## Requirements, and what is settled

| Requirement | Status |
|---|---|
| Run **Redmine 7.0** — never downgrade to 6.x | done, official image |
| Authorisation via the DEE user service | proven end to end against a local Keycloak stand-in |
| Hands-on feature check vs Jira/Confluence | done, every row tested live |
| Multiple identity providers / IDiAL accounts | answered **yes**, demonstrated with two live IdPs |
| Document every plugin (name, purpose, audit) **inside Redmine** | done — seeded from `docs/wiki/` |
| Match the team colour scheme | `themes/dee/`, two placeholder hex values await the real colours |
| Deploy on a DEE server, then message the team on Teams | **blocked on Farhat** (server + IdP credentials) |
| Confluence → Redmine migration **concept** (not an actual migration) | open, August task |
| OTRS / email ticketing | explicitly out of scope |

Roadmap: August = testing on the server + migration concept · end of September =
migration · new semester (~October) = production. If something proves a
showstopper in August the topic may be cancelled or changed.

## Hard-won facts — do not re-learn these

- **A theme's `application.css` REPLACES Redmine's core stylesheet.** Without
  `@import url(/application.css);` as the first rule, every page renders unstyled
  while still returning HTTP 200. This bug shipped once and was only caught by
  looking at a browser screenshot.
- **`/themes` must be served explicitly** since Redmine 6 (Propshaft compiles to
  `public/assets/themes/`). The `Dockerfile` symlink handles it.
- **`docker compose exec` bypasses the entrypoint**, so `SECRET_KEY_BASE` is not
  set and `rails runner` aborts. Pass it explicitly — the scripts already do.
- **Keycloak's OIDC issuer follows the request host.** Browser and container must
  use the *same* hostname, hence `host.docker.internal:8088` everywhere. Port 8088
  because 8080 is taken by a local Apache/XAMPP on this machine.
- **Redmine 7 UI changed:** no `#loggedas`; "Sign out" is inside an avatar
  dropdown; settings live at `/settings?tab=…`, not `/admin/settings`; issue
  editing is inline (`a.icon-edit`, then `#issue_notes`, submit through
  `#issue-form input[name=commit]` — other hidden submit buttons exist).
- **Agile boards** need a plugin; RedmineUP Agile supports only Redmine ≤ 6.1, so
  on 7.0 this is an open gap, recorded in the ledger. Do not claim otherwise.
- redmine.org publishes **source only** — the `redmine` Docker image comes from
  Docker's official-images programme. 7.0.x is the fully supported line.

## Working agreements

- Verify claims before stating them; the supervisor checks. Never present an
  untested assumption as a result.
- After any UI or theme change, **render it in a browser and look at it**.
  Status codes hide visual breakage. Playwright recipe: `npm i playwright-core`,
  then `chromium.launch({ channel: 'chrome' })` — uses the installed Chrome.
- Git commits here carry **no `Co-Authored-By` trailer** (the supervisor sees this
  repository).
- Secrets belong in `.env` and the database only. Never commit them.
- Keep the workspace minimal — remove anything that stops being necessary.

## Verifying a change

```bash
./scripts/setup.sh          # first run, or after wiping
docker compose up -d        # afterwards
```

Then check: `/admin/info` reports 7.0.0.stable · `/admin/plugins` lists the OAuth
plugin · the login page shows two SSO buttons and both log in · the header is DEE
blue with sans-serif type (not serif — that means the theme broke) ·
`/projects/redmine-admin/wiki` holds the documentation.

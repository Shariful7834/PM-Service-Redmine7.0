# Deployment notes — Redmine 7.0 on a DEE server (handover doc for Farhat)

Goal (from 2026-07-28 meeting): **Redmine running on a DEE server this week**, so
Christian + Alysia can start testing before Christian's holiday (Aug 7–21). One
server only — the production server doubles as test instance for now; a separate
dev server comes later. If there are security concerns, run it as a dev service
behind the firewall. **No secrets in this file** — see `.env.example`.

## What to deploy

`docker-compose.yml` from this repo — now based on the **official** `redmine:7.0`
image (published ~2026-07-27; we migrated off the community image locally and
verified). The compose builds a one-line derivative `dee-redmine:7.0` from the
repo `Dockerfile`: official image + a symlink that fixes `/themes` asset serving
(Redmine ≥6 requirement — theme CSS 404s without it). Services:

| Service | Image | Container port | Notes |
|---|---|---|---|
| redmine | `dee-redmine:7.0` (built FROM official `redmine:7.0`) | 3000 | behind reverse proxy w/ TLS |
| db | `postgres:16-alpine` | 5432 | internal only |
| keycloak | *(local dev only)* | — | **NOT deployed** — replaced by the real DEE user service |

Mounts: `./plugins` → `/usr/src/redmine/plugins` (redmine_oauth), `./themes/dee` →
`/usr/src/redmine/themes/dee` (DEE color theme; two placeholder hex values to
replace with official colors).

On the server, delete/ignore the `keycloak` service block; Redmine's OAuth
provider then points at the real DEE IdP.

## Steps (server)

1. Clone repo, `cp .env.example .env`, fill `DB_PASS` + `REDMINE_SECRET_KEY_BASE`
   (64 hex chars) with server-grade secrets.
2. `docker compose up -d redmine db` (skip keycloak).
3. Entrypoint auto-runs DB migrations, `bundle install` for the plugin gems and —
   because `REDMINE_PLUGINS_MIGRATE=1` — the plugin migrations. No manual rake.
4. Reverse proxy: TLS terminates in front, forward to container port 3000.
   The public URL determines the OAuth callback: `https://<domain>/oauth2callback`.
5. In Redmine `Administration → OAuth providers`: replace the local-Keycloak values
   with the DEE user service (Site = IdP base URL, Tenant = realm, Client-ID +
   Secret from Farhat). Provider config is 4 values + the registered redirect URI.
6. Change the admin password, verify `/admin/info` shows 7.0.x and
   `/admin/plugins` lists "Redmine OAuth plugin".

## Needed from Farhat (blocking)

- [ ] Which server / Docker host? Existing reverse proxy to hook into?
- [ ] Public domain for Redmine → callback URI `https://<domain>/oauth2callback`
- [ ] DEE user service: exact protocol ("OAuth 2.0 or something" per Farhat —
      need issuer/realm URL, and whether it is Keycloak)
- [ ] Client-ID + client secret for Redmine, redirect URI registered
- [ ] Which token claim maps to login/email

## Persistent volumes (backup targets)

- `db_data` → `/var/lib/postgresql/data` (PostgreSQL — pg_dump on schedule)
- `files_data` → `/usr/src/redmine/files` (uploaded attachments)

## Plugin governance (security requirement from 2026-07-28 meeting)

Every plugin must be listed with name/purpose/source and checked regularly for
updates + vulnerabilities. The authoritative list lives **inside Redmine's wiki**
(project "Redmine Administration"). Currently installed: `redmine_oauth` 4.2.0
(Kontron) — OAuth2/OIDC SSO. No other plugins.

## Teams message (paste when live — fill the two placeholders)

> **Redmine 7.0 is live and ready for testing** 🎉
>
> Hi everyone,
>
> our self-hosted Redmine instance is now running on the DEE server:
> **https://<REDMINE-DOMAIN>**
>
> **Login:** use the single-sign-on button on the login page — it works with your
> existing DEE account, no separate registration needed. Your account is created
> automatically on first login.
>
> **What you can test:** projects & sub-projects, issues with custom fields and
> role-based workflows, time tracking, roadmap/versions, per-project wikis with
> attachments, and full-text search. Redmine is our candidate replacement for
> Jira + Confluence.
>
> **Documentation:** the installation, configuration and the plugin security
> ledger are documented inside Redmine itself → project *"Redmine Administration"*.
>
> **Feedback:** please report anything you find (bugs, missing features,
> usability) as an issue in the *"<FEEDBACK-PROJECT>"* project — that way we test
> the issue tracker while using it. 🙂
>
> Known limitation: agile boards (Scrum/Kanban) are not included yet — the plugin
> vendor has not released Redmine 7.0 support; tracked in the security ledger.
>
> Best, Shariful

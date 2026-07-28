# Handover guide — Redmine 7.0 deployment (for Farhat)

**From:** Shariful · **Repo:** https://github.com/Shariful7834/PM-Service-Redmine7.0

## 1. Aim (what Christian asked for)

DEE replaces paid tools with self-hosted services. This Redmine 7.0 instance is
the candidate replacement for **Jira + Confluence** (issues, workflows, wikis,
time tracking). Christian's requirements:

1. **Run it on a DEE server this week** — Christian + Alysia want to start
   testing before his holiday (Aug 7–21). One server only for now: the
   production instance doubles as the test instance; a separate dev server comes
   later. If there are security concerns, run it behind the firewall as a dev
   service.
2. **Login must go through the DEE user service** (same SSO as the Academic
   Wallet) — no separate Redmine accounts.
3. Every plugin is documented in a security ledger inside the Redmine wiki
   (Christian's requirement after past incidents with unpatched plugins).

Everything is prepared and verified locally — deployment is intentionally a
copy-paste job. The only missing inputs are on your side (server + IdP client).

## 2. What the stack is

`docker compose` with two production services (the `keycloak` service in the
compose file is **local development only — do not deploy it**):

| Service | Image | Port | Persistent volume |
|---|---|---|---|
| redmine | `dee-redmine:7.0` — built by compose `FROM redmine:7.0` (official) + one-line `/themes` fix | 3000 | `files_data` → `/usr/src/redmine/files` |
| db | `postgres:16-alpine` | internal 5432 | `db_data` → `/var/lib/postgresql/data` |

The container entrypoint automatically runs DB migrations, `bundle install` for
the plugin gems, and plugin migrations (`REDMINE_PLUGINS_MIGRATE=1`). Only
plugin: `redmine_oauth` 4.2.0 (Kontron) — provides the OAuth2/OIDC login.

## 3. What we need from you

1. **Server / Docker host** — your choice which one.
2. **Public URL** for Redmine (e.g. `https://redmine.<dee-domain>`), reverse
   proxy with TLS in front, forwarding to container port 3000.
3. **An OAuth client in the DEE user service** for Redmine:
   - Confidential client (client authentication ON)
   - Redirect URI: `https://<redmine-domain>/oauth2callback`
   - We need: **issuer/base URL, realm/tenant name, client-id, client secret**,
     and which token claim carries the user's email (Redmine matches by email).
   - You mentioned the user service is "OAuth 2.0 or something" — if it is
     Keycloak, the plugin has a native Keycloak provider type; otherwise its
     generic "Custom OIDC" type works with any OpenID Connect IdP.

## 4. Deployment steps

```bash
git clone https://github.com/Shariful7834/PM-Service-Redmine7.0.git redmine
cd redmine
cp .env.example .env
# edit .env: set strong DB_PASS and REDMINE_SECRET_KEY_BASE (64 hex chars);
# the KEYCLOAK_* variables are unused in production (local dev IdP only)
docker compose up -d redmine db        # note: NOT the keycloak service
docker compose logs -f redmine         # first boot: migrations + bundle, ~1 min
```

Then in the browser:

1. `https://<domain>/login` → log in `admin` / `admin` → change the admin
   password immediately.
2. `Administration → Settings → General` → set host name to the public domain,
   protocol HTTPS.
3. `Administration → OAuth providers` → edit the existing provider (or create
   one): **Site** = IdP base URL · **Tenant ID** = realm · **Client ID/Secret**
   = from step 3 above. That's the entire IdP swap — 4 values.
4. Optional: `Administration → Settings → Display → Theme` = "Dee" (our color
   scheme; placeholder colors, adjustable in `themes/dee/stylesheets/application.css`).

## 5. Verify (5 minutes)

- [ ] `/admin/info` shows **Redmine 7.0.0.stable**
- [ ] `/admin/plugins` lists **Redmine OAuth plugin 4.2.0**
- [ ] Login page shows the SSO button; login with a DEE account works and
      auto-creates the Redmine user
- [ ] Project *"Redmine Administration"* wiki is reachable — contains the
      installation docs + **Plugin Security Ledger** (audit due 2026-08-28)
- [ ] Attachment upload works in any project (files volume writable)

Then Shariful posts the prepared announcement on Teams (text in
`docs/deployment-notes.md`) and Christian/Alysia start testing.

## 6. Ops notes

- **Backups:** `pg_dump` of the `db` database + the `files_data` volume.
- **Secrets:** only in `.env` (gitignored) and the provider config (DB). Nothing
  secret is in the repo.
- **Updates:** watch the `redmine:7.0` tag for 7.0.x security patches
  (redmine.org/Download); plugin updates tracked in the wiki ledger.
- **Local test data** (demo project `dee-eval`) is NOT part of the deployment —
  the server starts with a clean database. If you want the local DB imported
  instead, tell Shariful and he'll hand you a `pg_dump`.

## 7. One open question for you

Can the DEE user service federate the **IDiAL** IdP (identity brokering)?
Multi-provider login (several SSO buttons) is already proven to work in Redmine,
but brokering in the user service would give one button everywhere and unified
accounts — Christian wants a recommendation during August.

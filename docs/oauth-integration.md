# OAuth / OIDC integration — Redmine ↔ central identity provider

Goal: users log into Redmine with the same central login used by all D services
(same pattern as the Academic Wallet). This is a **local proof-of-concept** using a
locally-run Keycloak container — no university VPN/credentials needed. Legitimate,
defensible approach for the colloquium.

## Why a plugin is required

Redmine **core has no OAuth/OIDC login**. A plugin is mandatory.

## Plugin chosen: `redmine_oauth` (Kontron)

Repo: https://github.com/kontron/redmine_oauth

**Why this one:**
- Documented **compatible with Redmine 7.0.x** (also 6.1.x, 6.0.x) — the only
  candidate with stated 7.0 support.
- Widest provider coverage: Azure AD, **Keycloak**, Google, GitHub, GitLab, Okta,
  and generic **Custom OIDC**.
- Config done in UI after install: `Administration → OAuth providers`.
- Callback/redirect URI format: `https://<domain>/oauth2callback`
  (local POC: `http://localhost:3000/oauth2callback`).

**Alternatives considered, rejected (for the report):**
- `redmine_oidc` (Contargo/enricohuang) — OIDC-only, no stated 7.0 support.
- `redmine_omniauth_oidc` — OIDC via OmniAuth, narrower, no stated 7.0 support.

## OIDC flow (plain language)

1. User clicks "Login with SSO" in Redmine.
2. Redmine redirects the browser to the IdP (Keycloak) authorize endpoint.
3. User authenticates at the IdP.
4. IdP redirects back to Redmine `…/oauth2callback` with an auth code.
5. Redmine exchanges the code for tokens (server-to-server), reads the **email
   claim**, matches/creates the Redmine user, opens a session.

## Plugin installation (official image)

The stack runs the official `redmine:7.0` image (via the repo's one-line
`Dockerfile`). Plugin flow: `plugins/redmine_oauth` is bind-mounted to
`/usr/src/redmine/plugins`; the image entrypoint runs `bundle check || bundle
install` on start (plugin gems `jwt`, `oauth2`, `repost` — pure Ruby, no build
tools needed) and, because `REDMINE_PLUGINS_MIGRATE=1` is set, applies plugin
migrations automatically. No manual rake steps.

Implemented in this repo:
- `plugins/redmine_oauth` — cloned `kontron/redmine_oauth` v4.2.0 (requires
  Redmine ≥6.0; runs on 7.0.0 — verified).

## Local Keycloak POC — ✅ VERIFIED WORKING (implemented, reproducible)

**Status: the end-to-end SSO login was verified via a headless run of the full OIDC
Authorization-Code + PKCE flow.** A Keycloak test user logged into Redmine and a real
authenticated session was created (auto-provisioned account). This is exactly the
supervisor's requirement: *"connect it with the user service for authorization."*

Verified chain:
`Redmine SSO button → 302 → Keycloak d-lab authorize (client_id=redmine, PKCE S256,
redirect_uri=/oauth2callback) → login testuser → callback → 302 /my/account → session
as "Test User"`.

Keycloak is wired into `docker-compose.yml` and **imports the realm on first start**
from `keycloak/import/d-lab-realm.json` (rendered from `d-lab-realm.template.json`) —
no manual Keycloak clicking. Realm `d-lab`, confidential client `redmine`, test user
`testuser` / `testuser@example.com`.

**Networking note (important):** Keycloak is addressed as
`http://host.docker.internal:8088` so the OIDC **issuer is identical** whether the
request comes from the browser or from inside the Redmine container. Using `localhost`
there would break token validation (issuer mismatch). The Redmine service has
`extra_hosts: host.docker.internal:host-gateway`. Port is **8088** (host 8080 was
taken by a local Apache/XAMPP).

### Reproduce from scratch

```bash
cp .env.example .env            # fill secrets
docker compose up -d            # redmine + postgres + keycloak (realm auto-imported)
./scripts/provision-oauth-provider.sh   # creates the Keycloak OAuth provider in Redmine
```

`provision-oauth-provider.sh` is idempotent; it sets, in the running Redmine:

| Field | Value |
|---|---|
| oauth_name | `Keycloak` |
| Site | `http://host.docker.internal:8088` |
| Client-ID | `redmine` |
| Secret | `REDMINE_OAUTH_CLIENT_SECRET` from `.env` |
| Tenant ID | `d-lab` |
| self_registration | `3` (auto-create account on first SSO login) |

(Equivalent manual path: `Administration → OAuth providers → Keycloak`, same values.)
Redirect URI already registered in the realm: `http://localhost:3000/oauth2callback`.

### Demo the SSO login

1. Open `http://localhost:3000/login`, log out if needed.
2. Click the **Keycloak** button.
3. Authenticate as **`testuser`** / password = `KEYCLOAK_TEST_USER_PASSWORD` in `.env`.
4. Land in Redmine as that user (account auto-created on first login).

Keycloak admin console (if needed): `http://localhost:8088` — `admin` /
`KEYCLOAK_ADMIN_PASSWORD` from `.env`.

### Swapping in D's real IdP later

Same plugin, same fields — only change **Site** (real IdP base URL), **Tenant ID**
(real realm), **Client-ID/Secret** (issued by Farhat), and register the production
redirect `https://<redmine-domain>/oauth2callback`. Nothing else changes.

## Checklist — what D's REAL identity provider must supply (ACTION: Farhat)

- [ ] Which IdP? (Keycloak? Azure AD? custom) — same one the Wallet uses?
- [ ] Issuer / realm URL (OIDC discovery endpoint)
- [ ] Client ID + client secret (created in the IdP for the Redmine client)
- [ ] Allowed redirect URI registered: `https://<redmine-domain>/oauth2callback`
- [ ] Which claim maps to Redmine login/email
- [ ] Public domain Redmine will run on (needed for the callback URI)

## Open questions for Farhat

Reuse the Wallet's existing IdP client config/discovery URL as the starting point
instead of provisioning from scratch.

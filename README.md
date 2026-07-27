# PM-Service-Redmine7.0

Test install of **Redmine 7.0** for research group DEE (FH Dortmund). Goal: evaluate
Redmine as a self-hosted substitute for **Jira + Confluence**, connected to D's
central identity provider (OAuth/OIDC), same auth pattern as the Academic Wallet.

Owner: Md Shariful Islam · Supervisor: Prof. Christian Reimann · Infra: Farhat.
OTRS / email-ticketing replacement is **out of scope**.

## Quick start (local)

```bash
cp .env.example .env
# edit .env — set DB_PASS and REDMINE_SECRET_TOKEN
docker compose up -d
docker compose logs -f redmine    # first boot runs DB init + migrations
```

Open http://localhost:3000  — default login `admin` / `admin` (forces password change).

Stop / reset:

```bash
docker compose down            # keep data
docker compose down -v         # wipe db + redmine data (fresh install)
```

## Version note — why sameersbn, not the official image

Supervisor requires **Redmine 7.0** (no 6.x). Status (verified 2026-07-20):

- **Redmine 7.0.0 released** — stable, 2026-06-30 (Rails 8, Ruby 4.0, webhooks).
  Source: https://www.redmine.org/news/161
- **Official `library/redmine` has NO 7.x Docker image yet** — `docker manifest
  inspect redmine:7.0` → not found; tops out at `6.1.3`.
- **`sameersbn/redmine:7.0.0` DOES exist** → used here to run genuine 7.0 today.

Trade-off: sameersbn uses a different env-var scheme (`DB_*`, `REDMINE_SECRET_TOKEN`,
container listens on port **80**). When the official 7.0 image lands, can migrate to
it (revert to `REDMINE_DB_*` scheme). Running version confirmed **7.0.0 stable** via
`lib/redmine/version.rb`.

## Task board status (PM-Service Redmine)

**M1 — Test-Installation (end July)**
1. [x] Local Redmine 7.0.0 install running (screenshot `/admin/info` → `docs/screenshots/`)
2. [x] **DEE user service authorisation (OIDC via `redmine_oauth` + Keycloak stand-in) — VERIFIED end-to-end** — [docs/oauth-integration.md](docs/oauth-integration.md)
3. [x] **Feature check — hands-on, every row tested via API/console** — [docs/feature-check.md](docs/feature-check.md)

**M2 — Migration (August)**
4. [x] **Multi-provider OAuth question — YES, demonstrated with two live IdPs; IDiAL-in-DEE = brokering option** — [docs/multi-provider-oauth.md](docs/multi-provider-oauth.md)
5. [ ] Confluence → Redmine data-migration *concept* — [docs/confluence-migration.md](docs/confluence-migration.md)
6. [ ] Deployment on DEE server (needs Farhat: server, real IdP details) — [docs/deployment-notes.md](docs/deployment-notes.md)

## Run the OAuth proof-of-concept

```bash
docker compose up -d                     # redmine + postgres + keycloak (realm auto-imported)
./scripts/provision-oauth-provider.sh    # wire the Keycloak provider into Redmine
# open http://localhost:3000/login -> click "Keycloak" -> login testuser / $KEYCLOAK_TEST_USER_PASSWORD
```

Keycloak admin: `http://localhost:8088` (`admin` / `KEYCLOAK_ADMIN_PASSWORD`).

## Layout

- `docker-compose.yml` — redmine (sameersbn 7.0.0) + postgres
- `.env.example` — config template (copy to `.env`)
- `plugins/` — Redmine plugins (Phase 3: `redmine_oauth`)
- `keycloak/` — local IdP for the OAuth proof-of-concept (Phase 3)
- `docs/` — graded deliverables (feature-check, oauth, deployment, migration) + screenshots

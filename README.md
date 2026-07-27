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

## Version note — why sameersbn (and the migration path to the official image)

Supervisor requires **Redmine 7.0** (no 6.x). The running instance is genuine
**7.0.0 stable** — confirmed via `lib/redmine/version.rb` and `/admin/info`.

Timeline:

- **2026-06-30** — Redmine 7.0.0 released (Rails 8, Ruby 4.0, webhooks).
  Source: https://www.redmine.org/news/161
- **2026-07-20** — official `library/redmine` had **no** 7.x image
  (`docker manifest inspect redmine:7.0` → not found, tops out at `6.1.3`), while
  `sameersbn/redmine:7.0.0` did exist → **sameersbn chosen** to run real 7.0
  rather than downgrade to 6.x.
- **2026-07-27** — the **official `redmine:7.0` / `redmine:7.0.0` images are now
  published**. Migrating to them is a sensible next step, ideally before the
  server deployment.

Migration is more than swapping the image tag — the two images differ in:

| | sameersbn (current) | official |
|---|---|---|
| DB env vars | `DB_ADAPTER`, `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS` | `REDMINE_DB_POSTGRES`, `REDMINE_DB_DATABASE`, `REDMINE_DB_USERNAME`, `REDMINE_DB_PASSWORD` |
| Secret var | `REDMINE_SECRET_TOKEN` | `REDMINE_SECRET_KEY_BASE` |
| Container port | 80 | 3000 |
| Data / plugin dir | `/home/redmine/data` (plugins auto-installed) | `/usr/src/redmine/files`, plugins in `/usr/src/redmine/plugins` (manual `bundle install` + migrate) |

The PostgreSQL database itself is standard Redmine schema, so it carries over.

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

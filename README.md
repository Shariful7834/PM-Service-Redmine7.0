# PM-Service-Redmine7.0

Test install of **Redmine 7.0** for research group DEE (FH Dortmund). Goal: evaluate
Redmine as a self-hosted substitute for **Jira + Confluence**, connected to D's
central identity provider (OAuth/OIDC), same auth pattern as the Academic Wallet.

Owner: Md Shariful Islam · Supervisor: Prof. Christian Reimann · Infra: Farhat.
OTRS / email-ticketing replacement is **out of scope**.

## Quick start (local)

```bash
cp .env.example .env
# edit .env — set DB_PASS and REDMINE_SECRET_KEY_BASE
docker compose up -d
docker compose logs -f redmine    # first boot runs DB init + migrations
```

Open http://localhost:3000  — default login `admin` / `admin` (forces password change).

Stop / reset:

```bash
docker compose down            # keep data
docker compose down -v         # wipe db + redmine data (fresh install)
```

## Image

Runs the **official `redmine:7.0` Docker image** (genuine **7.0.0 stable**,
confirmed via `lib/redmine/version.rb` and `/admin/info`), extended by a one-line
`Dockerfile` (`dee-redmine:7.0`) that fixes `/themes` asset serving — since
Redmine 6 the asset pipeline compiles theme assets to `public/assets/themes/`
while pages link `/themes/`, which must be served explicitly.

History: Redmine 7.0.0 was released 2026-06-30, but the official Docker image
only followed ~2026-07-27. The initial test installation therefore ran on a
community image; the stack was migrated in place to the official image on
2026-07-28 (same PostgreSQL volume — all data preserved and re-verified).

Note on "official": the Redmine project itself distributes only source code
(redmine.org/Download lists no Docker images). The `redmine` image is maintained
by **Docker's official-images program** — a separate channel, which is why
redmine.org says nothing about it. Per redmine.org, **7.0.x is the latest stable
line and the only one receiving new features + full security support** (6.1.x =
fixes only, 6.0.x = legacy); no 7.0.1 patch exists yet as of 2026-07-28.

## Task board status (PM-Service Redmine)

**M1 — Test-Installation (end July)**
1. [x] Local Redmine 7.0.0 install running (verified: `/admin/info` → 7.0.0.stable)
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

- `docker-compose.yml` — redmine (official 7.0 base) + postgres + keycloak (dev IdP)
- `Dockerfile` — `dee-redmine:7.0`: official image + `/themes` serving fix
- `.env.example` — config template (copy to `.env`)
- `plugins/` — Redmine plugins (`redmine_oauth`)
- `themes/dee/` — DEE color theme (two placeholder hex values to swap)
- `keycloak/` — local IdP for the OAuth proof-of-concept (dev only)
- `docs/` — deliverables (feature-check, oauth, multi-provider, deployment, migration)

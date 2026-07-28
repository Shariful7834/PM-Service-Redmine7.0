# Redmine 7.0 — DEE installation documentation

Self-hosted Redmine, evaluated as a replacement for **Jira + Confluence** and
connected to the **DEE user service** for single sign-on.

This wiki is the authoritative documentation of the installation — per the team
decision of 2026-07-28, documentation lives inside Redmine itself. It is seeded
from the project repository (`docs/wiki/`), so it can be recreated on any
instance with one command.

## Setup overview

| Component | Value |
|---|---|
| Redmine | **7.0.0 stable** — official Docker image `redmine:7.0`, extended by a one-line `Dockerfile` (`dee-redmine:7.0`) that fixes `/themes` asset serving |
| Database | PostgreSQL 16 (`postgres:16-alpine`) |
| Authentication | OAuth2 / OpenID Connect — see [[OAuth-Configuration]] |
| Plugins | see [[Plugins]] (Plugin Security Ledger) |
| Theme | custom **dee** theme — see [[Theming]] |
| Repository | contains `docker-compose.yml`, `Dockerfile`, seed scripts and all documentation |

## How it runs

```
docker compose up -d
./scripts/provision-oauth-providers.sh
./scripts/seed-wiki-docs.sh
```

The container entrypoint automatically applies database migrations, installs the
plugin gems (`bundle install`) and runs plugin migrations
(`REDMINE_PLUGINS_MIGRATE=1`) — no manual rake steps.

## Persistent data (backup targets)

* `db_data` → PostgreSQL data directory
* `files_data` → `/usr/src/redmine/files` (attachments)

## History

* **2026-06-30** — Redmine 7.0.0 released.
* **2026-07-20** — first test installation. The official Docker image for 7.0 did
  not exist yet, so a community image was used rather than downgrading to 6.x.
* **2026-07-27** — SSO verified end to end, including multiple identity providers;
  hands-on feature check completed.
* **2026-07-28** — migrated to the **official** image; all data preserved.

Sub-pages: [[Plugins]] · [[OAuth-Configuration]] · [[Theming]]

# PM-Service Redmine 7.0 — DEE

Self-hosted **Redmine 7.0** for the DEE research group (FH Dortmund), evaluated as
a replacement for **Jira + Confluence** and connected to the **DEE user service**
for single sign-on — the same authentication pattern as the Academic Wallet.

Owner: Md Shariful Islam · Supervisor: Prof. Christian Reimann · Infrastructure: Farhat
OTRS / email ticketing is explicitly **out of scope**.

## Quick start

```bash
./scripts/setup.sh
```

Generates `.env` with fresh secrets, renders the Keycloak realms, fetches the OAuth
plugin, builds and starts the stack, registers both identity providers and seeds the
documentation wiki. Then open <http://localhost:3000>.

Everyday commands:

```bash
docker compose up -d      # start
docker compose down       # stop (data kept in volumes)
docker compose down -v    # stop and wipe all data
docker compose logs -f redmine
```

## What is running

| Service | Image | Purpose |
|---|---|---|
| redmine | `dee-redmine:7.0` — built from the official `redmine:7.0` | the application |
| db | `postgres:16-alpine` | database |
| keycloak | `quay.io/keycloak/keycloak:26.0` | **development only** identity provider, standing in for the DEE user service |

The `Dockerfile` adds exactly one thing to the official image: a symlink that makes
`/themes` assets resolvable (required since Redmine 6, otherwise theme CSS 404s).

## Milestones

**M1 — Test installation (due end of July) — complete**

- [x] Redmine 7.0.0 running in Docker with PostgreSQL
- [x] Authorisation through an OAuth2/OIDC user service — verified end to end
- [x] Hands-on feature check → [docs/feature-check.md](docs/feature-check.md)

**M2 — Migration (August)**

- [x] Multiple identity providers possible? → **yes, demonstrated with two live IdPs**, plus the IDiAL/brokering options → [docs/multi-provider-oauth.md](docs/multi-provider-oauth.md)
- [ ] Confluence → Redmine data-migration **concept** → [docs/confluence-migration.md](docs/confluence-migration.md)
- [ ] Deployment on a DEE server → [docs/Handover-to-farhad.md](docs/Handover-to-farhad.md) *(needs server + real IdP credentials)*

## Documentation

Installation, configuration and the **plugin security ledger** live *inside*
Redmine, as the team requires — project *"Redmine Administration"*. The source of
those pages is version-controlled in [docs/wiki/](docs/wiki/) and imported by
`./scripts/seed-wiki-docs.sh`, so every instance gets the same documentation.

Additional documents for the supervisor and for handover are in [docs/](docs/).

## Layout

```
docker-compose.yml      redmine + postgres + keycloak (dev)
Dockerfile              official image + /themes asset fix
.env.example            configuration template (secrets are generated)
scripts/                setup, identity providers, wiki seeding
themes/dee/             DEE colour scheme (two placeholder values)
keycloak/               realm templates for the two development IdPs
docs/                   deliverables, handover, wiki sources
```

## Security notes

- Secrets exist only in `.env` (git-ignored) and in the database; nothing sensitive
  is committed. Realm files containing client secrets are rendered into the
  git-ignored `keycloak/import/`.
- Every plugin must be entered in the security ledger with a recorded audit date —
  see the wiki. Currently one plugin: `redmine_oauth` 4.2.0.
- Change the `admin` password immediately after the first login.

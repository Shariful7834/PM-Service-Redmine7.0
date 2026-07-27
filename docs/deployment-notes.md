# Deployment notes — Redmine 7.0 for a D server (handover to Farhat)

Request-and-handover doc. Local POC is done; this is what's needed to host it on a
D server. **No secrets in this file** — see `.env.example` for variable names.

## Containers + ports

| Service | Image | Container port | Notes |
|---|---|---|---|
| redmine | `sameersbn/redmine:7.0.0` | 80 | behind reverse proxy |
| db | `postgres:16-alpine` | 5432 | internal only |
| keycloak (POC only) | `quay.io/keycloak/keycloak` | 8080 | **not** deployed if D has its own IdP |

Official `library/redmine` has no 7.0 image yet — sameersbn used to get 7.0. Revisit
when the official image ships.

## Persistent volumes (must survive restarts / be backed up)

- `db_data` → `/var/lib/postgresql/data` (PostgreSQL)
- `redmine_data` → `/home/redmine/data` (uploaded files, config, plugins)
- `redmine_logs` → `/var/log/redmine`

## Environment

- Config via `.env` (see `.env.example`). **Never commit real secrets.**
- Required: `DB_PASS`, `REDMINE_SECRET_TOKEN` (64 hex).

## Backup

- PostgreSQL: `pg_dump` of the redmine DB on a schedule.
- Files: back up the `redmine_data` volume (`/home/redmine/data`).

## HTTPS / reverse proxy

- Terminate TLS at a reverse proxy (nginx/Traefik) in front of Redmine.
- Tell Redmine it is behind HTTPS: set `REDMINE_HTTPS=true` and the public
  `REDMINE_PORT`/host so generated URLs + the OAuth `oauth2callback` use `https://`.

## Questions for Farhat (blocking deployment / real OAuth)

- [ ] Which server hosts the container? Existing Docker host / registry to reuse?
- [ ] Public domain/URL for Redmine (needed for OAuth callback `…/oauth2callback`)?
- [ ] Which identity provider does D use (Keycloak? Azure AD? custom)? Same as Wallet?
- [ ] Client ID + secret for the Redmine client (created by Farhat in the IdP)?
- [ ] Issuer/realm URL + which claim maps to Redmine login/email?

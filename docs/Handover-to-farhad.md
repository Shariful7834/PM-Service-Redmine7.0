# Redmine 7.0 — deployment handover

**For:** Farhad (infrastructure) · **From:** Shariful
**Goal:** get Redmine 7.0 live on a DEE server, with login through the DEE User
Service, so Prof. Reimann and Olesja can start testing.

Everything is already built, configured and tested locally. This document is the
complete path from a bare server to a working instance. Budget **30–45 minutes**,
most of it waiting for Docker.

If anything is unclear or behaves differently than described, stop and message me
rather than improvising — I would rather answer a question than debug a surprise.

---

## 0. The short version

For the impatient, this is the whole deployment:

```bash
git clone <repo-url> redmine && cd redmine
git clone --depth 1 https://github.com/kontron/redmine_oauth.git plugins/redmine_oauth
cp .env.example .env        # then edit 4 lines — see section 4.3
./scripts/deploy-server.sh
```

Then point your reverse proxy at `127.0.0.1:3000` and configure the DEE login in
the browser (section 6). The rest of this document explains each part and why it
matters.

---

## 1. Background — what this is for

DEE is replacing bought tools with self-hosted ones. Redmine is the candidate
replacement for **Jira + Confluence**: issue tracking, project wikis, roadmaps,
time tracking.

Prof. Reimann's requirements for this stage:

| # | Requirement | Status |
|---|---|---|
| 1 | Redmine **7.0** (not 6.x) | done — official image |
| 2 | Login via the **DEE User Service**, no separate Redmine passwords | prepared, needs your credentials |
| 3 | Running **on a DEE server** so the team can test | **this document** |
| 4 | Feature check against Jira/Confluence | done |
| 5 | Every plugin documented for vulnerability tracking | done — inside Redmine's wiki |
| 6 | Team colour scheme | done — theme included |

One server is enough for now. The production instance doubles as the test
instance; a separate dev server can come later. If you would rather keep it behind
the firewall for the moment, that is fine — the team only needs to reach it.

**Explicitly out of scope:** replacing OTRS / e-mail ticketing.

---

## 2. What you are deploying

Two containers, defined in `docker-compose.yml`:

| Service | Image | Port | Persistent data |
|---|---|---|---|
| `redmine` | `dee-redmine:7.0` — built from the **official** `redmine:7.0` | 3000 (internal) | volume `files_data` → attachments |
| `db` | `postgres:16-alpine` | 5432 (internal only) | volume `db_data` → database |

The `Dockerfile` adds exactly one thing to the official image: a symlink so
`/themes` assets resolve. Since Redmine 6 the asset pipeline compiles theme files
into `public/assets/themes/` while pages link them under `/themes/` — without the
symlink the theme CSS returns 404.

**One plugin only:** `redmine_oauth` 4.2.0 (Kontron, GPLv3). Redmine core has no
OAuth login; this plugin provides it. It is fetched separately because it is
third-party code and is not vendored into our repository.

> **About `docker-compose.dev.yml`:** the repository also contains a local Keycloak
> that I use on my laptop as a stand-in for the DEE User Service. It lives in a
> separate compose file that a server `.env` never loads, so it cannot start here.
> You do not need to do anything about it.

---

## 3. What I need from you

| # | Item | Notes |
|---|---|---|
| 1 | **A VM with Docker** and the `docker compose` v2 plugin | modest: 2 vCPU / 4 GB RAM / 20 GB disk is plenty |
| 2 | **A public domain**, e.g. `redmine.dee.fh-dortmund.de`, TLS at your reverse proxy, forwarding to `127.0.0.1:3000` | Redmine itself binds to loopback only |
| 3 | **An OAuth client for Redmine in dee.core** | details below |

For item 3, please create a **confidential** client (client authentication on) with
this exact redirect URI:

```
https://<the-public-domain>/oauth2callback
```

PKCE (S256) must be permitted — the plugin always sends a code challenge. Then send
me three values:

- the **base URL** of dee.core, as reachable from the Redmine server
- the **client ID**
- the **client secret**

**Nothing else is needed.** I took the endpoint layout from the Academic Wallet's
working dee.core integration (`server/dee-core.js`):

```
authorize : <base>/oauth/authorize
token     : <base>/oauth/token
userinfo  : <base>/oauth/userinfo
scope     : openid profile email
```

---

## 4. Deployment

### 4.1 Clone the repository

```bash
git clone <repo-url> redmine
cd redmine
```

### 4.2 Fetch the authentication plugin

```bash
git clone --depth 1 https://github.com/kontron/redmine_oauth.git plugins/redmine_oauth
```

*Why separately:* it is third-party code, so we track the exact upstream version
instead of copying it into our repository. It is recorded in the plugin security
ledger inside Redmine.

### 4.3 Configure — the only file you edit

```bash
cp .env.example .env
```

Open `.env` and make **these four changes**. Everything else can stay as it is.

| # | Line | Change to | Why |
|---|---|---|---|
| 1 | `COMPOSE_PATH_SEPARATOR=";"`<br>`COMPOSE_FILE="docker-compose.yml;docker-compose.dev.yml"` | **delete both lines** | They load my local demo login server. Removing them means only Redmine + PostgreSQL start. |
| 2 | `REDMINE_BIND=0.0.0.0` | `REDMINE_BIND=127.0.0.1` | Redmine is then reachable only through your reverse proxy, never directly from the network. |
| 3 | `DB_PASS=change-me` | output of `openssl rand -hex 32` | database password |
| 4 | `REDMINE_SECRET_KEY_BASE=change-me` | output of `openssl rand -hex 64` | Rails session signing key — changing it later invalidates all sessions |

The `KEYCLOAK_*`, `*_CLIENT_SECRET` and `*_TEST_USER_PASSWORD` entries belong to my
local demo setup and do nothing on a server. Leave or delete them, as you prefer.

> `.env` is git-ignored on purpose — it is the only place secrets live.

### 4.4 Deploy

```bash
./scripts/deploy-server.sh
```

The script is idempotent and refuses to run if the configuration still looks like a
developer machine or still contains placeholder secrets. It will:

1. build the image and start both containers
2. wait until Redmine answers
3. **load Redmine's default configuration data** — trackers, issue statuses,
   workflows, priorities, roles
4. install the documentation wiki
5. print the remaining manual steps

**Step 3 is not optional.** A fresh Redmine database contains none of that data, and
the official image does not create it. Without it Redmine starts and looks healthy,
but creating an issue fails with **HTTP 500**. The script handles it — I mention it
so the behaviour is not a mystery if you ever rebuild by hand.

<details>
<summary>Equivalent manual commands, if you prefer</summary>

```bash
docker compose up -d --build

docker compose exec -e SECRET_KEY_BASE="$REDMINE_SECRET_KEY_BASE" redmine \
  bundle exec rake redmine:load_default_data RAILS_ENV=production REDMINE_LANG=en

./scripts/seed-wiki-docs.sh
```
</details>

First start takes about a minute: database migrations plus installing the plugin's
gems.

---

## 5. Reverse proxy

Terminate TLS at your proxy and forward to `127.0.0.1:3000`. Redmine needs the
original host and scheme to build correct URLs:

```nginx
location / {
    proxy_pass         http://127.0.0.1:3000;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
    client_max_body_size 20m;   # file attachments
}
```

`https://<the-public-domain>` should now show the Redmine login page.

---

## 6. Connect the DEE login

Open the site and log in with **`admin` / `admin`**.

**a) Change the admin password immediately.**

**b) Administration → Settings → General**

- *Host name*: the public domain
- *Protocol*: HTTPS

Otherwise links in notification e-mails point at `localhost:3000`.

**c) Administration → OAuth providers → new provider**

dee.core is an Auth0-compatible OAuth 2.0 service rather than Keycloak, so use the
**Custom** provider type:

| Field | Value |
|---|---|
| Provider | **`Custom`** |
| Display name | `DEE User Service` |
| Site | base URL of dee.core |
| Tenant ID | *leave empty* (unused in Custom mode) |
| Client ID | from section 3 |
| Client secret | from section 3 |
| Authorization endpoint | `<base>/oauth/authorize` |
| Token endpoint | `<base>/oauth/token` |
| Profile (userinfo) endpoint | `<base>/oauth/userinfo` |
| Scope | `openid profile email` |
| UID field | `preferred_username` |
| E-mail field | `email` |
| Firstname / Lastname field | `given_name` / `family_name` |

**d) Administration → Settings → Display → Theme** → `Dee`

**e) Log out and sign in through the new button.**

The flow is standard OpenID Connect Authorization Code with PKCE. Users are matched
by **e-mail address**, and a Redmine account is created automatically on first
login — nobody needs to be pre-registered.

> **Adding IDiAL later:** each configured provider gets its own button on the login
> page; there is no limit of one. If DEE decides to offer IDiAL as well, repeat step
> (c) with IDiAL's own client credentials. I have already tested two providers
> running side by side.

---

## 7. Verify it worked

| Check | Expected |
|---|---|
| `/admin/info` | **Redmine 7.0.0.stable** |
| `/admin/plugins` | **Redmine OAuth plugin 4.2.0** |
| Login page | SSO button present; a DEE account logs in and is created automatically |
| Create an issue in any project | works (proves the default data step ran) |
| Project **"Redmine Administration"** | contains installation notes and the **Plugin Security Ledger** |
| Upload a file to an issue | works (proves the files volume is writable) |

When these pass, tell me — I will announce it to the team on Teams, and Christian
and Olesja start testing.

---

## 8. Troubleshooting

**Redmine does not answer after a minute or two**
`docker compose logs -f redmine`. First start runs migrations and installs gems; it
is slow, but should end with the server listening on 3000.

**"Missing `secret_key_base` for 'production'"**
You ran a `rails`/`rake` command through `docker compose exec`, which bypasses the
container's start-up script. Add `-e SECRET_KEY_BASE="$REDMINE_SECRET_KEY_BASE"`.

**Creating an issue returns HTTP 500**
The default configuration data was not loaded — see section 4.4, step 3.

**The interface looks unstyled** (serif fonts, no layout)
The theme's CSS is not being served. It should not happen with the provided image,
but if it does, tell me — it is a known trap with Redmine themes and I have the fix
documented.

**SSO fails with an invalid `redirect_uri`**
The URI registered in dee.core must match exactly, including scheme and host:
`https://<the-public-domain>/oauth2callback`.

**SSO returns but the user is not logged in**
Usually the e-mail claim: check that the token actually carries `email`, and that
the *E-mail field* in the provider configuration matches the claim name.

---

## 9. Running it afterwards

**Backups** — the database and the uploaded files:

```bash
docker compose exec -T db pg_dump -U "$DB_USER" "$DB_NAME" > redmine-$(date +%F).sql
docker run --rm -v redmine_files_data:/f -v "$PWD":/out alpine \
  tar czf /out/redmine-files-$(date +%F).tar.gz -C /f .
```

`docker compose down` keeps all data; only `docker compose down -v` destroys it.

**Updates** — 7.0.x patch releases are listed at
<https://www.redmine.org/projects/redmine/wiki/Download>. Change `REDMINE_VERSION`
in `.env` and run `docker compose up -d --build`; migrations run automatically.

**Plugins** — a team rule from Prof. Reimann, after past incidents with unpatched
plugins: **every plugin must be recorded in the Plugin Security Ledger** inside
Redmine (project *"Redmine Administration"*) with name, version, purpose, source and
an audit date. Please do not add plugins without an entry there. Currently there is
exactly one: `redmine_oauth` 4.2.0, next audit due **2026-08-28**.

**Logs** — `docker compose logs -f redmine`

---

## 10. After go-live

1. You confirm the instance is reachable.
2. I finish the DEE login configuration and verify it end to end.
3. I announce it on Teams; Christian and Olesja begin testing.
4. During August: a concept for migrating the Confluence content into Redmine.
5. Target: full production use from the start of the new semester.

Thanks — and again, please ask rather than improvise if anything looks different
from what is written here.

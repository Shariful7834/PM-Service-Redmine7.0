# Deploying Redmine 7.0 on a DEE server — guide for Farhat

**From:** Shariful. Ask me anything at any point — nothing here is urgent enough
to guess at.

---

## 1. The aim

Put **Redmine 7.0** on a DEE server so that people log in with the **account they
already have** — through the DEE user service — instead of a separate Redmine
password. Christian and Alysia want to start testing this week.

Redmine is being evaluated as our self-hosted replacement for Jira and Confluence.

**Done means:** `https://redmine.<our-domain>` opens, there is a **"Sign in with
DEE"** button on the login page, clicking it authenticates against the DEE user
service, and the user lands in Redmine with an account created automatically.
If we also want IDiAL, a second button appears next to it.

Six steps get you there:

| Step | What happens | Roughly |
|---|---|---|
| 1 | Get the code onto the server | 1 min |
| 2 | Fetch the login plugin | 1 min |
| 3 | Edit `.env` — **the only file you change** | 5 min |
| 4 | Run the deploy script (Redmine + database come up) | 10 min |
| 5 | Point your reverse proxy at it | 5 min |
| 6 | Register the OAuth client and enter 4 values in Redmine | 10 min |

---

## 2. What you actually touch

This is the whole list. **Inside the project you edit exactly one file.**

| What | Action | Where |
|---|---|---|
| **`.env`** | **The only file you edit** — 4 lines (step 3) | in the project |
| `plugins/redmine_oauth/` | fetched with one `git clone` — you do not edit it | in the project |
| OAuth client for Redmine | register it in the DEE user service | your IdP admin |
| Reverse proxy config | one `location` block | your usual nginx/Apache config |

Everything else — `docker-compose.yml`, `Dockerfile`, the scripts, the theme — is
already prepared and needs **no changes**.

---

## 3. What I need from you

1. **A server** that runs Docker (`docker compose` v2).
2. **A public domain**, e.g. `redmine.dee.fh-dortmund.de`, TLS terminated at your
   reverse proxy, forwarding to `127.0.0.1:3000`.
3. **An OAuth2 / OpenID Connect client** for Redmine in the DEE User Service:
   - **confidential** client (client authentication switched on)
   - allowed redirect URI, exactly:
     ```
     https://<the-public-domain>/oauth2callback
     ```
   - scope `openid profile email` permitted, and PKCE (S256) allowed — the plugin
     always sends a code challenge

   You confirmed the DEE User Service is **not Keycloak** but a custom OIDC
   service on standard OAuth 2.0, so Redmine uses the plugin's **"Custom"**
   provider mode. That mode needs the endpoints spelled out. Please send me:

   | Value | Example |
   |---|---|
   | base URL (issuer, no path) | `https://users.dee.fh-dortmund.de` |
   | **authorization endpoint** | `.../protocol/openid-connect/auth` |
   | **token endpoint** | `.../protocol/openid-connect/token` |
   | **userinfo endpoint** (optional — if omitted the plugin reads the token itself) | `.../protocol/openid-connect/userinfo` |
   | client ID | `redmine` |
   | client secret | (secret) |
   | claim holding the e-mail address | usually `email` |
   | claim holding the username | usually `preferred_username` |

> If the service publishes an OpenID discovery document
> (`<base-url>/.well-known/openid-configuration`), just send me that URL — every
> endpoint above is listed in it and I can read the rest myself.

I have already configured and tested exactly this "Custom" mode locally against a
standard OIDC provider, and the login works end to end — so the shape of the
configuration is proven before we touch the real service.

---

## 4. Step 1 — get the code

*Aim: have the project on the server.*

```bash
git clone <repository-url> redmine
cd redmine
```

## 5. Step 2 — fetch the login plugin

*Aim: Redmine has no OAuth login of its own; this plugin adds it.*

It is third-party code, so it is not committed into our repository:

```bash
git clone --depth 1 https://github.com/kontron/redmine_oauth.git plugins/redmine_oauth
```

## 6. Step 3 — edit `.env` (the only file you edit)

*Aim: configure this instance as a server instead of my laptop.*

```bash
cp .env.example .env
```

Now open `.env` and make **these four changes**. Everything else stays as it is.

| # | Line in `.env` | What to do | Why it matters |
|---|---|---|---|
| 1 | `COMPOSE_PATH_SEPARATOR=;`<br>`COMPOSE_FILE=docker-compose.yml;docker-compose.dev.yml` | **delete both lines** | They add the demo login server I use on my laptop. Deleting them means only Redmine + database start on the server. |
| 2 | `REDMINE_BIND=0.0.0.0` | change to `REDMINE_BIND=127.0.0.1` | Redmine is then reachable **only** through your reverse proxy, never directly from the network. |
| 3 | `DB_PASS=change-me` | replace with `openssl rand -hex 32` | database password |
| 4 | `REDMINE_SECRET_KEY_BASE=change-me` | replace with `openssl rand -hex 64` | Rails session signing key |

The `KEYCLOAK_*`, `*_CLIENT_SECRET` and `*_TEST_USER_PASSWORD` entries belong to
my local demo login server. They do nothing on the server — leave them or delete
them, both are fine.

> `.env` is excluded from Git on purpose. It is the only place secrets live.

## 7. Step 4 — deploy

*Aim: Redmine and the database running on the server.*

```bash
./scripts/deploy-server.sh
```

It refuses to run if `.env` still points at the demo login server or still has
placeholder secrets, so it cannot quietly do the wrong thing. It builds the image,
starts both containers, loads Redmine's default configuration data, installs the
documentation, and prints what is left to do.

First start takes about a minute (database migrations + plugin gems).

<details>
<summary>If you prefer to run the commands yourself</summary>

```bash
docker compose up -d --build

# REQUIRED on a fresh database: a new Redmine has no trackers, issue statuses or
# workflows, and the official image does not create them. Without this, creating
# an issue fails with HTTP 500.
docker compose exec -e SECRET_KEY_BASE="$REDMINE_SECRET_KEY_BASE" redmine \
  bundle exec rake redmine:load_default_data RAILS_ENV=production REDMINE_LANG=en

./scripts/seed-wiki-docs.sh
```
</details>

## 8. Step 5 — reverse proxy

*Aim: users reach Redmine over HTTPS on the public domain.*

Terminate TLS at your proxy and forward to `127.0.0.1:3000`. Redmine needs the
original host and scheme:

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

Now `https://<the-public-domain>` should show the Redmine login page.

## 9. Step 6 — the login with DEE (and optionally IDiAL)

*Aim: the actual point of the whole exercise — people sign in with their DEE account.*

Log in at `https://<the-public-domain>` with **`admin` / `admin`**.

**a) Change the admin password immediately.**

**b) Administration → Settings → General**
- Host name: the public domain
- Protocol: HTTPS

(Otherwise links in notification e-mails point at `localhost:3000`.)

**c) Administration → OAuth providers → new provider** — this creates the DEE
login button. Since the DEE User Service is a custom OIDC service, choose the
**Custom** provider type and fill in:

| Field | Value |
|---|---|
| Provider | **`Custom`** |
| Display name | `DEE User Service` |
| Site | base URL of the DEE User Service |
| Tenant ID | leave empty (unused in Custom mode) |
| Client ID | the client ID |
| Client secret | the client secret |
| Authorization endpoint | from the discovery document |
| Token endpoint | from the discovery document |
| Profile (userinfo) endpoint | from the discovery document — may be left empty |
| Scope | `openid profile email` |
| UID field | `preferred_username` |
| E-mail field | `email` |
| Firstname / Lastname field | `given_name` / `family_name` |

These exact settings are already proven working in the test instance.

**d) Administration → Settings → Display → Theme** → `Dee`

**e) Log out and sign in through the new button** to confirm it works. The Redmine
account is created automatically on first login, matched by e-mail address.

### Adding IDiAL as a second login

Each configured provider gets **its own button** on the login page — there is no
limit of one. To offer IDiAL as well, repeat step **c** with IDiAL's values
(its own client ID and secret, registered on the IDiAL side with the same
`https://<domain>/oauth2callback` redirect URI). Users then see two buttons and
pick the one they belong to.

I have already tested exactly this locally with two providers side by side, so we
know it works before you touch the real ones.

> There is a nicer long-term option, if the DEE user service supports it:
> **identity brokering**, where the DEE user service itself accepts IDiAL as an
> upstream provider. Then every DEE service keeps a single login button and IDiAL
> users get normal DEE accounts. Christian wants a recommendation in August — no
> action needed now, but tell me if you know whether our user service can do it.

---

## 10. Check it worked

- `/admin/info` shows **Redmine 7.0.0.stable**
- `/admin/plugins` lists **Redmine OAuth plugin 4.2.0**
- The SSO button logs a DEE user in and creates the account automatically
- Creating an issue in a project works (this proves the default-data step ran)
- The project **"Redmine Administration"** contains the installation notes and the
  **Plugin Security Ledger**

Then tell me, and I will announce it to the team on Teams.

---

## 11. Things that will trip you up

**Never run `scripts/setup.sh` on the server.** That is the developer script; it
starts the demo login server. It refuses to run against a server `.env` — please
do not work around it.

**`docker compose exec` skips the container's start-up script**, so any manual
`rails` or `rake` command needs `-e SECRET_KEY_BASE="$REDMINE_SECRET_KEY_BASE"`.
Without it Rails aborts with a confusing "missing secret_key_base" error.

**The database is a Docker volume**, not a folder in the project directory.
`docker compose down` keeps it — only `docker compose down -v` deletes it.

**The first start is slow** (~1 min). `docker compose logs -f redmine` shows
progress.

---

## 12. Running it afterwards

**Backup** — database and uploaded files:

```bash
docker compose exec -T db pg_dump -U "$DB_USER" "$DB_NAME" > redmine-$(date +%F).sql
docker run --rm -v redmine_files_data:/f -v "$PWD":/out alpine \
  tar czf /out/redmine-files-$(date +%F).tar.gz -C /f .
```

**Updates** — 7.0.x patch releases appear on
<https://www.redmine.org/projects/redmine/wiki/Download>. Change `REDMINE_VERSION`
in `.env`, then `docker compose up -d --build`. Migrations run automatically.

**Plugins** — only one is installed (`redmine_oauth` 4.2.0). Team rule from
Christian: every plugin gets an entry in the Plugin Security Ledger inside Redmine
with an audit date, because unpatched plugins have caused problems before. Please
don't add plugins without recording them there.

**Logs** — `docker compose logs -f redmine`

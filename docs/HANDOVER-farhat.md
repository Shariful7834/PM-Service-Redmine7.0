# Deploying Redmine 7.0 on a DEE server — guide for Farhat

**From:** Shariful · Questions: ask me any time, nothing here is urgent enough to guess at.

Everything has been built and tested locally. This guide is the exact path from a
clean server to a working instance. It takes roughly 30 minutes, most of it
waiting for Docker.

---

## 1. What this is, in three sentences

Redmine 7.0 is being evaluated as DEE's self-hosted replacement for Jira and
Confluence. It must authenticate against the **DEE user service**, so people log
in with the account they already have — no separate Redmine passwords. Christian
and Alysia want to start testing on a real server this week.

It runs as two Docker containers: Redmine itself and a PostgreSQL database.

---

## 2. What I need from you (before you start)

| # | Needed | Used for |
|---|---|---|
| 1 | A server / Docker host | running the two containers |
| 2 | A public domain, e.g. `redmine.dee.fh-dortmund.de`, with TLS terminated by your reverse proxy, forwarding to port 3000 on localhost | users reach Redmine over HTTPS |
| 3 | An **OAuth2 / OpenID Connect client** registered for Redmine in the DEE user service | single sign-on |

For item 3, the client must be **confidential** (client authentication on) and
must permit this exact redirect URI:

```
https://<the-public-domain>/oauth2callback
```

and I need these values back from you:

- the **base URL** of the DEE user service (the issuer, without any path)
- the **realm / tenant** name
- the **client ID**
- the **client secret**
- which **claim** carries the user's e-mail address (Redmine matches accounts by e-mail)

> You mentioned the user service speaks "OAuth 2.0 or something". If it is
> **Keycloak**, the plugin has a native Keycloak mode and only needs the four
> values above. If it is something else that speaks OpenID Connect, the plugin
> has a generic "Custom" mode where the endpoints are entered manually — tell me
> which it is and I will prepare the exact settings.

---

## 3. Deployment

### 3.1 Get the code

```bash
git clone <repository-url> redmine
cd redmine
```

### 3.2 Fetch the authentication plugin

Redmine has no OAuth login of its own; it comes from one plugin. It is not part
of this repository (it is third-party code), so fetch it explicitly:

```bash
git clone --depth 1 https://github.com/kontron/redmine_oauth.git plugins/redmine_oauth
```

### 3.3 Create the configuration

```bash
cp .env.example .env
```

Now edit `.env`. **Four changes matter — the rest can stay as they are:**

| In `.env` | What to do | Why |
|---|---|---|
| `COMPOSE_PATH_SEPARATOR=` and `COMPOSE_FILE=` | **Delete both lines** | They add a local demo identity provider used only on my laptop. On a server it must not run. |
| `REDMINE_BIND=0.0.0.0` | change to `REDMINE_BIND=127.0.0.1` | Redmine is then only reachable through your reverse proxy, never directly from the network |
| `DB_PASS=change-me` | a real secret: `openssl rand -hex 32` | database password |
| `REDMINE_SECRET_KEY_BASE=change-me` | a real secret: `openssl rand -hex 64` | Rails session signing key |

The `KEYCLOAK_*`, `*_CLIENT_SECRET` and `*_TEST_USER_PASSWORD` entries belong to
my local demo identity provider. They are unused on the server — leave them or
delete them, either is fine.

> `.env` is deliberately excluded from Git. It is the only place secrets live.

### 3.4 Deploy

```bash
./scripts/deploy-server.sh
```

The script refuses to run if `.env` still points at the demo identity provider or
still contains placeholder secrets, so it cannot quietly do the wrong thing. It
builds the image, starts both containers, loads Redmine's default configuration
data, installs the documentation, and prints the remaining steps.

**If you would rather do it by hand**, this is precisely what it runs:

```bash
docker compose up -d --build

# REQUIRED on a fresh database. A new Redmine has no trackers, issue statuses or
# workflows, and the official image does not create them — without this step,
# creating an issue fails with HTTP 500.
docker compose exec -e SECRET_KEY_BASE="$REDMINE_SECRET_KEY_BASE" redmine \
  bundle exec rake redmine:load_default_data RAILS_ENV=production REDMINE_LANG=en

./scripts/seed-wiki-docs.sh
```

### 3.5 Reverse proxy

Terminate TLS at your proxy and forward to `127.0.0.1:3000`. Redmine needs the
original host and scheme, for example with nginx:

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

---

## 4. Configuration in the browser (about 5 minutes)

Open `https://<the-public-domain>` and log in with **`admin` / `admin`**.

1. **Change the admin password immediately.**

2. **Administration → Settings → General**
   - Host name: the public domain
   - Protocol: HTTPS

   Without this, links in notification e-mails point at `localhost:3000`.

3. **Administration → OAuth providers → new provider** — this is the actual
   single-sign-on step:

   | Field | Value |
   |---|---|
   | Provider | `Keycloak` (or `Custom` for another OIDC service) |
   | Site | base URL of the DEE user service |
   | Tenant ID | the realm name |
   | Client ID | the client ID |
   | Client secret | the client secret |

4. **Administration → Settings → Display → Theme** → `Dee` (the DEE colour
   scheme; the exact colours are still placeholders until the team gives me the
   official values).

5. Log out and sign in once using the SSO button.

---

## 5. Check it worked

- `/admin/info` shows **Redmine 7.0.0.stable**
- `/admin/plugins` lists **Redmine OAuth plugin 4.2.0**
- The login page shows an SSO button, and logging in with a DEE account works
  and creates the Redmine account automatically
- Creating an issue in any project works (proves the default data step ran)
- The project **"Redmine Administration"** contains the installation
  documentation and the **Plugin Security Ledger**

Then tell me, and I will announce it to the team on Teams.

---

## 6. Things that will trip you up

**Redmine takes about a minute on first start.** It runs database migrations and
installs the plugin's gems. `docker compose logs -f redmine` shows progress; it
is ready when it answers on port 3000.

**Never run `scripts/setup.sh` on the server.** That is the developer script and
it starts the demo identity provider. It refuses to run against a server `.env`,
but do not fight it.

**`docker compose exec` skips the container's start-up script**, so any manual
`rails`/`rake` command needs `-e SECRET_KEY_BASE="$REDMINE_SECRET_KEY_BASE"`,
otherwise Rails aborts with a confusing "missing secret_key_base" error.

**The database is a Docker volume**, not a folder in the project directory.
`docker compose down` keeps it; only `docker compose down -v` deletes it.

---

## 7. Operating it

**Backup** — the database and the uploaded files:

```bash
docker compose exec -T db pg_dump -U "$DB_USER" "$DB_NAME" > redmine-$(date +%F).sql
docker run --rm -v redmine_files_data:/f -v "$PWD":/out alpine \
  tar czf /out/redmine-files-$(date +%F).tar.gz -C /f .
```

**Updates** — Redmine 7.0.x patch releases are announced on
<https://www.redmine.org/projects/redmine/wiki/Download>. Change `REDMINE_VERSION`
in `.env`, then `docker compose up -d --build`. Migrations run automatically.

**Plugins** — only one is installed (`redmine_oauth` 4.2.0). Team rule: every
plugin is recorded in the Plugin Security Ledger inside Redmine with an audit
date, because unpatched plugins have caused problems before. Please do not add
plugins without an entry there.

**Logs** — `docker compose logs -f redmine`

---

## 8. One question for later

Can the DEE user service federate the **IDiAL** identity provider (identity
brokering)? Redmine can show several SSO buttons — I have that working with two
providers — but if the user service brokered IDiAL instead, every DEE service
would keep a single login button and IDiAL users would get normal DEE accounts.
Christian would like a recommendation during August. No action needed now.

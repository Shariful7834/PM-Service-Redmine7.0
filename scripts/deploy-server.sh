#!/usr/bin/env bash
# Server deployment for Redmine 7.0.
#
#   ./scripts/deploy-server.sh
#
# Starts Redmine + PostgreSQL, loads Redmine's default configuration data and
# installs the documentation wiki. The local demo identity provider is NOT part
# of this — authentication is configured against the real DEE user service in the
# web interface afterwards (the script prints the exact steps).
#
# Safe to re-run: every step checks its own state first.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo; echo "ERROR: $*" >&2; exit 1; }

command -v docker >/dev/null || fail "docker is not installed"
docker info >/dev/null 2>&1 || fail "the Docker daemon is not running"
docker compose version >/dev/null 2>&1 || fail "the 'docker compose' plugin is missing"

[ -f .env ] || fail ".env is missing. Copy .env.example to .env and fill it in first (see docs/HANDOVER-farhat.md section 3)."

# shellcheck disable=SC1091
set -a; . ./.env; set +a

# ------------------------------------------------------------- sanity checks
for v in DB_PASS REDMINE_SECRET_KEY_BASE; do
  val="${!v:-}"
  [ -n "$val" ] || fail "$v is not set in .env"
  [ "$val" != "change-me" ] || fail "$v is still 'change-me' — set a real secret (openssl rand -hex 32)"
done

if grep -q '^COMPOSE_FILE=.*docker-compose.dev.yml' .env; then
  fail "This .env still loads docker-compose.dev.yml, which starts the local demo
  identity provider. On a server, remove the COMPOSE_FILE and COMPOSE_PATH_SEPARATOR
  lines from .env and run this script again."
fi

if [ "${REDMINE_BIND:-0.0.0.0}" = "0.0.0.0" ]; then
  echo "WARNING: REDMINE_BIND is 0.0.0.0, so Redmine is reachable directly on"
  echo "         port ${REDMINE_PORT:-3000} from the network, bypassing the reverse proxy."
  echo "         Recommended for a server: REDMINE_BIND=127.0.0.1"
  echo
  printf "Continue anyway? [y/N] "
  read -r answer
  [ "$answer" = "y" ] || [ "$answer" = "Y" ] || fail "aborted by user"
fi

[ -d plugins/redmine_oauth ] || fail "the OAuth plugin is missing. Run:
  git clone --depth 1 https://github.com/kontron/redmine_oauth.git plugins/redmine_oauth"

# --------------------------------------------------------------------- start
echo "[1/4] building and starting Redmine + PostgreSQL"
docker compose up -d --build

echo "      waiting for Redmine to answer..."
code=""
for _ in $(seq 1 120); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${REDMINE_PORT:-3000}/login" || true)
  [ "$code" = "200" ] && break
  sleep 3
done
[ "$code" = "200" ] || fail "Redmine did not start. Inspect the logs: docker compose logs redmine"
echo "      Redmine is up"

# -------------------------------------------------------------- default data
# A fresh database has no trackers, issue statuses, workflows, priorities or
# roles. The official image does not load them, and without them creating an
# issue fails with HTTP 500.
echo "[2/4] loading Redmine default configuration data"
docker compose exec -T \
  -e SECRET_KEY_BASE="${REDMINE_SECRET_KEY_BASE}" \
  redmine bundle exec rails runner '
if Redmine::DefaultData::Loader.no_data?
  Redmine::DefaultData::Loader.load("en")
  puts "      loaded"
else
  puts "      already present — skipped"
end
raise "default data missing" if Tracker.count.zero?
puts "      trackers=#{Tracker.count} statuses=#{IssueStatus.count} workflows=#{WorkflowTransition.count}"
' RAILS_ENV=production

# ------------------------------------------------------------- documentation
echo "[3/4] installing the documentation wiki"
./scripts/seed-wiki-docs.sh >/dev/null
echo "      documentation and plugin security ledger installed"

# -------------------------------------------------------------------- checks
echo "[4/4] verifying"
docker compose exec -T -e SECRET_KEY_BASE="${REDMINE_SECRET_KEY_BASE}" redmine \
  bundle exec rails runner '
puts "      Redmine #{Redmine::VERSION}"
puts "      plugins: #{Redmine::Plugin.all.map { |p| "#{p.id} #{p.version}" }.join(", ")}"
puts "      admin password is still the default" if User.find_by_login("admin")&.check_password?("admin")
' RAILS_ENV=production

cat <<EOF

────────────────────────────────────────────────────────────────────
 Redmine is running on 127.0.0.1:${REDMINE_PORT:-3000}

 REMAINING MANUAL STEPS (in the browser, through your reverse proxy):

 1. Log in as  admin / admin  and change the password immediately.

 2. Administration -> Settings -> General
      Host name         : <the public domain>
      Protocol          : HTTPS

 3. Administration -> OAuth providers -> new provider
      Provider    : Keycloak   (or "Custom" for a non-Keycloak OIDC service)
      Site        : <base URL of the DEE user service>
      Tenant ID   : <realm name>
      Client ID   : <client id issued for Redmine>
      Client secret: <client secret>
    The identity provider must allow the redirect URI:
      https://<the public domain>/oauth2callback

 4. Administration -> Settings -> Display -> Theme : Dee

 5. Log out and sign in once through the SSO button to confirm it works.

 Documentation lives inside Redmine: project "Redmine Administration".
────────────────────────────────────────────────────────────────────
EOF

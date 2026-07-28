#!/usr/bin/env bash
# One-command bootstrap for the local development / evaluation instance.
#
#   ./scripts/setup.sh
#
# Creates .env with freshly generated secrets (never overwrites an existing one),
# renders the Keycloak realm imports, fetches the OAuth plugin, starts the stack,
# registers the identity providers and seeds the documentation wiki.
#
# For the production server the identity provider is the real DEE user service,
# not the bundled Keycloak — see docs/HANDOVER-farhat.md.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "the Docker daemon is not running" >&2; exit 1; }

rand() { openssl rand -hex "$1"; }

# ---------------------------------------------------------------- 1. secrets
if [ -f .env ]; then
  echo "[1/7] .env already exists — keeping it (delete it to regenerate)"
else
  echo "[1/7] generating .env with fresh secrets"
  cp .env.example .env
  # portable in-place edit (works with both GNU and BSD sed)
  set_var() { sed -i.bak "s|^$1=.*|$1=$2|" .env && rm -f .env.bak; }
  set_var DB_PASS                     "$(rand 16)"
  set_var REDMINE_SECRET_KEY_BASE     "$(rand 64)"
  set_var KEYCLOAK_ADMIN_PASSWORD     "$(rand 12)"
  set_var REDMINE_OAUTH_CLIENT_SECRET "$(rand 24)"
  set_var IDIAL_CLIENT_SECRET         "$(rand 24)"
  set_var KEYCLOAK_TEST_USER_PASSWORD "$(rand 8)"
  set_var IDIAL_TEST_USER_PASSWORD    "$(rand 8)"
fi

# This script is for developer machines, where the local Keycloak must be part of
# the stack. Refuse to run against a server-style .env instead of silently
# configuring a demo identity provider on a production instance.
if ! grep -q '^COMPOSE_FILE=.*docker-compose.dev.yml' .env; then
  cat >&2 <<'MSG'
This .env has no development identity provider configured (COMPOSE_FILE does not
include docker-compose.dev.yml), which means it looks like a SERVER setup.

scripts/setup.sh is for local development only. To deploy on a server, follow
docs/HANDOVER-farhat.md instead.
MSG
  exit 1
fi

# shellcheck disable=SC1091
set -a; . ./.env; set +a

# ------------------------------------------------------- 2. realm imports
echo "[2/7] rendering Keycloak realm imports"
mkdir -p keycloak/import
for tpl in keycloak/*.template.json; do
  out="keycloak/import/$(basename "${tpl%.template.json}").json"
  if command -v envsubst >/dev/null; then
    envsubst < "$tpl" > "$out"
  else
    sed -e "s|\${REDMINE_PORT}|${REDMINE_PORT}|g" \
        -e "s|\${REDMINE_OAUTH_CLIENT_SECRET}|${REDMINE_OAUTH_CLIENT_SECRET}|g" \
        -e "s|\${IDIAL_CLIENT_SECRET}|${IDIAL_CLIENT_SECRET}|g" \
        -e "s|\${KEYCLOAK_TEST_USER_PASSWORD}|${KEYCLOAK_TEST_USER_PASSWORD}|g" \
        -e "s|\${IDIAL_TEST_USER_PASSWORD}|${IDIAL_TEST_USER_PASSWORD}|g" \
        "$tpl" > "$out"
  fi
  echo "      $(basename "$out")"
done

# --------------------------------------------------------------- 3. plugin
echo "[3/7] fetching the redmine_oauth plugin"
if [ -d plugins/redmine_oauth/.git ]; then
  echo "      already present"
else
  git clone --depth 1 https://github.com/kontron/redmine_oauth.git plugins/redmine_oauth
fi

# ---------------------------------------------------------------- 4. start
echo "[4/7] building and starting the stack"
docker compose up -d --build

echo "      waiting for Redmine..."
for _ in $(seq 1 100); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${REDMINE_PORT}/login" || true)
  [ "$code" = "200" ] && break
  sleep 3
done
[ "${code:-}" = "200" ] || { echo "Redmine did not become ready — check: docker compose logs redmine" >&2; exit 1; }

echo "      waiting for Keycloak realms..."
for _ in $(seq 1 60); do
  a=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${KEYCLOAK_PORT}/realms/d-lab/.well-known/openid-configuration" || true)
  b=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${KEYCLOAK_PORT}/realms/idial/.well-known/openid-configuration" || true)
  [ "$a" = "200" ] && [ "$b" = "200" ] && break
  sleep 3
done

# ------------------------------------------------------ 5. default data
# A fresh Redmine database contains no trackers, issue statuses, workflows,
# priorities or roles — the official image does not load them. Without this step
# issue creation fails with HTTP 500. The rake task is a no-op once data exists.
# NOTE: `docker compose exec` bypasses the entrypoint, so SECRET_KEY_BASE must be
# passed explicitly — otherwise Rails aborts and the failure is easy to miss.
echo "[5/7] loading Redmine default configuration data"
docker compose exec -T \
  -e SECRET_KEY_BASE="${REDMINE_SECRET_KEY_BASE}" \
  redmine bundle exec rails runner '
if Redmine::DefaultData::Loader.no_data?
  Redmine::DefaultData::Loader.load("en")
  puts "      default data loaded"
else
  puts "      already present — skipped"
end
puts "      trackers=#{Tracker.count} statuses=#{IssueStatus.count} workflows=#{WorkflowTransition.count} roles=#{Role.count}"
raise "default data missing" if Tracker.count.zero?
' RAILS_ENV=production

# ------------------------------------------------------------ 6./7. config
echo "[6/7] registering identity providers"
./scripts/provision-oauth-providers.sh

echo "[7/7] seeding documentation wiki"
./scripts/seed-wiki-docs.sh

cat <<EOF

────────────────────────────────────────────────────────────
 Redmine 7.0 is ready:  http://localhost:${REDMINE_PORT}

 Administrator : admin / admin   (change on first login!)
 SSO — DEE     : testuser  / ${KEYCLOAK_TEST_USER_PASSWORD}
 SSO — IDiAL   : idialuser / ${IDIAL_TEST_USER_PASSWORD}

 Keycloak (dev identity provider): http://localhost:${KEYCLOAK_PORT}
 Documentation: /projects/redmine-admin/wiki
────────────────────────────────────────────────────────────
EOF

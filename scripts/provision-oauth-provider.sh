#!/usr/bin/env bash
# Provision the Keycloak OAuth provider inside the running Redmine (idempotent).
# Turns the manual "Administration -> OAuth providers" step into one command, so the
# whole POC is reproducible: docker compose up  ->  this script  ->  SSO login works.
#
# Usage:  ./scripts/provision-oauth-provider.sh
# Requires: stack running (docker compose up -d) and .env with REDMINE_OAUTH_CLIENT_SECRET.
set -euo pipefail
cd "$(dirname "$0")/.."

CS=$(grep '^REDMINE_OAUTH_CLIENT_SECRET=' .env | cut -d= -f2)
KCPORT=$(grep '^KEYCLOAK_PORT=' .env | cut -d= -f2)
SITE="http://host.docker.internal:${KCPORT}"

docker compose exec -T -e CS="$CS" -e SITE="$SITE" redmine sh -c \
  'cd /home/redmine/redmine && RAILS_ENV=production bundle exec rails runner "
p = OauthProvider.find_or_initialize_by(oauth_name: %q{Keycloak})
p.custom_name = %q{Keycloak}
p.site = ENV[%q{SITE}]
p.client_id = %q{redmine}
p.client_secret = ENV[%q{CS}]
p.tenant_id = %q{d-lab}
p.identify_user_by = %q{email}
p.position = 1
p.save!
s = Setting.plugin_redmine_oauth
s[%q{self_registration}] = %q{3}   # auto-create Redmine account on first SSO login
Setting.plugin_redmine_oauth = s
puts %Q{OK provider ##{p.id} #{p.oauth_name} site=#{p.site} tenant=#{p.tenant_id}}
"'
echo "Provisioned. Open http://localhost:3000/login and click the Keycloak button."
echo "Test user: testuser / \$KEYCLOAK_TEST_USER_PASSWORD (email testuser@example.com)"

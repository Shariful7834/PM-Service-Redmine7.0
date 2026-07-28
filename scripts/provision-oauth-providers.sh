#!/usr/bin/env bash
# Register the OAuth/OIDC identity providers inside the running Redmine.
# Idempotent: safe to re-run. Turns the manual "Administration -> OAuth providers"
# clicking into one reproducible command.
#
# Usage: ./scripts/provision-oauth-providers.sh
# Needs:  stack running (docker compose up -d) and a populated .env
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck disable=SC1091
set -a; . ./.env; set +a

SITE="http://host.docker.internal:${KEYCLOAK_PORT}"

# NOTE: `docker compose exec` bypasses the image entrypoint, so SECRET_KEY_BASE is
# not derived from REDMINE_SECRET_KEY_BASE automatically — export it explicitly or
# Rails aborts with "Missing `secret_key_base` for 'production'".
docker compose exec -T \
  -e SECRET_KEY_BASE="${REDMINE_SECRET_KEY_BASE}" \
  -e SITE="${SITE}" \
  -e DEE_SECRET="${REDMINE_OAUTH_CLIENT_SECRET}" \
  -e IDIAL_SECRET="${IDIAL_CLIENT_SECRET}" \
  redmine bundle exec rails runner "
# Provider 1 — DEE user service (local Keycloak realm 'd-lab' stands in for it)
dee = OauthProvider.find_or_initialize_by(custom_name: %q{Keycloak})
dee.oauth_name       = %q{Keycloak}
dee.site             = ENV.fetch(%q{SITE})
dee.client_id        = %q{redmine}
dee.client_secret    = ENV.fetch(%q{DEE_SECRET})
dee.tenant_id        = %q{d-lab}
dee.identify_user_by = %q{email}
dee.position         = 1
dee.save!

# Provider 2 — IDiAL (demonstrates multiple identity providers side by side)
idial = OauthProvider.find_or_initialize_by(custom_name: %q{IDiAL})
idial.oauth_name       = %q{Keycloak}
idial.site             = ENV.fetch(%q{SITE})
idial.client_id        = %q{redmine}
idial.client_secret    = ENV.fetch(%q{IDIAL_SECRET})
idial.tenant_id        = %q{idial}
idial.identify_user_by = %q{email}
idial.button_color     = %q{#8ff0a4}
idial.position         = 2
idial.save!

# Auto-create a Redmine account on first successful SSO login
s = Setting.plugin_redmine_oauth
s[%q{self_registration}] = %q{3}
Setting.plugin_redmine_oauth = s

# Apply the DEE theme
Setting.ui_theme = %q{dee}

puts %Q{OK providers: #{OauthProvider.order(:position).map { |x| \"#{x.custom_name}(#{x.tenant_id})\" }.join(%q{, })}}
puts %Q{OK theme: #{Setting.ui_theme}}
" RAILS_ENV=production

echo
echo "Done. Open http://localhost:${REDMINE_PORT}/login — two SSO buttons should appear."
echo "  DEE   : testuser   / \$KEYCLOAK_TEST_USER_PASSWORD"
echo "  IDiAL : idialuser  / \$IDIAL_TEST_USER_PASSWORD"

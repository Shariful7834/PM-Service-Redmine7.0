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
# Provider 1 — the DEE user service.
#
# Farhat confirmed (2026-07-21) that it is NOT Keycloak: it is a custom OIDC
# service speaking standard OAuth 2.0. The plugin therefore needs its 'Custom'
# mode, where the endpoints are given explicitly instead of derived from a realm.
# Locally the endpoints point at the Keycloak realm 'd-lab', which stands in for
# it — same protocol, so the configuration shape is identical to production.
dee = OauthProvider.find_or_initialize_by(custom_name: %q{DEE User Service})
dee.oauth_name              = %q{Custom}
dee.site                    = ENV.fetch(%q{SITE})
dee.client_id               = %q{redmine}
dee.client_secret           = ENV.fetch(%q{DEE_SECRET})
# Custom mode does not use a tenant/realm, but the column is NOT NULL — keep it blank.
dee.tenant_id               = %q{}
dee.custom_auth_endpoint    = %Q{#{ENV.fetch(%q{SITE})}/realms/d-lab/protocol/openid-connect/auth}
dee.custom_token_endpoint   = %Q{#{ENV.fetch(%q{SITE})}/realms/d-lab/protocol/openid-connect/token}
dee.custom_profile_endpoint = %Q{#{ENV.fetch(%q{SITE})}/realms/d-lab/protocol/openid-connect/userinfo}
dee.custom_scope            = %q{openid profile email}
dee.custom_uid_field        = %q{preferred_username}
dee.custom_email_field      = %q{email}
dee.custom_firstname_field  = %q{given_name}
dee.custom_lastname_field   = %q{family_name}
dee.identify_user_by        = %q{email}
dee.position                = 1
dee.save!

# The old Keycloak-mode entry, if this instance still has one from before.
OauthProvider.where(custom_name: %q{Keycloak}).destroy_all

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

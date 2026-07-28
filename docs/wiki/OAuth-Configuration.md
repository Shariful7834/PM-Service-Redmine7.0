# OAuth / OpenID Connect configuration

Redmine core has **no** OAuth login — SSO is provided by the `redmine_oauth`
plugin (see [[Plugins]]).

## How the login works

Standard **OpenID Connect Authorization Code flow with PKCE**:

1. The user clicks an SSO button on the Redmine login page.
2. Redmine redirects to the identity provider's authorize endpoint.
3. The user authenticates at the identity provider.
4. The provider redirects back to `/oauth2callback` with an authorization code.
5. Redmine exchanges the code for tokens server-to-server, reads the **email**
   claim, matches or creates the user, and opens a session.

Accounts are created automatically on first login (plugin self-registration
mode 3), so no separate Redmine registration is needed.

## Multiple identity providers

Providers are database rows — **each configured provider gets its own login
button**. There is no single-provider limitation.

The development setup runs two providers side by side to prove this:

| Provider | Realm / tenant | Stands in for |
|---|---|---|
| Keycloak | `d-lab` | the **DEE user service** |
| IDiAL | `idial` | an **IDiAL** identity provider |

Both flows were verified end to end, each producing a real authenticated session.

**Alternative for production — identity brokering:** the DEE user service itself
federates IDiAL as an upstream provider. Every DEE service then keeps a single
login button and IDiAL users become regular DEE accounts (one identity across
wallet, Redmine, Moodle). Configured once centrally instead of per tool. Requires
a client registration on the IDiAL side. Recommendation pending with Farhat.

## Development values

| Field | Value |
|---|---|
| Site | `http://host.docker.internal:<KEYCLOAK_PORT>` |
| Client ID | `redmine` |
| Redirect URI | `http://localhost:3000/oauth2callback` |

**Why `host.docker.internal` and not `localhost`:** the OIDC issuer is derived
from the request host, so the browser and the Redmine container must reach the
identity provider under the *same* hostname. Using `localhost` inside the
container would produce a different issuer and token validation would fail.

## The real DEE User Service

Confirmed with Farhat (2026-07-21): the DEE User Service is **not Keycloak**. It is
`dee.core`, an **Auth0-compatible OAuth 2.0 provider**. The Academic Wallet already
authenticates against it, and its integration (`server/dee-core.js`) documents the
endpoint layout:

```
authorize : <base>/oauth/authorize
token     : <base>/oauth/token
userinfo  : <base>/oauth/userinfo
introspect: <base>/oauth/token_info      (machine-to-machine, not needed by Redmine)
scope     : openid profile email
```

Redmine uses the plugin's **"Custom"** provider mode, where these endpoints are
configured explicitly. Fields for *Administration → OAuth providers*:

| Field | Value |
|---|---|
| Provider | `Custom` |
| Site | base URL of dee.core |
| Tenant ID | empty (unused in Custom mode, but the column is NOT NULL) |
| Client ID / Secret | issued for Redmine by the infrastructure team |
| Authorization endpoint | `<base>/oauth/authorize` |
| Token endpoint | `<base>/oauth/token` |
| Profile (userinfo) endpoint | `<base>/oauth/userinfo` |
| Scope | `openid profile email` |
| UID / e-mail / firstname / lastname fields | `preferred_username` / `email` / `given_name` / `family_name` |

Plus the production redirect URI `https://<redmine-domain>/oauth2callback`
registered on the dee.core side, with PKCE (S256) permitted.

**This mode is verified.** The development instance runs provider 1 in exactly this
Custom configuration and a full Authorization-Code + PKCE login completes through
it, so only the endpoint values change when moving to the real service.

**Security note:** client secrets live only in `.env` (git-ignored) and in the
provider configuration inside the database — never in the repository.

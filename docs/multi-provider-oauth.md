# M2 question: "Is OAuth for multiple providers possible? Or can we use IDiAL accounts in DEE?"

Short answer: **yes to both — and they are two different architectures.** Multiple
providers is possible and **already demonstrated live** in the test installation.
Using IDiAL accounts *inside* DEE is also possible via identity brokering, and is
the cleaner long-term option. Decision needed (with Farhat) on which one DEE wants.

## Option A — multiple OAuth providers directly in Redmine ✅ DEMONSTRATED

The `redmine_oauth` plugin stores providers as database rows (`oauth_providers`
table, position-sorted). **Each configured provider gets its own login button** on
the Redmine login page. There is no single-provider limitation.

Proof, executed hands-on (2026-07-27) in the local instance:

1. Two Keycloak realms run side by side, simulating two independent IdPs:
   - realm `d-lab` = stand-in for the **DEE user service**
   - realm `idial` = stand-in for an **IDiAL** identity provider
2. Two provider rows configured in Redmine (`Keycloak` / `IDiAL`).
3. Login page renders **two SSO buttons** (verified: 2× `login-oauth-submit`).
4. **Full OIDC Authorization-Code + PKCE login executed through EACH provider**:
   - `testuser@example.com` via realm `d-lab` → authenticated Redmine session ✅
   - `idial.user@idial.example.com` via realm `idial` → authenticated Redmine
     session, account auto-provisioned ✅

Characteristics:
- Pro: works today, per-provider button colors/labels, zero IdP-side coupling.
- Con: users must pick the right button; accounts from different IdPs are distinct
  Redmine users (matched by email); every new service that wants IDiAL login must
  repeat this per-service configuration.

## Option B — IDiAL accounts *inside* DEE via identity brokering (recommended to evaluate)

Keycloak (if the DEE user service is Keycloak — **to confirm with Farhat**) has
built-in **identity brokering**: the DEE realm adds IDiAL as an upstream Identity
Provider. Flow: user hits DEE login → chooses "IDiAL" → authenticates at IDiAL →
DEE issues the token. Redmine (and every other DEE service) keeps **one single
OAuth provider: DEE**.

Characteristics:
- Pro: one login button everywhere; IDiAL users get regular DEE accounts (account
  linking, one identity across all DEE services — wallet, Redmine, Moodle…);
  configured **once** centrally instead of per service.
- Con: needs an OIDC/SAML client registration **on the IDiAL side** (organizational
  step, presumably via FH Dortmund IT) and admin access to the DEE user service.

## Recommendation

- **Short term:** Option A is proven and available now — nothing blocks the Redmine
  rollout on it.
- **Long term:** if IDiAL accounts should work across *all* DEE services (not just
  Redmine), brokering (Option B) at the DEE user service is the right layer — do it
  once centrally, not per tool.

## Open points for Farhat / Christian

- [ ] Is the DEE user service Keycloak? (brokering support + admin access)
- [ ] Does IDiAL expose an OIDC or SAML endpoint DEE could federate with, and who
      approves a client registration there?
- [ ] Preferred UX: several login buttons per tool (A) vs one DEE login with IDiAL
      as upstream (B)?

# Plugin Security Ledger

**Policy (non-negotiable, team decision 2026-07-28):** every plugin installed in
this Redmine must have an entry here — exact name, version, purpose, source — plus
a recorded security audit. Plugins are third-party code, and forgotten plugin
updates have caused open security issues in the past.

**No ledger entry → no install.**

## Installed plugins

### 1. redmine_oauth

| Field | Value |
|---|---|
| Exact name | `redmine_oauth` ("Redmine OAuth plugin", Kontron / Karel Pičman) |
| Version | **4.2.0** |
| Purpose | OAuth2 / OpenID Connect single sign-on against the DEE user service. Adds the provider configuration UI and the SSO login buttons. **Authentication-critical.** |
| Source | https://github.com/kontron/redmine_oauth |
| License | GPLv3 |
| Requires | Redmine ≥ 6.0 (verified running on 7.0.0) |
| **Last security audit** | **2026-07-28** — latest release, no known advisories found |
| **Next audit due** | **2026-08-28** |

*No other plugins are installed.*

## Agile / Scrum / Kanban boards — not installed

Redmine core has no agile board; the usual candidate is **RedmineUP Agile**
(free "Light" tier, paid PRO). Its published compatibility list states
**"Redmine 6.1 - 4.0"** — **Redmine 7.0 is not supported yet** (re-checked
2026-07-28 on redmineup.com).

Installing an uncertified plugin would violate the stability requirement, so the
agile board remains an **open gap**. Re-check the vendor page at every audit date;
install and test on a non-production instance first once 7.0 appears.

## Redmine core — version watch

Security fixes land in the **7.0.x** line first (redmine.org: latest stable, fully
supported; 6.1.x receives fixes only; 6.0.x is legacy). At every audit, also check
https://www.redmine.org/projects/redmine/wiki/Download for a new 7.0.x patch and
update the image tag accordingly. Current: **7.0.0** — no patch release as of
2026-07-28.

Note: redmine.org distributes source code only; the `redmine` Docker image comes
from Docker's official-images program, which is a separate channel.

## Audit procedure

For **every** plugin, monthly and before every Redmine core upgrade:

1. Check the plugin repository for new releases and changelog entries.
2. Check for security advisories affecting the plugin.
3. Confirm compatibility with the target Redmine version **before** upgrading core.
4. Apply updates on a test instance first; run plugin migrations; re-test SSO login.
5. Record the date and result in the audit log below.

## Audit log

| Date | Plugin | Auditor | Result |
|---|---|---|---|
| 2026-07-28 | redmine_oauth 4.2.0 | Md Shariful Islam | OK — current release, no advisories, verified working on 7.0.0 |
| 2026-07-28 | RedmineUP Agile (candidate) | Md Shariful Islam | NOT installed — vendor supports ≤ 6.1 only |

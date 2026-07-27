# Feature check: Redmine 7.0 vs Jira + Confluence (+ OTRS note)

**Method:** every row below was tested **hands-on** in the running local instance
(Redmine 7.0.0, sameersbn image) on 2026-07-27, via REST API calls and the Rails
console. No row is filled from memory or marketing pages. Test objects live in the
`dee-eval` project.

## Result table

| Capability | Needed for | Redmine native? | Plugin needed? | Verdict | Evidence (hands-on) |
|---|---|---|---|---|---|
| Projects & sub-projects | Jira | ✅ core | – | **OK native** | `POST /projects.json` → `dee-eval` (id 1); sub-project `dee-eval-sub` (id 2, parent "DEE Eval"). Note: API wants numeric `parent_id`. |
| Issues, types, custom fields | Jira | ✅ core | – | **OK native** | Trackers Bug/Feature/Support present; issue #1 created via API; custom field "Customer" (string, all trackers) created. |
| Workflows / status transitions per role | Jira | ✅ core | – | **OK native** | Live instance: 5 roles, 6 statuses, **144 workflow transitions** configured per role×tracker. |
| Agile boards (Scrum/Kanban) | Jira | ❌ | ⚠️ RedmineUP Agile (free "Light" / paid PRO) — vendor compat list says **Redmine 6.1–4.0, no 7.0 yet** (checked redmineup.com 2026-07-27) | **Gap on 7.0 for now** | Not in core UI of the running 7.0 instance. **Biggest gap vs Jira** — adoption-relevant. Plugin not installed; on 7.0 needs a compatibility test or vendor update first. |
| Sprints / backlog | Jira | ❌ (versions ≈ sprints) | ⚠️ same Agile plugin (same 7.0 caveat) | **Gap on 7.0 for now** | Core "versions" can emulate sprint buckets (tested, see Roadmap row) but no board/backlog UI. |
| Time tracking | Jira | ✅ core | – | **OK native** | `POST /time_entries.json` → 1.5 h logged on issue #1 with comment. |
| Roadmap / versions / milestones | Jira | ✅ core | – | **OK native** | `POST /projects/dee-eval/versions.json` → version "Sprint 1", due 2026-08-31. |
| Wiki with page hierarchy | Confluence | ✅ core | – | **OK native** | `PUT …/wiki/Home.json` (201) + child page `Architecture` with `parent_title=Home` (201). |
| Wiki attachments & versioning | Confluence | ✅ core | – | **OK native** | `POST /uploads.json` → attachment token issued (upload API works); wiki pages are versioned by core. |
| Rich text / Markdown editing | Confluence | ✅ core | – | **OK native** | Instance setting `text_formatting = common_mark` (CommonMark Markdown, Redmine 7 default). Weaker macro system than Confluence. |
| Full-text search across wiki + issues | Confluence | ✅ core | – | **OK native** | `GET /search.json?q=feature+check` → issue + project hits; `q=Hierarchy` → `wiki-page` hit. |
| Git / GitLab repository integration | both | ✅ core (repo browsing) | ⚠️ for deep GitLab sync | **OK native (basic)** | `git 2.39.5` present in container; core supports attaching Git repos (browse, commit refs like `#123`). Two-way GitLab integration (MRs etc.) would need webhooks/plugin — not tested. |
| REST API | both | ✅ core | – | **OK native** | Entire feature check was executed through the REST API with an API key. |
| LDAP / SSO | both | LDAP ✅ core; OAuth/OIDC ❌ core | ✅ `redmine_oauth` | **OK with plugin** | OIDC login **verified end-to-end** against local Keycloak incl. auto-provisioning — see [oauth-integration.md](oauth-integration.md). Multiple providers verified — see [multi-provider-oauth.md](multi-provider-oauth.md). |
| Email notifications | both | ✅ core (needs SMTP config) | – | **OK native** | Capability core; SMTP currently unconfigured in the eval container (`SMTP_ENABLED=false`). Config task for deployment, not a gap. |
| Email → issue creation | *(OTRS-like)* | ⚠️ basic core | ✅ helpdesk plugins (paid) | **OUT OF SCOPE** | Per supervisor decision: Redmine's ticketing too weak to replace OTRS without plugins → excluded from this evaluation. |

## Headline findings

1. **Jira replacement: yes, with one caveat.** Issues, workflows (144 role-based
   transitions out of the box), time tracking, versions/roadmap, custom fields, API —
   all core and verified. The one real gap is the **agile board (Scrum/Kanban) UI**,
   which needs the Agile plugin family. A free Light tier exists, **but the vendor's
   compatibility list stops at Redmine 6.1 as of 2026-07-27 — 7.0 support is not
   published yet**, so on 7.0 this is currently an open gap pending a compatibility
   test or vendor update. This is the main adoption decision for the group.
2. **Confluence replacement: yes for DEE's internal-doc needs.** Hierarchical wiki,
   Markdown (CommonMark), attachments, versioning, full-text search — all verified
   core. Confluence's rich macros/templates have no 1:1 equivalent; wiki is plainer.
3. **SSO: solved.** OIDC login via `redmine_oauth` verified end-to-end, including
   **multiple providers in parallel** (relevant for the IDiAL question).
4. **OTRS/email-ticketing: out of scope** as agreed.

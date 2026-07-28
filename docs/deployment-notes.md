# Deployment — status & go-live communication

**The complete deployment guide lives in [HANDOVER-farhat.md](HANDOVER-farhat.md)**
(aim, stack, required inputs, step-by-step, verification checklist, ops notes).
This file only keeps what is not in the handover: the go-live announcement and
the open-items tracker.

## Open items (blocking go-live — all on Farhat's side)

- [ ] Server / Docker host assigned
- [ ] Public domain + TLS reverse proxy → callback `https://<domain>/oauth2callback`
- [ ] OAuth client in the DEE user service (issuer URL, realm, client-id, secret,
      email claim)
- [ ] Deployed + verification checklist in the handover passed
- [ ] Teams announcement posted (text below)

## Teams message (paste when live — fill the two placeholders)

> **Redmine 7.0 is live and ready for testing** 🎉
>
> Hi everyone,
>
> our self-hosted Redmine instance is now running on the DEE server:
> **https://<REDMINE-DOMAIN>**
>
> **Login:** use the single-sign-on button on the login page — it works with your
> existing DEE account, no separate registration needed. Your account is created
> automatically on first login.
>
> **What you can test:** projects & sub-projects, issues with custom fields and
> role-based workflows, time tracking, roadmap/versions, per-project wikis with
> attachments, and full-text search. Redmine is our candidate replacement for
> Jira + Confluence.
>
> **Documentation:** the installation, configuration and the plugin security
> ledger are documented inside Redmine itself → project *"Redmine Administration"*.
>
> **Feedback:** please report anything you find (bugs, missing features,
> usability) as an issue in the *"<FEEDBACK-PROJECT>"* project — that way we test
> the issue tracker while using it. 🙂
>
> Known limitation: agile boards (Scrum/Kanban) are not included yet — the plugin
> vendor has not released Redmine 7.0 support; tracked in the security ledger.
>
> Best, Shariful

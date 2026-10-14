# FocusLearn

Study and focus companion for Sri Lankan G.C.E. Advanced Level students.
Flutter (Android, Windows), self-hosted Supabase, Cloudflare R2, React admin dashboard.

> Status: **Phase 0 (infrastructure) in progress.** No app code yet.

## Principles
Privacy by default (many users are minors), no ads, no data sale, honest capability claims
(see `docs/CAPABILITY_MATRIX.md` once added), free-tier friendly, low-end-device friendly.

## Hostnames (flat, free Cloudflare Universal SSL)
| Purpose | Host |
|---|---|
| API (Kong: Auth, REST, Realtime, Functions) | `eduapp-api.shanutechx.com` |
| Supabase Studio (Cloudflare Access only) | `eduapp-studio.shanutechx.com` |
| Admin dashboard (Access + app auth + MFA) | `eduapp-admin.shanutechx.com` |
| Optional web app | `eduapp-app.shanutechx.com` |
| Public non-sensitive assets (R2) | `eduapp-files.shanutechx.com` |

Hostnames are read from environment variables so changing them is configuration only.

## Repo layout
See `CLAUDE.md`. Create the skeleton with `bash infra/scripts/bootstrap-repo.sh`.

## Phases
0 Infra, 1 Auth and design system, 2 Planner, 3 Focus, 4 Social and notes and chat,
5 Calculators, 6 Calendar and push, 7 Native focus integrations, 8 Admin, 9 Hardening and packaging.

## Verify the scaffold (Phase 0.1)
```bash
git init && bash infra/scripts/bootstrap-repo.sh
git add -A && git commit -m "chore: scaffold"
# push to GitHub and confirm the CI, Secret scan workflows are green
```

Not legal advice: privacy documents are drafts for lawyer review (Sri Lanka PDPA No. 9 of 2022).
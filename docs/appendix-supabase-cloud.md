# Appendix: running on Supabase Cloud's free plan instead (fallback)

Checked 2026-10-15 (marketing and third-party pages; figures differ between sources, so **verify on https://supabase.com/pricing before relying on any number**).
Use this when the laptop is unavailable, or the pilot needs availability the laptop cannot give. The apps are built to switch by configuration.

## Free plan numbers (as found)
| Item | Value | Matters for us because |
|---|---|---|
| Projects | 2 active | Enough: one project |
| Database | 500 MB | Fine for a pilot (text data only: files live in R2) |
| Auth | 50,000 monthly active users | More than needed |
| File storage | 1 GB, 50 MB per upload | **Irrelevant**: we use R2 via our own functions (ADR-002) |
| Bring-your-own storage provider | **Not included** on free | Also irrelevant for the same reason |
| Edge Functions | 500,000 invocations per month, 10 MB script size | Fine |
| Egress | 5 GB per month in some sources, 500 MB in others | **Unclear: verify**. Files bypass Supabase, so only API traffic counts |
| Automatic backups | **Not included** on free | Our backups would need a cloud variant (below) |
| **Pausing** | **Free projects pause after 1 week of inactivity** | Must be handled, see below |
| Paid tier | Pro, USD 25 per month: no pausing, daily backups kept 7 days | The realistic production option |

## What changes
| Area | Self-hosted (now) | Supabase Cloud |
|---|---|---|
| API URL and keys | `https://eduapp-api.shanutechx.com`, keys from `stack.sh secrets` | Project URL and publishable key from the dashboard. The secret key lives only in Edge Function secrets |
| Gateway, Tunnel, Studio hostname, Access | Ours | Not needed. Studio is the Supabase dashboard (turn on MFA on the owner account) |
| Custom domain for the API | Free | Paid add-on: the apps use the `*.supabase.co` URL on free |
| SMTP | `infra/docker/.env` | Dashboard, Authentication, SMTP. Same Brevo settings |
| Turnstile | `TURNSTILE_SECRET` in `.env` | Dashboard, Authentication, captcha protection. Same widget and secret |
| Migrations | `backend/supabase/migrations` applied by our runner | Same files, applied with the Supabase CLI against the project (verify the exact command) |
| Edge Functions | Self-hosted functions runtime | `supabase functions deploy` and `supabase secrets set` for R2 keys |
| R2 | Unchanged | Unchanged |
| Backups | `infra/backup/backup.sh` (uses `docker exec`) | **Not supported yet.** A cloud variant needs `pg_dump` run from a machine with the connection string. Listed in LIMITATIONS |
| Inactivity pause | Not applicable | Project pauses after a week without activity and is unreachable until restored. A scheduled keep-alive request avoids it but is a workaround, not a guarantee: for real users use Pro |
| Region | Home | Choose the nearest available region (for example Singapore or Mumbai: verify availability) |

## Configuration the apps must expose (decision for Phase 1)
`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `ENVIRONMENT` as build-time values (Flutter `--dart-define-from-file`, Vite `.env`), never hard-coded. Nothing else may differ between the two backends.

## Switch checklist
1. Create the project, pick the region, enable MFA on the owner account.
2. Apply all migrations. Run the pgTAP tests (RLS) against the new project.
3. Configure SMTP, Turnstile, redirect URLs and the site URL in the dashboard.
4. Deploy Edge Functions and set their secrets.
5. Point a staging build of the apps at the project and run the integration tests.
6. Move data if needed (see below), then publish builds with the new URL.

## Moving existing users and data (unverified)
A data-only dump of `public` and `auth` from the self-hosted database could be loaded into a fresh project, which would keep password hashes. I have **not** verified that Supabase Cloud accepts such a restore, or how the different signing keys affect sessions. Expect every user to have to log in again. Rehearse on a throwaway project first.

## Privacy and legal
Supabase Cloud is a third-party processor that stores minors' data outside Sri Lanka. Add it to the privacy notice and to the list for your lawyer (`DATA_INVENTORY.md`, cross-border processing).

## Known issues
Unverified: egress allowance, free-plan card requirement at sign-up, region list, CLI commands, restore compatibility. This appendix is a plan, not a tested path.

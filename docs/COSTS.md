# Costs and quotas

Checked: **2026-10-15** (web lookup during Phase 0.2).
Policy: every figure is **verify before deployment**. Vendors change free tiers without notice.
Status column: `official` = read on the vendor's own docs page in search results,
`secondary` = third-party article only, `unverified` = not looked up yet.

Target: **USD 0 recurring** for the pilot. The only unavoidable cost is the domain you already own.

## Summary

| Service | Free allowance (as found) | Status | Pilot fit | Source |
|---|---|---|---|---|
| Cloudflare DNS + proxy + Universal SSL | Free plan. Universal SSL covers one subdomain level only, hence flat hostnames | official knowledge, re-verify | Fits | https://developers.cloudflare.com/ssl/edge-certificates/universal-ssl/ |
| Cloudflare proxied request body limit | **100 MB** (Free and Pro) | official | Fits: large uploads go direct to R2 | https://developers.cloudflare.com/support/troubleshooting/http-status-codes/4xx-client-error/error-413 |
| Cloudflare proxied request timeout | 100 s then HTTP 524 | secondary (community post) | Fits | https://community.cloudflare.com/t/when-we-import-a-file-we-get-timeout-error/763524/2 |
| Cloudflare Tunnel | Free | secondary | Fits | https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/ |
| Cloudflare Zero Trust (Access) | Free plan, up to **50 users**, about 24 h log retention | secondary (plus 2020 launch blog) | Fits: only a few admins use it | https://blog.cloudflare.com/teams-plans |
| Cloudflare Turnstile | Free, unlimited challenges, up to **20 widgets**, **10 hostnames per widget**, 7-day analytics | official | Fits | https://developers.cloudflare.com/turnstile/plans/ |
| Cloudflare R2 storage | **10 GB-month** free, Standard class only | official page for ops, secondary for the 10 GB figure | Fits for pilot | https://developers.cloudflare.com/r2/pricing/ |
| R2 Class A (writes, lists) | 1 million per month free, then USD 4.50 per million | official | Fits | same |
| R2 Class B (reads, HEAD) | 10 million per month free, then USD 0.36 per million | official | Fits | same |
| R2 egress | Free | official | Fits | same |
| Supabase self-hosted | No licence cost. Docs say community-supported | official | Fits | https://supabase.com/docs/guides/self-hosting/docker |
| Firebase Cloud Messaging | No per-message charge. Default downstream quota 600,000 messages per minute per project | quota official; "free" from general knowledge | Fits | https://firebase.google.com/docs/cloud-messaging/throttling-and-quotas |
| Google Calendar API | Free to use, with per-project and per-user quotas | **unverified** | Check in Phase 6 | https://developers.google.com/calendar/api/guides/quota |
| Home laptop | Electricity and ISP only | n/a | Fits (dev and pilot) | n/a |
| VPS (later) | Not free | n/a | Phase 9 decision | n/a |

## Things that could break "stay free"

1. **R2 may require a payment method on file** even when usage stays inside the free allowance. I did not
   confirm this. Check at account setup. If a card is mandatory and you refuse, R2 is not possible
   and storage falls back to local disk plus off-site backup elsewhere (decision record needed).
2. **R2 free allowance is shared by all three buckets.** Backups consume it. Plan: compress, `age`-encrypt,
   keep a short retention (see RUNBOOK in step 0.8). Student file uploads need a per-user quota.
3. **Turnstile has no SLA** on the free plan. If it is down, signup and login must degrade safely
   (fail closed for signup, with a clear message). Do not fail open silently.
4. **Zero Trust free is capped at 50 users.** Admin and Studio users must stay well below this.
   Students never go through Access.
5. **Email daily caps** hit on signup spikes (see below).

## SMTP provider comparison (decision happens in step 0.7)

| Provider | Free tier found | Notes | Status | Source |
|---|---|---|---|---|
| **Brevo** | 300 emails per day, no expiry | Highest effective free volume. Secondary sources report a provider footer on free-plan emails: verify | secondary | https://www.brevo.com/pricing/ |
| Mailjet | 6,000 per month, capped at 200 per day | SMTP and API | secondary | https://www.mailjet.com/pricing/ |
| Resend | 3,000 per month, capped at 100 per day, 1 domain | Best developer experience. Daily cap is tight for signup bursts | secondary | https://resend.com/pricing |
| Amazon SES | Reported as 12-month free tier or credits that expire | Not permanently free. Skip for a free-only plan | secondary | https://aws.amazon.com/ses/pricing/ |
| SendGrid | Permanent free tier reported **retired in 2025** (60-day trial only) | Exclude | secondary | https://dreamlit.ai/blog/best-sendgrid-alternatives |

**Provisional pick: Brevo** (300 per day). Verification, reset and re-send emails all count. At 300 per day, a
launch day with more than about 150 signups (each may also trigger a resend or reset) can exhaust the cap.
Mitigations: rate-limit resend, Turnstile on signup, stagger onboarding of classes, and keep a documented
second provider (Mailjet or Resend) configured but dormant.

## R2 capacity estimate (pilot, assumptions marked)

| Assumption | Value |
|---|---|
| Students | 200 |
| Avg stored attachments per student | 20 MB after client-side compression |
| Total | about 4 GB (inside 10 GB free) |
| Per-user quota (proposed default) | 50 MB, adjustable by admin |
| Backups | about 0.1 to 1 GB total with a 14-day retention (estimate, measure in 0.8) |
| Class A ops | uploads and listings, far below 1 million per month |
| Class B ops | signed GETs, far below 10 million per month |

Orphan cleanup deletes are free operations per R2 docs, so garbage collection costs nothing in operations.

## Self-hosting resource figures

| Item | Figure | Status | Source |
|---|---|---|---|
| Minimum for the full Supabase stack | 4 GB RAM, 2 CPU cores, 40 to 50 GB SSD (the docs show both 40 and 50 GB across versions) | official | https://supabase.com/docs/guides/self-hosting/docker |
| Recommended | 8 GB+ RAM, 4+ cores, 80 GB+ SSD | official | same |
| Observed idle on a 4 GB droplet | about 1.5 GB RAM, images about 8.9 GB on disk | secondary (single blog) | https://learnwithhasan.com/guide/self-host-supabase/ |
| Safe to remove if unused | Docs name Analytics (Logflare), Realtime, Storage, imgproxy, Edge Runtime as removable. We need Realtime and Edge Functions, so we trim only Analytics and imgproxy, and test | official | same |

**Laptop requirement to run the pilot:** at least 8 GB RAM is advisable (host OS plus the stack plus headroom).
With 4 GB it will swap. I still need your laptop's RAM and OS (question at the end of the step 0.2 reply).

## Cloudflare Tunnel and large downloads

Cloudflare's free-plan terms around serving non-HTML media through the proxy have restrictions. Our design
sends private file bytes **directly from R2 signed URLs**, not through the proxied API domain, so this
should not apply. Re-check the current Cloudflare self-serve terms before launch. Status: unverified.

---

## Additions from steps 0.6 to 0.10 (checked 2026-10-15, all verify before deployment)

### File operation cost model (R2)
Upload = 2 Class A (PUT, COPY) + 2 Class B (HEAD, ranged GET). View = 1 Class B. Delete = free.
At 200 students uploading 5 files per month: about 2,000 Class A and 2,000 Class B, plus views, against 1M and 10M free.
Presigned URLs work only on `<account>.r2.cloudflarestorage.com`, not on custom domains.

### Backup operations and storage
Each daily run: 3 PUT (Class A) and 3 HEAD (Class B); Sundays double that. About 100 Class A and 100 Class B per month: negligible.
Storage: about 22 retained sets (14 daily + 8 weekly) x encrypted dump size. A 100 MB dump means about 2.2 GB of the 10 GB free allowance, shared with student files. Measure after the first real backup.

### SMTP
Brevo free: 300 per day, SMTP key required (not the API key), host `smtp-relay.brevo.com` port 587. Source: https://developers.brevo.com/docs/supabase-smtp-integration (status: secondary).

### Monitoring
| Service | Free allowance (as found) | Status | Source |
|---|---|---|---|
| Healthchecks.io | 20 checks, 100 log entries per check | secondary | https://healthchecks.io/pricing/ |
| UptimeRobot | 50 monitors, 5-minute; non-commercial use only | secondary | https://uptimerobot.com/pricing/ |
| Better Stack | 10 monitors + 10 heartbeats | secondary | https://betterstack.com/pricing |

### Supabase Cloud fallback (not used now)
Free plan: 500 MB database, 1 GB storage, 50 MB uploads, 50,000 monthly users, 2 projects, pauses after a week of inactivity, no automatic backups. Egress figures conflict between sources. Source: https://supabase.com/pricing. Details: `docs/appendix-supabase-cloud.md`.

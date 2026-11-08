# R2 setup (Phase 0.6)

Sources read 2026-10-15: https://developers.cloudflare.com/r2/api/s3/presigned-urls/ , https://developers.cloudflare.com/r2/pricing/ ,
https://supabase.com/docs/guides/self-hosting/self-hosted-s3 . Dashboard click paths and wrangler flags change: **verify** each.

## 0. First, answer the open cost question
Before creating anything, open the Cloudflare dashboard, R2 Object Storage, and note whether it **asks for a payment method** to enable R2.
Write the answer in `docs/setup/measurements.md`. If a card is mandatory and you will not provide one, stop: tell me and we switch to the
fallback in ADR-002 (local disk plus another free off-site backup target).

## 1. Buckets
| Bucket | Purpose | Public? | Contents |
|---|---|---|---|
| `focuslearn-public` | App icons, admin-published assets | Yes, via custom domain `eduapp-files.shanutechx.com` only | Non-sensitive only. Never user content. |
| `focuslearn-private` | Note attachments, chat files, avatars (if private) | **No**, signed URLs only | `pending/` (unconfirmed uploads), `objects/` (confirmed) |
| `focuslearn-backups` | Encrypted database dumps | **No** | `daily/`, `weekly/` |

Create them with `bash infra/cloudflare/r2-apply.sh` (dry run first, then `WRANGLER_VERSION=<x.y.z> ... --apply`) or in the dashboard.
Location hint: choose an Asia-Pacific hint if offered (verify). R2 jurisdiction options may not include Sri Lanka: flag for the lawyer (cross-border transfer, `DATA_INVENTORY.md`).
Do **not** enable the `r2.dev` public URL on any bucket. Only `focuslearn-public` gets a custom domain: bucket Settings, Custom Domains, add `eduapp-files.shanutechx.com`.

## 2. API tokens (least privilege)
R2, Manage API tokens, create one token per purpose. Permission **Object Read & Write**, scoped to **one bucket** each (menu names: verify).
| Token name | Bucket | Used by | Lives in |
|---|---|---|---|
| `fl-private-functions` | `focuslearn-private` | Edge Functions: presign, HEAD, ranged GET, copy, delete, garbage collection | Functions environment on the server only |
| `fl-backups` | `focuslearn-backups` | Backup job (step 0.8) | Server `.env` for the backup script only |
| `fl-public-admin` | `focuslearn-public` | Admin publishing script (later) | Admin's machine only, not on the server |
Copy each Access Key ID and Secret **once** into a password manager. Put the first two into `infra/cloudflare/.env` for the spike.
Also keep a read-only token for restore drills offline (step 0.8).
Known gap: R2 tokens cannot be write-only and R2 has no Object Lock (a third-party doc lists object lock as unavailable: verify). A compromised backup token could delete dumps.
Mitigations: server-side lifecycle (this step), plus a weekly copy of the latest encrypted dump to a machine that is not the laptop (step 0.8).

## 3. CORS
Dashboard, bucket Settings, CORS Policy, paste:
- `focuslearn-private`: `infra/cloudflare/r2-cors.json` (admin and app origins; GET, PUT, HEAD)
- `focuslearn-public`: `infra/cloudflare/r2-cors-public.json` (GET, HEAD from anywhere)
Native Flutter apps do not enforce CORS. CORS matters for the admin dashboard and any web app. The JSON is the S3-style array format shown in third-party guides: **verify** it is accepted.

## 4. Lifecycle
Applied by `r2-apply.sh`: private `pending/` expires after 1 day; backups `daily/` after 14 days and `weekly/` after 56 days; incomplete multipart uploads abort after 1 day.
Deletes by lifecycle and by `DeleteObject` do not cost operations (R2 pricing page: DeleteObject is a free operation).

## 5. Object key and upload design (summary of ADR-002)
- Keys: `pending/<user_uuid>/<file_uuid>` then `objects/<user_uuid>/<file_uuid>`. No original filename, no extension from the client. The display name lives in Postgres.
- Upload: function checks auth, allowlisted type, declared size against the per-user quota (reserved at presign time) -> presigned PUT, **5 minute** expiry, content-type pinned.
- Confirm: function does HEAD (size), a ranged GET of the first bytes (magic-number check, never trusting the extension), then CopyObject `pending/` -> `objects/`, deletes the pending object, marks `file_objects.status = ready`. Failures delete the object.
- Download: function re-checks access (owner, active share or conversation membership) -> presigned GET, **60 to 120 s**, with a response-content-disposition for the file name.
- Presigned URLs are bearer tokens and work only on the S3 endpoint `<account>.r2.cloudflarestorage.com`, not on custom domains (Cloudflare docs). Never log URLs.

Operations per file (estimates, check with the spike): upload = 2 Class A (PUT, COPY) + 2 Class B (HEAD, ranged GET); each view = 1 Class B. Pilot volumes are far inside the free allowance (`COSTS.md`).

## 6. Run the spike (exit criteria for 0.6)
```bash
cp infra/cloudflare/.env.example infra/cloudflare/.env     # fill the values
python3 infra/cloudflare/r2-spike/r2_spike.py --selftest   # offline signer check, must pass
python3 infra/cloudflare/r2-spike/r2_spike.py              # online, uses ~10 Class A and ~15 Class B operations
```
It checks: presigned PUT accepted; wrong content-type rejected; whether a signed content-length caps upload size (reported as INFO with the consequence);
presigned GET returns identical bytes; ranged GET works; content-disposition override; expiry enforced; anonymous access denied; HEAD size; server-side copy and delete;
token scoping (backup token cannot read private, private token cannot write backups); CORS allows the admin origin and denies others; a 5 MiB upload with measured speed.
Save the full output in `docs/setup/measurements.md`. The upload-speed line is a rough proxy for what a student on a similar connection will see: run it from a normal home connection, not only from the server.

## 7. Behaviour when R2 is down (tested in Phase 4)
Clients keep notes and messages text working offline. Attachments show a retry state. Uploads wait in the local outbox. Downloads fail with a clear message and never block the rest of the screen.

## Rotating a token
Create a new token with the same scope, update the server environment, restart the function container, run the spike, then delete the old token.

## Known issues
- **Not run against real R2.** My environment has no network or account. Verified offline: the SigV4 signer reproduces two published AWS test vectors (`--selftest`).
  Not verified: every online check above, including the CORS JSON format and whether the signed content-length is enforced.
- Wrangler flags (`--id`, `--prefix`, `--expire-days`, `--abort-incomplete-days`) come from a third-party page, not Cloudflare's reference: verify with `--help`.
- Whether R2 requires a payment method is unknown until you check (section 0).

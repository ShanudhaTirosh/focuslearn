# 04. Email: verification and password reset (Phase 0.7)

Sources read 2026-10-15: Brevo's Supabase guide https://developers.brevo.com/docs/supabase-smtp-integration , Brevo SMTP integration pages
(via third-party write-ups), https://leadhaste.com/blog/brevo-smtp-setup , https://www.captaindns.com/en/blog/brevo-transactional-email-technical-guide .
These are mostly **secondary sources**: confirm every value against Brevo's own dashboard.

## Decision (provisional, confirm after the test below)
**Brevo free plan.** 300 emails per day, no expiry, no rollover (several sources agree; verify on the pricing page).
Settings: host `smtp-relay.brevo.com`, port **587** with STARTTLS (465 for implicit TLS, 2525 if 587 is blocked), password = a dedicated **SMTP key**
(not an API key). The SMTP login may be your account email or an address ending `@smtp-brevo.com`.
Fallbacks kept dormant, not configured: Mailjet (200 per day) and Resend (100 per day), `COSTS.md`. If Brevo refuses or suspends the account, switch by editing four lines in `infra/docker/.env`.

## Sender domain: use a subdomain
Send from `no-reply@eduapp.shanutechx.com` and authenticate `eduapp.shanutechx.com` with Brevo. Reasons: reputation isolated from any mail on the root domain,
and you will not disturb an existing SPF record. (Email DNS records are not TLS certificates, so the one-level certificate limit from Phase -1 does not apply.)
Brevo needs an authenticated sender whose address matches this domain, or it may rewrite or reject mail: verify.

## Steps
1. Create the Brevo account. Brevo may review new accounts before sending is allowed: record how long it took.
2. **Settings, Senders, Domains, IPs, Domains**: add `eduapp.shanutechx.com`. Brevo shows the DNS records it wants (verification code, DKIM, DMARC).
3. Add exactly those records in Cloudflare DNS. **Set every record to "DNS only" (grey cloud).** A proxied CNAME breaks DKIM.
   Brevo's DKIM records are a TXT or two CNAMEs depending on the account, so copy them from the dashboard, do not guess names.
   DMARC: only **one** DMARC TXT may exist at `_dmarc.eduapp.shanutechx.com`. Start with `v=DMARC1; p=none;` plus a `rua=` mailbox you actually read
   (or omit `rua` until you have one). After reports look clean for two weeks, move to `p=quarantine`.
4. Check what the world sees (selector names are the part before `._domainkey` in the records Brevo gave you):
   ```bash
   bash infra/scripts/check-email-dns.sh eduapp.shanutechx.com --dkim <selector1> --dkim <selector2>
   ```
   Propagation can take up to 24 to 48 hours (Brevo write-up): rerun later.
5. **Settings, SMTP & API, SMTP tab**: generate an SMTP key. Check **Authorized IPs** on the same page (see the gotcha below).
6. Put the values in `infra/docker/.env` (`SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_ADMIN_EMAIL`), then:
   ```bash
   python3 infra/scripts/send-test-email.py --to <your own gmail address>
   ```
7. Apply to the stack and probe the real Auth path (do this in **local mode, before Turnstile**, because captcha blocks scripted signups):
   ```bash
   bash infra/scripts/stack.sh setup && (cd infra/docker/stack && sh run.sh recreate)
   bash infra/scripts/auth-email-probe.sh <your address> signup
   bash infra/scripts/auth-email-probe.sh <your address> recover
   ```
   Delete the probe user afterwards in Studio.

## Exit criteria for 0.7 (record results in `docs/setup/measurements.md`)
- `check-email-dns.sh` has no FAIL lines.
- Test mail reaches the **inbox (not spam)** at Gmail and at one other provider your students use. Open "Show original" at Gmail: **DKIM: PASS** and **DMARC: PASS**.
- The signup confirmation mail arrives, and its link works. **Write down the link's host and path**: this settles the open `API_EXTERNAL_URL` question from 0.3.
  If the link lacks `/auth/v1`, adjust `API_EXTERNAL_URL` in `setup.sh` as noted in 01-supabase-local.md.
- Time from request to inbox, and the Brevo logs show the message as delivered.

## Gotchas
- **Authorized IPs (home laptop, two ISPs).** A real-world report shows Brevo rejecting SMTP logins from IPs not on an authorized list (`5.7.1 Unauthorized IP`). Your laptop's public IP changes and
  differs per ISP. Check the setting on the SMTP & API page. If IP restriction is on, turn it off (the SMTP key is then the only secret: treat it as one), or use Brevo's HTTPS API from a function later. Verify in the dashboard.
- **Tracking.** Verification and reset emails must have **no open-tracking pixel and no click-tracking link rewriting**. Rewritten links can break verification and tracking pixels conflict with our privacy-by-default rule for minors. Find and disable these for transactional mail in Brevo: I could not confirm where the setting lives.
- **Free-plan footer.** One secondary source said free-plan mail may carry a provider footer. Check the test message, and note it in `LIMITATIONS.md` if present.
- **Rate limits.** Brevo: 300 per day, hard. Auth also has its own per-hour limit (30 per hour is the hosted default with custom SMTP; the self-hosted variable is believed to be `GOTRUE_RATE_LIMIT_EMAIL_SENT`: verify with `sh run.sh printenv auth`). A launch-day signup wave can exhaust the daily cap, so stagger class onboarding (`COSTS.md`).
- **Unauthenticated domain.** Brevo can replace an unauthenticated sender domain with its own shared domain: check the `From` header in the test mail shows `eduapp.shanutechx.com`.
- **Replies.** `no-reply@` has no mailbox. Put a real support address in the email body text (Phase 1 templates). Cloudflare Email Routing can receive mail for a support address, but never use it for sending.
- **Privacy.** Brevo is another processor with data outside Sri Lanka: add it to the privacy notice and the lawyer review list (`DATA_INVENTORY.md`). Logs hold recipient addresses: set the shortest retention the dashboard allows.

## Templates (deferred to Phase 1)
Default Supabase Auth emails are generic English. Phase 1 replaces them (confirmation, recovery, email change) with short, plain, translatable text, no images, no tracking, a clear "ignore this if you did not sign up" line,
and a support address. In self-hosted Supabase, templates are served from a URL configured in Auth: check the current docs then.

## Known issues
- **Not run against real services.** Verified offline (18 tests, `bash infra/scripts/tests/run-email-tests.sh`): the DNS checker against stubbed DNS answers (healthy, missing DMARC, duplicate DMARC, missing DKIM, CNAME without key),
  and the SMTP sender against a local stub server (login, envelope, headers, Message-ID domain, password never printed, clean failure on missing password).
  Not verified: Brevo behaviour, real DNS, deliverability, the `auth-email-probe.sh` path through the gateway (it needs the running stack).
- The DNS checker uses Cloudflare's DNS-over-HTTPS and needs curl and python3. It sees what resolvers see, which can lag your dashboard by minutes to hours.
- Brevo's DKIM record names are not hard-coded because the sources disagree (TXT or CNAME, varying selector names).

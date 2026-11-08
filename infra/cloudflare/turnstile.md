# Cloudflare Turnstile notes

Free plan (official plans page, read 2026-10-15): unlimited challenges, up to 20 widgets, 10 hostnames per widget,
7-day analytics, **no SLA**. Supabase Auth supports Turnstile on self-hosted installs (Supabase docs).

## Create the widget
1. Dashboard, Turnstile, Add widget. Mode: **Managed**. Hostnames: `eduapp-app.shanutechx.com` (and `localhost` for a separate dev widget).
2. Copy the **site key** (public, goes in the apps) and the **secret** (server only: `infra/docker/.env` as `TURNSTILE_SECRET`).
3. Use a separate widget for development so test traffic never mixes with production analytics.
4. Dummy test keys exist for automated tests (always pass or always fail). Look them up on Cloudflare's Turnstile testing page, verify, and use them only in local mode.

## Where it is enforced
Supabase Auth checks the captcha token on sign-up, sign-in and password reset when captcha is enabled. Our setup script enables it only after the
secret passes a preflight check. The client sends the token with each auth call (`captchaToken` in the Supabase client libraries).

## Native apps (Phase 1 decision, flagged now)
Turnstile is a web widget. Flutter on Android and Windows must render it in a WebView page that is served from an allowed hostname
(candidate: a tiny static page on `eduapp-app.shanutechx.com`), then pass the token back to Dart. Windows needs the WebView2 runtime.
This adds dependency weight on low-end phones and needs an offline-friendly error state. Spike in Phase 1 before committing.

## Failure policy
- Turnstile down: signup and password reset show a clear "try again later" message. Do not silently disable captcha.
- Login for existing users: if the captcha provider is unreachable we still require it (fail closed), and we measure how often this happens before reconsidering.

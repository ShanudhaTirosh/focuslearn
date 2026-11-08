# Cloudflare Access policies (dashboard steps, no secrets)

Plan: Zero Trust Free, up to 50 users (verify: COSTS.md). Menu names change, so verify each path in the dashboard.

## 1. One-time setup
1. Open Zero Trust, create a team name if asked (free plan, no payment may be requested: verify).
2. Login methods: enable **One-time PIN** (email code). Add Google later only if you need it.

## 2. Application: Supabase Studio
- Type: Self-hosted. Application domain: `eduapp-studio.shanutechx.com`, path empty (whole host).
- Session duration: 4 hours.
- Policy name `studio-admins`, action **Allow**, include rule **Emails** = exactly your own addresses (no wildcards, no whole-domain rule).
- No Bypass or Service Auth policies. Anything not matched is denied.
- Optional: require a country allowlist (Sri Lanka plus your travel) only if it does not lock you out.

## 3. Application: Admin dashboard (Phase 8, listed here so it is not forgotten)
- Domain `eduapp-admin.shanutechx.com`, same pattern, separate policy `admin-users`.
- This is only the outer gate. The admin app still requires Supabase Auth, MFA (AAL2) and server-side authorization.

## 4. Never
- Never put Access in front of `eduapp-api` (mobile and desktop apps cannot complete a browser login).
- Never use an email-domain wildcard policy.
- Never share Studio access with anyone who is not a trusted device administrator.

## 5. Test (also automated in `verify-edge.sh`)
- Private window to `https://eduapp-studio.shanutechx.com`: must redirect to the Cloudflare Access login.
- An email not on the list must not receive access.
- After login, Studio still asks for the basic-auth username and password (second factor of defence).

## 6. Recovery
If you lock yourself out: Zero Trust dashboard, edit the policy. Keep a second trusted email on the list.

# Supabase Free Plan Setup & Zero-Cost Architecture Guide

This guide details how to run the entire Focus Learn backend for free on the **Supabase Free Plan** combined with **Cloudflare R2** for file storage, achieving high availability with **$0 monthly hosting costs**.

---

## 1. Free-Plan Architecture & Official Limits

| Resource | Official Limit | Focus Learn Allocation | Protection Strategy |
|---|---|---|---|
| **PostgreSQL Database** | 500 MB | ~30 MB for 10,000 active students | Automated nightly `pg_cron` purge of transient logs (`rate_limit_events`, old audit logs) |
| **Database Egress** | 5 GB / month | ~1 GB / month (JSON REST payload) | Aggressive client-side caching in SQLite & SharedPreferences |
| **Auth (MAU)** | 50,000 Monthly Active Users | 1,000–5,000 targeted pilot students | 90% headroom; standard email + OTP confirmation |
| **File Storage & Bandwidth** | 10 GB free on Cloudflare R2 | 10 GB free attachments & notes | **$0 egress fees** on Cloudflare R2 via Supabase Edge Functions |
| **Edge Functions** | 500,000 invocations / month | < 50,000 calls / month | 95% of business logic executes directly in PostgreSQL triggers & RLS; Edge Functions only used for FCM push, Google OAuth, AI Camera math solve, and AI Notebook RAG |
| **AI Vision & LLM Quota** | 1,500 requests/day ($0 free tier) | ~100–300 calls / day | Google AI Studio Gemini 1.5/2.0 Flash; enforced via per-user daily limits (20 solves/day) and cache |
| **Vector Storage (pgvector)** | 500 MB DB ceiling | ~20 MB for 5,000 chunks | Matryoshka dimension truncation to 768 float4s via `text-embedding-004`; orphaned chunks purged on delete |
| **Realtime** | 200 concurrent connections, 2M msgs | ~50–150 peak concurrent study rooms | Channels disconnect when mobile app is paused or placed in background |
| **Project Inactivity** | Pauses after 7 days of inactivity | 24/7 Awake | Automated GitHub Actions cron ping every 4 days |

---

## 2. Step-by-Step Setup Runbook

### Step 1: Create Free Supabase Project
1. Log in to [Supabase](https://supabase.com) and create an organization on the **Free Tier**.
2. Click **New Project**:
   - **Name**: `focuslearn`
   - **Database Password**: Generate a secure 32-character password and store it in your offline vault.
   - **Region**: Choose the closest region to your users (e.g. `ap-southeast-1` Singapore or `ap-south-1` Mumbai).
   - **Pricing Plan**: Free ($0/month).

### Step 2: Configure Cloudflare R2 Free Storage (10 GB Free + $0 Egress)
1. Log in to Cloudflare Dashboard and navigate to **R2**.
2. Create a bucket named `focuslearn-private`.
3. In **R2 Manage API Tokens**, create a token with `Admin Read & Write` permissions.
4. Note your:
   - `R2_ACCOUNT_ID`
   - `R2_ACCESS_KEY_ID`
   - `R2_SECRET_ACCESS_KEY`
   - `R2_BUCKET_PRIVATE` (`focuslearn-private`)

### Step 3: Apply Database Migrations
Link the repository to your remote Supabase project and apply migrations:
```bash
# Install Supabase CLI if needed
npm install -g supabase

# Login and link project
supabase login
supabase link --project-ref <your-project-id>

# Apply all migrations (000 to 090)
supabase db push
```

Verify that all tables and views are active:
- `public.profiles`
- `public.timetable_events`
- `public.study_sessions`
- `public.enforcement_policies`
- `public.policy_violations`
- `public.policy_overrides`
- `public.usage_monitoring_overview`

### Step 4: Deploy Edge Functions & Set Secrets
Set the required secrets in Supabase Cloud:
```bash
supabase secrets set \
  R2_ACCOUNT_ID="<your-cloudflare-account-id>" \
  R2_ACCESS_KEY_ID="<your-access-key-id>" \
  R2_SECRET_ACCESS_KEY="<your-secret-access-key>" \
  R2_BUCKET_PRIVATE="focuslearn-private" \
  FCM_SERVER_KEY="<your-firebase-server-key>" \
  GEMINI_API_KEY="<your-google-ai-studio-free-api-key>"

# Deploy Edge Functions
supabase functions deploy files-presign
supabase functions deploy files-confirm
supabase functions deploy files-sign-download
supabase functions deploy push-send
supabase functions deploy gcal-oauth
supabase functions deploy gcal-sync
supabase functions deploy ai-math-solve
supabase functions deploy ai-notebook-rag
```

### Step 5: Enable Nightly Data Pruning (`pg_cron`)
In Supabase SQL Editor, verify that `pg_cron` extension is enabled:
```sql
create extension if not exists pg_cron;

-- Schedule nightly table maintenance at 03:00 UTC
select cron.schedule('nightly-data-purge', '0 3 * * *', 'select private.purge_expired_data();');

-- Schedule pending account deletions at 04:00 UTC
select cron.schedule('process-pending-deletions', '0 4 * * *', 'select private.process_pending_deletions();');
```

### Step 6: Configure Inactivity Keep-Alive Workflow
In your GitHub repository:
1. Navigate to **Settings > Secrets and variables > Actions**.
2. Add secrets:
   - `SUPABASE_URL`: `https://<your-project-id>.supabase.co`
   - `SUPABASE_ANON_KEY`: `<your-publishable-anon-key>`
3. The workflow in `.github/workflows/supabase-keep-alive.yml` will automatically ping your REST gateway every 4 days, preventing the 7-day inactivity pause.

---

## 3. How to Restore a Paused Project
If your project is ever paused due to inactivity:
1. Log in to [https://supabase.com/dashboard](https://supabase.com/dashboard).
2. You will see a banner: **"Project is paused due to inactivity"**.
3. Click the green **"Restore Project"** button.
4. The database and functions will be restored within 1–2 minutes with all data intact.
5. In the mobile app or Admin SPA, an informative status banner prompts the user: *"Backend is waking up, please wait a moment."*

---

## 4. Usage Monitoring & Proactive Alerts
The Admin Dashboard includes a dedicated **Free-Plan Quota Monitor** tab displaying real-time gauges:
- **Database Size**: Threshold alerts at 350 MB (70% Amber) and 450 MB (90% Red).
- **R2 Storage**: Visual indicator of storage against the 10 GB free allowance.
- **Active Users**: Headroom tracker against the 50,000 MAU free allowance.
- **Manual Maintenance Action**: Admins can click *"Run Table Cleanup"* at any time to immediately purge stale logs and reclaim database space.

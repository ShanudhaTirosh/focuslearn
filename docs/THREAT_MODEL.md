# Threat model (STRIDE), version 0.1

Scope: self-hosted Supabase on a home laptop (later a VPS), Cloudflare in front, R2 for files,
Flutter clients, React admin. Living document, reviewed at the end of every phase.

## Assets (what we protect)

| Asset | Why it matters |
|---|---|
| Student identity and profile (many are minors) | Privacy, safety, legal exposure under PDPA No. 9 of 2022 (lawyer review needed) |
| Private notes, messages, files | Confidentiality between students |
| Auth tokens and sessions | Account takeover |
| Service-role key, JWT secret, R2 keys, SMTP password, FCM account, OAuth secrets | Full backend compromise |
| Database and backups | All of the above in bulk |
| Admin and Studio access | Privileged control |
| Device enrolment records | Must not become a surveillance tool |

## Trust boundaries

1. Client devices (untrusted) to Cloudflare edge.
2. Cloudflare to the home laptop via Tunnel (outbound-only link).
3. Kong gateway to internal services (Auth, REST, Realtime, Functions).
4. Services to Postgres.
5. Edge Functions to R2, SMTP, FCM, Google APIs (server secrets).
6. Admin browser to Access, then to the admin app, then to functions.

## Threats and mitigations

### Spoofing
| Threat | Mitigation |
|---|---|
| Credential stuffing or bot signups | Turnstile on signup, login, reset; per-IP and per-account rate limits; generic error messages |
| Stolen session | Short-lived access tokens, refresh rotation, session list and revoke, logout invalidates |
| Fake admin | Cloudflare Access plus Supabase Auth with MFA (AAL2) and re-auth for privileged actions |
| Spoofed role in a request | Roles are read from tables inside RLS and functions, never from client input |
| Phishing the reset email | Fixed redirect allowlist, SPF, DKIM, DMARC on the sending domain |

### Tampering
| Threat | Mitigation |
|---|---|
| Client edits focus minutes or streaks | Server computes `validated_s` and achievements; client values advisory |
| Client writes another user's rows | RLS on every table with allowed, denied and anonymous pgTAP tests |
| Edited share permission | Share changes go through SQL functions that check ownership and write an audit row |
| Tampered upload (wrong type) | Server-side MIME sniffing, allowlist, size caps, status `ready` only after confirm |
| Altered backups | `age` encryption plus checksum, restore drill verifies integrity |

### Repudiation
| Threat | Mitigation |
|---|---|
| Admin denies a change | Append-only `audit_logs`: who, what, when, from where, before and after, request id |
| Dispute over consent | Versioned, append-only `consents` records |

### Information disclosure
| Threat | Mitigation |
|---|---|
| Cross-user read of notes, messages, devices | RLS plus authorization tests for every private table |
| Private file bytes leaked | Private R2 bucket, signed URLs about 60 to 120 s, authorization checked on every sign request |
| Revoked share still downloads | Short signed-URL TTL, so revocation takes effect within one TTL. Documented residual: an already issued URL works until expiry |
| Secrets in client or git | Server-only env, `.gitignore`, gitleaks in CI, no service-role key in browser |
| Push payload shows message text | Generic payloads, content fetched after the app opens, lock-screen privacy setting |
| Studio or Postgres exposed | Studio behind Access only, Postgres bound to localhost or the docker network, no inbound ports (Tunnel) |
| Minors discoverable by strangers | Under-18 profiles private and undiscoverable by default |
| Calendar OAuth tokens leak | Encrypted at rest, server-side only, never selectable by clients |
| Laptop theft | Full-disk encryption, documented. Home hosting is dev and pilot only |

### Denial of service
| Threat | Mitigation |
|---|---|
| Request flood | Cloudflare proxy and WAF, rate limits in functions |
| Upload abuse | Per-user quota, size limits, direct-to-R2 uploads, Class A budget alerts |
| Realtime connection exhaustion | Subscribe only to open conversations, low-resource mode, limits per user |
| Laptop sleep, power cut, ISP outage | Documented as unmitigated at the pilot stage. Router failover for 2 ISPs, UPS advice, VPS later |
| Email cap exhaustion (free tier) | Resend rate limits, Turnstile, dormant second provider |
| Disk full | Disk alerts, log rotation, backup retention |

### Elevation of privilege
| Threat | Mitigation |
|---|---|
| `SECURITY DEFINER` abuse | Explicit `set search_path = ''`, input checks, justification comment, tests |
| Group admin gains device control | Separate group administrators from trusted device administrators; enrolment needs explicit consent |
| Group membership grants access to unrelated chats or notes | Access helpers check the specific resource, tested |
| Edge Function without authorization check | Shared auth helper required, lint rule and review checklist, tests |
| Compromised dependency | Dependabot, audit workflow, pinned versions, minimum-age rule for new releases |

## Child safety and abuse (non-STRIDE)

| Risk | Mitigation |
|---|---|
| Strangers contacting minors | No discoverability by default, friend or invite-only contact, block list enforced in RLS |
| Harassment in groups | Roles, moderation, reports table, mute and block |
| Bullying through shared notes | Reporting and moderator review, removal with audit |
| Admin overreach into student data | Least privilege, audit logs, admin cannot read private notes or messages by default |

## Residual risks accepted for the pilot

1. Single-host availability (home laptop).
2. No end-to-end encryption. We say so in the UI and docs.
3. Signed URLs already issued remain valid until they expire.
4. Free-tier services have no SLA (Turnstile, SMTP).

## Review checklist per phase
- New table: RLS enabled and forced, policies, pgTAP tests.
- New function: authorization first, input validation, rate limit, audit if privileged.
- New secret: server env only, rotation documented.
- New data field: added to `DATA_INVENTORY.md`.

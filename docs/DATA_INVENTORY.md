# Data inventory (draft)

**Not legal advice.** Retention periods and legal bases below are engineering proposals.
A lawyer familiar with Sri Lanka's Personal Data Protection Act, No. 9 of 2022 must review them
(especially minors, consent, retention, cross-border transfer and breach notification) before real
student data is collected.

Principle: collect the minimum, keep it for the shortest useful time, delete on request.

| Data | Examples | Purpose | Stored in | Sensitivity | Proposed retention | Deletion path |
|---|---|---|---|---|---|---|
| Account | email, password hash (Auth) | Login, verification, reset | Postgres `auth` | High | Life of account | Account deletion |
| Profile | display name, stream, subjects, birth year, time zone | Personalisation, age-aware defaults | `profiles` | Medium (minors) | Life of account | Account deletion |
| Avatar | image | Display | R2 (public bucket only if allowed, else private) | Medium | Life of account | Deletion job removes R2 object |
| Preferences | language, theme, quiet hours, low-resource mode | App behaviour | `user_preferences` | Low | Life of account | Account deletion |
| Consents | type, version, granted, revoked | Proof of consent | `consents` (append-only) | Medium | Keep proof for a period set by lawyer, then anonymise | Anonymise at deletion |
| Devices and sessions | platform, last seen, session id | Security, device management | `devices`, Auth sessions | Medium | Until revoked, purge after 90 days inactive (proposal) | Revoke or account deletion |
| Push tokens | FCM token | Delivery of notifications | `push_tokens` (not client-selectable) | Medium | Until rotated or removed | Remove on logout and deletion |
| Timetable | events, recurrence, exceptions, links | Planner | `timetable_events` etc. | Low to medium | Life of account | Account deletion |
| Meeting links | Zoom or Meet URLs | One-tap join | `timetable_events` | Medium (may contain passcodes) | Life of account | Account deletion |
| Focus sessions | start, end, validated seconds, subject | Stats, rewards | `study_sessions` | Low to medium | Life of account | Account deletion |
| Achievements and streaks | badges, streak counts | Gamification | `achievements` | Low | Life of account | Account deletion |
| Notes | text, tags, versions | Study | `notes`, `note_versions` | High (private) | Life of account | Account deletion, versions included |
| Note attachments | images, PDFs | Study | R2 private bucket, `file_objects` | High | Life of account | Deletion job removes R2 objects |
| Messages | text, replies, reactions | Chat | `messages` | High | Life of account, per-conversation rules in Phase 4 | Delete own, account deletion |
| Message attachments | files | Chat | R2 private bucket | High | As messages | Deletion job |
| Friends and blocks | relationships | Social graph | `friendships` | Medium | Life of account | Account deletion |
| Groups | membership, roles | Study groups | `groups`, `group_members` | Medium | Life of account | Leave, ownership transfer rules |
| Usage monitor data | app usage totals | Optional self-report, only with consent | Local first; server copy only if user opts in | High | Short (proposal: 30 days) | User can delete anytime |
| Device enrolment | level, consent id, revocation | Managed mode (explicit) | `device_enrollments` | High | While enrolled, plus audit retention | Revocation flow |
| Calendar connection | OAuth tokens (encrypted), external ids | Optional Google sync | `calendar_connections` (server only) | High | Until revoked | Revoke removes tokens |
| Audit logs | actor, action, before and after, IP, request id | Accountability | `audit_logs` | Medium | Proposal: 12 months | Anonymise actor on deletion where lawful |
| Reports | reporter, subject, reason | Moderation | `reports` | High | Proposal: 12 months after resolution | Case-based |
| Rate limit events | key, counts | Abuse prevention | `rate_limit_events` | Low | Proposal: 7 days | Auto-purge |
| Backups | encrypted dumps | Recovery | R2 backups bucket | High | Proposal: 14 days daily, 8 weeks weekly | Expire by lifecycle rule. Deleted users persist in backups until expiry, to be stated in the privacy notice |
| Server logs | request metadata | Operations | Host and Cloudflare | Medium | Proposal: 14 days locally | Rotation |
| Email | verification and reset mail via SMTP provider | Account flows | SMTP provider | Medium | Provider policy: verify | Provider side |

## Not collected (by design)
Location, contacts, microphone, camera (beyond user-selected image upload), keystrokes, screen content,
message contents from other apps, advertising identifiers.

## Cross-border processing (flag for lawyer)
Cloudflare, the SMTP provider, Firebase Cloud Messaging and Google Calendar process some data outside
Sri Lanka. Record each processor, location and purpose in the privacy notice.

## Minors
- Ask year of birth only. Under 18: private profile, not discoverable, stricter sharing defaults.
- No behavioural advertising, no data sale, no profiling for third parties.
- Parental-consent requirements under PDPA: lawyer to confirm. Do not invent a legal threshold in the app.

## Account deletion (summary, detailed in Phase 1)
1. User requests deletion, the request is recorded in `deletion_requests`.
2. Grace period (proposal: 7 days, cancellable).
3. A job deletes database rows, removes R2 objects, revokes sessions and push tokens, revokes calendar tokens.
4. Backups age out by retention rules.
5. A confirmation email is sent.

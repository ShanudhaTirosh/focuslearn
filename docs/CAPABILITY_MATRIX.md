# Platform capability matrix

Status: **hypothesis, unverified on devices.** Updated in Phase 7 with real-device results.
Never imply Android, Windows, iOS and web are equivalent.

Legend: **FS** fully supported · **UP** supported with user permission · **MD** managed devices only ·
**VO** voluntary only · **NS** unsupported · `?` needs a spike before we commit.

## Core app

| Feature | Android | Windows | iOS (later) | Web (later) | Verify in |
|---|---|---|---|---|---|
| Auth, profile, sessions | FS | FS | FS | FS | Phase 1 |
| Timetable, notes, chat, calculators | FS | FS | FS | FS | Phases 2, 4, 5 |
| Offline cache and queued sync | FS | FS | FS | UP (browser can evict storage) | Phase 3 |
| Secure token storage | FS (Keystore) | UP (DPAPI via plugin, fallback documented) | FS | weaker | Phase 1 |
| Class link opens in Zoom, Meet, browser | FS | FS | FS | FS | Phase 2 |
| Google Calendar sync (server-side OAuth) | FS | FS | FS | FS | Phase 6 |

## Reminders and notifications

| Feature | Android | Windows | Notes |
|---|---|---|---|
| Local reminders | UP: notification permission, exact-alarm permission. Reliability depends on battery optimisation and OEM task killers | UP: works while app runs or has a registered startup path `?` | Reliability checklist screen on Android |
| Reminder after reboot | UP: boot receiver. Some OEMs block it | VO: depends on a startup entry the user allows | Test on a real low-end phone |
| Alarm while device is off | **NS** | **NS** | Never promise this |
| Push (generic payload only) | FS via FCM | `?` No first-class FCM for Flutter on Windows. Options: Realtime while running, local notifications, WNS if packaged | Decide in Phase 6 |
| Lock-screen privacy | FS (generic payload, no message text) | FS | Default on |

## Focus levels (names shown in UI)

| Feature | Android | Windows |
|---|---|---|
| **Level 1: Focus mode (voluntary)** timer, nudges, tree growth | FS (VO) | FS (VO) |
| Always-on-top timer | UP (overlay permission, optional) | VO (window flag, user can close) |
| Installed-app picker | UP: Android 11+ package visibility. `QUERY_ALL_PACKAGES` is Play-restricted, so prefer a `<queries>` allowlist | FS (read installed apps) |
| **Level 2: Usage monitor (with permission)** own usage report | UP: Usage Access, revocable consent | UP: foreground-process sampling, only with consent `?` |
| Warning overlay on non-allowed app | VO: nudge notification. Accessibility overlay only if disclosed and Play-approved `?` | VO: overlay the user can dismiss |
| **Level 3: Managed-device mode** hard lockdown | **MD**: Device Owner, lock task mode, on provisioned devices only | **MD**: Assigned Access or kiosk, admin policy |
| Prevent closing the app or user switching | **NS** on a personal device | **NS** for an ordinary desktop app |
| Emergency calling and visible exit | FS, always allowed | FS |

Rule: no feature in level 1 or 2 may silently restrict the owner, hide itself, intercept messages or block
removal of the app.

## Honest statements for the UI and docs

- "Focus mode helps you stay on task. It cannot lock your phone or laptop."
- "Managed-device mode works only on devices that were set up for it and that you agreed to enrol."
- "Reminders can be delayed by your phone's battery settings. Use the reliability checklist."
- "Chat is encrypted in transit (TLS). It is not end-to-end encrypted."

## Open spikes before commitment

1. Windows push strategy (Phase 6).
2. Windows foreground-process sampling legality and API choice (Phase 7).
3. Android exact-alarm policy for sideload vs Play (`USE_EXACT_ALARM` vs `SCHEDULE_EXACT_ALARM`), verify current Play rules (Phase 2).
4. Whether an Accessibility Service is needed at all. Default answer: no (Phase 7).

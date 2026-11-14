# Mobile Device Management (MDM) Feasibility Report & Integration Analysis

This report evaluates mobile device management (MDM) approaches for the Focus Learn companion app, analyzing feature feasibility, platform requirements, Google Play Store compliance, cost implications, and integration within the **Supabase Free Plan**.

---

## 1. Executive Summary & Recommended Approach

To achieve effective distraction blocking and study enforcement while keeping hosting costs at **$0** and ensuring compatibility with students' personal devices, Focus Learn implements:

1. **Primary Engine (Active for all students)**:
   - **App-Level Controls** via Android `PACKAGE_USAGE_STATS` (Usage Access) and `SYSTEM_ALERT_WINDOW` (Display over other apps).
   - Requires **no factory reset**, functions on any standard personal Android phone (Android 8 to 15+), complies 100% with Google Play Store consumer policies, and requires zero cloud infrastructure costs.
2. **Managed Extension (For dedicated school/family tablets)**:
   - Built-in `FocusDeviceAdminReceiver` supporting Android LockTask (Kiosk) mode when provisioned via ADB or Device Owner QR code.
3. **Excluded as Infeasible**:
   - Cloud EMM (Android Management API) due to required Google Cloud billing accounts and external API costs.
   - Work Profile mode due to Android's strict boundary preventing personal profile app monitoring.

---

## 2. Comparative Analysis of MDM Approaches

| Feature / Criteria | 1. Android Management API (Google Cloud EMM) | 2. Custom DPC (Device Owner Mode) | 3. Work Profile (Profile Owner Mode) | 4. App-Level Controls (Focus Learn Selected) |
|---|---|---|---|---|
| **Enrolment Requirement** | Factory reset + 6 taps for QR code or zero-touch | Factory reset + QR code OR `adb shell dpm set-device-owner` | Work account addition | Simple standard Android permission toggle in settings |
| **Personal Device Suitability** | ❌ **Unusable**: Wipes personal data | ❌ **Impractical**: Requires ADB or wipe | ⚠️ Permitted, but cannot monitor personal apps | ✅ **Optimal**: Zero device wipe or root required |
| **App Allow/Block Lists** | ✅ Full policy block | ✅ True app suspension (`setPackagesSuspended`) | ❌ Work apps only | ✅ Real-time foreground detection & blocking overlay |
| **Kiosk / LockTask Mode** | ✅ Supported | ✅ Supported via `startLockTask()` | ❌ Not supported | ⚠️ Voluntary full-screen overlay + auto-redirect |
| **Restricting Android Settings** | ✅ System settings blocked | ✅ Supported via `addUserRestriction` | ❌ Work container only | ❌ Platform protected (user can access settings) |
| **Scheduled Study Policies** | ✅ Pushed via EMM policy | ✅ Evaluated locally & synced to DB | ❌ Ineffective for personal apps | ✅ Evaluated locally via SQLite & synced to Supabase |
| **Device Status Reporting** | ✅ Battery, OS, app inventory | ✅ Battery, OS, app inventory | ⚠️ Work metrics only | ✅ Battery, app inventory, violation history |
| **Google Play Policy Fit** | Dedicated enterprise tracks only | Restricted on standard consumer track | Enterprise compliant | ✅ **Fully Play Store compliant** with in-app disclosure |
| **Infrastructure Cost** | ❌ Requires Google Cloud billing account | ✅ **$0** (Runs on Supabase backend) | ✅ **$0** | ✅ **$0** (Runs on Supabase Free Plan) |

---

## 3. Feature-by-Feature Breakdown

### 3.1 App Allow & Block Lists
- **App-Level Implementation (Built)**:
  - When a focus session or scheduled study window starts, a native background monitor periodically inspects the foreground package via `UsageStatsManager`.
  - If a blacklisted package (e.g. `com.instagram.android`, `com.zhiliaoapp.musically`, `com.google.android.youtube`) is detected, Focus Learn immediately triggers `bringAppToFront()` and displays the full-screen `EnforcementOverlayScreen`.
  - The violation is logged to `policy_violations` locally and synced to Supabase.
- **Requirements**: User grants `PACKAGE_USAGE_STATS` and `SYSTEM_ALERT_WINDOW` permissions once.
- **Cost**: $0.

### 3.2 Kiosk / LockTask Mode
- **Managed Implementation (Built in `FocusDeviceAdminReceiver`)**:
  - Devices enrolled as Device Owner can call `DevicePolicyManager.setLockTaskPackages()` and `activity.startLockTask()`.
  - The device is pinned to Focus Learn: Home, Overview, and Back buttons are disabled, status bar notifications are hidden, and the student cannot exit until the timer completes or the supervisor unlocks it.
- **Requirements**: Device provisioned via Device Owner mode (dedicated school tablet).
- **Cost**: $0.

### 3.3 Scheduled Study Windows & Daily Recreational Limits
- **Implementation (Built in `EnforcementRepository`)**:
  - Policies are stored in Supabase table `enforcement_policies` with `schedule_days`, `start_time`, and `end_time`.
  - Policies are synced to local `SharedPreferences` cache so enforcement continues seamlessly when the device is offline or in airplane mode.
- **Requirements**: None beyond standard app permissions.
- **Cost**: $0.

### 3.4 Emergency Overrides & Transparent Auditing
- **Implementation (Built)**:
  - If an emergency occurs during a locked session, the student can tap **"Emergency Override"**.
  - A mandatory reason must be provided (minimum 3 characters).
  - The override unlocks the device for 15 minutes, logs to `policy_overrides`, and remains permanently visible in the student and guardian history.
- **Requirements**: None.
- **Cost**: $0.

---

## 4. What is Feasible vs What is Infeasible

### Feasible & Built
1. **Real-time distraction interception**: Instantly nudges students back to their study session upon opening distracting entertainment apps.
2. **Supervised rules**: Guardians and teachers can define rules from the Admin Dashboard, which sync down to student devices.
3. **Offline rule enforcement**: Rules continue operating when devices lose connectivity.
4. **Complete transparency**: Students see exactly which rules apply, who set them, and can audit all recorded violations and overrides.
5. **Zero-cost operations**: Entirely operates within the Supabase Free Plan and device-local compute.

### What is Infeasible on Personal Devices
1. **Silent / Invisible Tracking**: Google Play Store policies strictly prohibit hiding the app or monitoring app usage without explicit, prominent in-app disclosure. Focus Learn complies by requiring user consent and providing full visibility.
2. **Preventing App Uninstallation**: On unmanaged personal devices, Android OS always allows the device owner to uninstall third-party apps via Settings. Only managed Device Owner mode can block uninstallation.
3. **Modifying System Settings Without Permission**: Changing system settings (such as airplane mode or Wi-Fi state) requires system-level signature permissions unavailable to non-system apps.

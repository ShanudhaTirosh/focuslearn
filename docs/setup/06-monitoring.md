# 06. Monitoring: heartbeat and backup alarms (Phase 0.10)

Sources read 2026-10-15 (third-party comparisons, not vendor pages): free-tier figures below are **verify before deployment**.

## Why a heartbeat, not only an outside probe
A home laptop fails by going silent: power cut, ISP outage, tunnel drop, crash. A "dead man's switch" handles all of these with one idea: the laptop pings an outside monitor every 5 minutes, and the monitor alerts you when pings **stop**.
It also fires immediately when the laptop reports itself unhealthy. An outside probe of a public URL adds little today: every API path needs an API key (the gateway rejects keyless requests), and the tunnel only forwards four path prefixes. Revisit in Phase 9 once a public, keyless status endpoint exists.

## Provider choice
| Option | Free tier (as found) | Fit |
|---|---|---|
| **Healthchecks.io** (recommended) | 20 checks, 100 log entries per check | Built for "alert when a ping is late". Provides a `/fail` signal and email alerts. Check its terms for your use |
| UptimeRobot | 50 monitors, 5-minute checks, **non-commercial use only** since late 2024 (sources differ on the exact date) | Probes from outside, which we cannot use yet. Terms may exclude a school project run as a business |
| Better Stack | 10 monitors + 10 heartbeats, 3-minute checks | Alternative with heartbeats |
| StatusCake | 10 monitors, 5-minute, must log in every 90 days | Probes only |
| Freshping | Shut down in March 2026 | Not available |

## Set up (about 10 minutes)
1. Create a Healthchecks.io account. Create **two checks**:
   - `focuslearn-heartbeat`: period **5 minutes**, grace **10 minutes**. Alerts after about 15 minutes of silence.
   - `focuslearn-backup`: period **1 day**, grace **6 hours**.
2. Add your email as the alert channel. Add a second channel (phone push or Telegram) so one lost inbox is not a single point of failure.
3. Copy each check's **ping URL**. These are secrets (anyone holding one can send pings): put them only in `infra/docker/.env` (`HEARTBEAT_URL`) and `infra/backup/.env` (`BACKUP_PING_URL`). Both must be `https://`.
4. Install the timer: `sudo bash infra/scripts/install-heartbeat.sh` (it refuses while `HEARTBEAT_URL` is empty).
5. Confirm both checks turn green in the dashboard after the first run (`bash infra/scripts/heartbeat.sh`, then `bash infra/backup/backup.sh`).

## Prove the alarms work (record the times in `docs/setup/measurements.md`)
| Test | How | Expect |
|---|---|---|
| Silence | `sudo systemctl stop focuslearn-heartbeat.timer`, wait | Alert after about 15 minutes. Then start the timer again |
| Unhealthy | `bash infra/scripts/stack.sh stop`, wait for the next run | An immediate `/fail` alert, with the failing line in the check's log. Then start the stack |
| Network loss | Unplug Ethernet (or the ISP) for 20 minutes | An alert about silence. Note whether the second ISP kept it quiet |
| Backup silence | Skip a daily backup (or lower the grace period) | The backup check goes late and alerts |

## What it does and does not tell you
- It proves the laptop is alive, the stack is healthy by `healthcheck.sh` (containers, API through the gateway, disk, backup freshness), and that the laptop can reach the internet.
- It does **not** prove that students can reach you: DNS, the Cloudflare edge or an expired Access policy could still break the public path. `verify-edge.sh` covers that on demand.
- It does not measure speed or errors seen by users.

## Privacy
The monitor learns that you are alive and, on failure, up to 500 bytes of health-check text (container names, statuses, disk percentage; never keys, URLs or user data). It is still another processor: list it in the privacy notice and `DATA_INVENTORY.md`. If you prefer to send nothing but the signal, leave the failure body empty by editing `heartbeat.sh` (one line).

## Rotate a ping URL
Regenerate it in the dashboard, edit the `.env` file, run the script once, confirm green.

## Known issues
- **Not run against a real monitor.** Verified offline (13 heartbeat tests plus the backup ping cases, with a local server as the monitor): GET when healthy, POST to `/fail` when not, the 500-byte cap, no double slash, secret URLs never printed, refusal of empty and non-https URLs, a dead or erroring monitor, and the timer units with `systemd-analyze verify`.
- The `/fail` suffix, POST bodies and free-tier numbers come from memory and third-party pages: confirm in the Healthchecks.io documentation.
- A sleeping laptop stops pinging: the power settings in `hardening.md` are what prevent that.
- A monitor that is itself down cannot alert you. Two channels reduce, not remove, the risk.

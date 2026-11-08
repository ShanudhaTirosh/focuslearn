# Measurements (fill in during Phase 0; one dated entry per measurement)

Hardware: laptop model, CPU, RAM, disk type and size, Ubuntu version, wired or Wi-Fi, ISP 1 and ISP 2 names and speeds.

## Answers to open questions
| Question | Answer | Date |
|---|---|---|
| Did R2 ask for a payment method? | | |
| Did Zero Trust ask for a payment method? | | |
| Did Brevo ask for a payment method, and how long did account approval take? | | |
| Is the disk encrypted? (passphrase / TPM / none) | | |
| Link host and path in the confirmation email (settles `API_EXTERNAL_URL`) | | |
| Is a signed content-length enforced by R2? | | |
| Does the R2 CORS JSON apply as written? | | |
| Does Brevo free mail carry a footer? Is tracking disabled for transactional mail? | | |

## Stack (10 minutes idle)
| Metric | Value |
|---|---|
| `free -h` used / total / swap | |
| `docker stats --no-stream`: total RAM of containers, highest CPU | |
| `docker system df` images size | |
| Time from `stack.sh up` to healthy | |
| Time to healthy after a reboot (no human action) | |

## Edge and failover (`docs/setup/02-cloudflare-edge.md` section F)
| Test | Result (seconds of outage / behaviour) |
|---|---|
| cloudflared container restart: seconds of `000` | |
| Realtime WebSocket: reconnects by itself? after how long? | |
| Primary ISP unplugged: outage seconds, traffic returned on ISP 2? | |
| Reboot: tunnel and stack back without help? | |

## R2 spike
Paste the full output. Upload speed (MiB/s) from the server and from a normal home connection: ____ / ____

## Email
| Provider (Gmail / other) | Inbox or spam | DKIM | DMARC | Minutes to arrive |
|---|---|---|---|---|
| | | | | |

## Backups and the restore drill
| Metric | Value |
|---|---|
| Encrypted dump size | |
| `backup.sh` duration, upload duration | |
| Drill: total seconds (database RTO) | |
| Drill: `pg_restore` error lines (paste them; mark which are benign) | |
| Offline copy of the latest weekly set made on | |
| `systemctl list-timers focuslearn-backup.timer`: next run | |

## Monitoring (`docs/setup/06-monitoring.md`)
| Test | Minutes until the alert arrived | Channel |
|---|---|---|
| Heartbeat silence | | |
| Unhealthy (`/fail`) | | |
| Network loss | | |
| Backup silence | | |

## Phase 7/9 performance budgets (set now, measure later)
Cold start, APK size, idle RAM, battery per focus hour on a low-end Android phone and an older Windows laptop: **targets to be agreed in Phase 1**.

#!/usr/bin/env bash
# Runs all offline email tooling tests. No network needed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0
echo "== DNS checker"; bash "$HERE/test-email-dns.sh" || rc=1
echo "== SMTP sender"; python3 "$HERE/test_send_email.py" || rc=1
exit "$rc"

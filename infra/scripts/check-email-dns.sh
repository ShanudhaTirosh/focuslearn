#!/usr/bin/env bash
# Checks the public DNS for email authentication of a sending domain, using Cloudflare's DNS-over-HTTPS (needs curl + python3).
# Usage: check-email-dns.sh DOMAIN [--dkim SELECTOR]...
#   Selector names come from your SMTP provider's dashboard (for example the part before ._domainkey).
# Exit code 1 if any hard check fails. WARN lines do not fail.
# Offline testing: set DNS_STUB_DIR to a directory of files named <TYPE>_<name>.json.
set -uo pipefail

domain="${1:?usage: check-email-dns.sh DOMAIN [--dkim SELECTOR]...}"; shift
selectors=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dkim) selectors+=("${2:?--dkim needs a selector}"); shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

doh() {  # name type -> JSON
  if [ -n "${DNS_STUB_DIR:-}" ]; then
    cat "$DNS_STUB_DIR/${2}_${1}.json" 2>/dev/null || echo '{"Status":3}'
  else
    curl -sS -m 10 -H 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=${1}&type=${2}" 2>/dev/null || echo '{"Status":2}'
  fi
}
answers() {  # name type -> lines "TYPE<TAB>DATA" (type 16 = TXT, 5 = CNAME)
  doh "$1" "$2" | python3 -c 'import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
for a in (d.get("Answer") or []):
    print("%s\t%s" % (a.get("type"), a.get("data", "")))'
}
txt() {  # name -> TXT strings, one per line, quotes and chunk splits removed
  answers "$1" TXT | awk -F'\t' '$1==16{print $2}' | sed -e 's/^"//' -e 's/"$//' -e 's/" "//g'
}

command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 2; }
if [ -z "${DNS_STUB_DIR:-}" ]; then command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 2; }; fi

fail=0
ok()   { printf 'OK    %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; fail=1; }
warn() { printf 'WARN  %s\n' "$1"; }

# DMARC: exactly one record
dm="$(txt "_dmarc.$domain" | grep -i '^v=DMARC1' || true)"
n="$(printf '%s' "$dm" | grep -c . || true)"
if [ "$n" = 0 ]; then
  bad "no DMARC record at _dmarc.$domain"
elif [ "$n" -gt 1 ]; then
  bad "$n DMARC records at _dmarc.$domain (must be exactly one)"
else
  pol="$(printf '%s' "$dm" | tr ';' '\n' | sed 's/^ *//' | grep -i '^p=' | head -n1 | cut -d= -f2)"
  ok "DMARC present, policy p=${pol:-?}"
  [ "${pol:-}" = none ] && warn "DMARC p=none is monitoring only. Move to quarantine after clean reports."
fi

# DKIM selectors
if [ "${#selectors[@]}" = 0 ]; then
  warn "no --dkim selectors given; DKIM not checked. Pass the selector names shown in your SMTP provider."
fi
for s in "${selectors[@]}"; do
  name="$s._domainkey.$domain"
  all="$(answers "$name" TXT)"
  keys="$(printf '%s\n' "$all" | awk -F'\t' '$1==16' | grep -c 'p=' || true)"
  cn="$(printf '%s\n' "$all" | awk -F'\t' '$1==5' | grep -c . || true)"
  if [ "${keys:-0}" -gt 0 ]; then
    ok "DKIM key resolves at $name"
  elif [ "${cn:-0}" -gt 0 ]; then
    warn "$name is a CNAME but no public key resolves yet (propagation, wrong target, or Cloudflare proxy ON: it must be DNS only)"
  else
    bad "no DKIM record at $name"
  fi
done

# Provider verification code (some providers ask for it)
if txt "$domain" | grep -qi '^brevo-code:'; then ok "provider verification TXT present"; else warn "no brevo-code TXT at $domain (only needed if Brevo asked for it)"; fi

# SPF (informational: a shared-IP provider may rely on DKIM alone, but a wrong SPF can still hurt)
spf="$(txt "$domain" | grep -i '^v=spf1' || true)"
if [ -n "$spf" ]; then ok "SPF present: $spf"; else warn "no SPF at $domain (DKIM alone can satisfy DMARC on a shared-IP provider: confirm with the provider)"; fi

exit "$fail"

#!/usr/bin/env bash
# Offline tests for check-email-dns.sh using stubbed DNS answers.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHK="$HERE/../check-email-dns.sh"
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
pass=0; failn=0
expect() { # description expected_exit actual_exit
  if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "PASS  $1"; else failn=$((failn+1)); echo "FAIL  $1 (wanted exit $2, got $3)"; fi
}
has() { # description needle haystack
  if printf '%s' "$3" | grep -qF -- "$2"; then pass=$((pass+1)); echo "PASS  $1"; else failn=$((failn+1)); echo "FAIL  $1"; fi
}
mk() { printf '%s' "$3" > "$D/${1}_${2}.json"; }   # type name json

# Healthy domain: one DMARC (p=quarantine), DKIM TXT with key, DKIM CNAME chain with key, SPF, provider code
mk TXT _dmarc.good.example '{"Status":0,"Answer":[{"type":16,"data":"\"v=DMARC1; p=quarantine; rua=mailto:r@good.example\""}]}'
mk TXT k1._domainkey.good.example '{"Status":0,"Answer":[{"type":16,"data":"\"v=DKIM1; k=rsa; p=MIIBIjAN\" \"BgkqhkiG9w0BAQ\""}]}'
mk TXT k2._domainkey.good.example '{"Status":0,"Answer":[{"type":5,"data":"b2.good.dkim.example."},{"type":16,"data":"\"v=DKIM1; p=ABCDEF\""}]}'
mk TXT good.example '{"Status":0,"Answer":[{"type":16,"data":"\"v=spf1 include:spf.example ~all\""},{"type":16,"data":"\"brevo-code:abc123\""}]}'
out="$(DNS_STUB_DIR="$D" bash "$CHK" good.example --dkim k1 --dkim k2)"; rc=$?
expect "healthy domain passes" 0 "$rc"
has "reports DMARC policy" "p=quarantine" "$out"
has "reports DKIM ok" "DKIM key resolves at k1._domainkey.good.example" "$out"

# Missing DMARC fails
out="$(DNS_STUB_DIR="$D" bash "$CHK" nodmarc.example)"; rc=$?
expect "missing DMARC fails" 1 "$rc"

# Two DMARC records fail (provider says exactly one)
mk TXT _dmarc.dup.example '{"Status":0,"Answer":[{"type":16,"data":"\"v=DMARC1; p=none\""},{"type":16,"data":"\"v=DMARC1; p=reject\""}]}'
out="$(DNS_STUB_DIR="$D" bash "$CHK" dup.example)"; rc=$?
expect "duplicate DMARC fails" 1 "$rc"
has "explains duplicate" "must be exactly one" "$out"

# Missing DKIM selector fails
mk TXT _dmarc.nodkim.example '{"Status":0,"Answer":[{"type":16,"data":"\"v=DMARC1; p=none\""}]}'
out="$(DNS_STUB_DIR="$D" bash "$CHK" nodkim.example --dkim brevo1)"; rc=$?
expect "missing DKIM selector fails" 1 "$rc"
has "p=none warns" "monitoring only" "$out"

# CNAME without resolved key is a warning, not a pass
mk TXT _dmarc.cn.example '{"Status":0,"Answer":[{"type":16,"data":"\"v=DMARC1; p=none\""}]}'
mk TXT s1._domainkey.cn.example '{"Status":0,"Answer":[{"type":5,"data":"target.example."}]}'
out="$(DNS_STUB_DIR="$D" bash "$CHK" cn.example --dkim s1)"; rc=$?
expect "CNAME without key does not fail hard" 0 "$rc"
has "CNAME without key warns and mentions proxy" "DNS only" "$out"

printf '\n%d passed, %d failed\n' "$pass" "$failn"
[ "$failn" -eq 0 ]

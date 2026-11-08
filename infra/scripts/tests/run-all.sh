#!/usr/bin/env bash
# Runs EVERY offline test suite in the repo. No Docker, network, Postgres or root needed.
# Usage: bash infra/scripts/tests/run-all.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
rc=0
run() { printf '\n=== %s\n' "$1"; shift; if "$@"; then printf -- '--- OK: %s\n' "$LABEL"; else printf -- '--- FAILED: %s\n' "$LABEL"; rc=1; fi; }
LABEL="stack libs and tunnel template";   run "$LABEL" bash "$ROOT/infra/docker/tests/test-lib.sh"
LABEL="email tooling";                    run "$LABEL" bash "$ROOT/infra/scripts/tests/run-email-tests.sh"
LABEL="backup tooling";                   run "$LABEL" python3 "$ROOT/infra/backup/tests/test_backup.py"
LABEL="host hardening and audit";         run "$LABEL" python3 "$ROOT/infra/scripts/tests/test_host_tools.py"
LABEL="migration linter";                 run "$LABEL" python3 "$ROOT/infra/scripts/tests/test_lint_migrations.py"
LABEL="migration and pgTAP runners";      run "$LABEL" python3 "$ROOT/infra/scripts/tests/test_db_runners.py"
LABEL="heartbeat";                        run "$LABEL" python3 "$ROOT/infra/scripts/tests/test_heartbeat.py"
LABEL="phase 0 report script";            run "$LABEL" python3 "$ROOT/infra/scripts/tests/test_phase0_verify.py"
LABEL="pgTAP plan checker";               run "$LABEL" python3 "$ROOT/infra/scripts/tests/test_pgtap_plans.py"
LABEL="design tokens and contrast";       run "$LABEL" python3 "$ROOT/packages/design_system/tools/test_tokens.py"
LABEL="client validation contract";       run "$LABEL" python3 "$ROOT/packages/core/tools/test_validation_contract.py"
LABEL="planner contract (recurrence, links, reminders, SQL parity)"; run "$LABEL" python3 "$ROOT/packages/core/tools/test_planner_contract.py"
LABEL="Dart zone-resolver algorithm";      run "$LABEL" python3 "$ROOT/packages/core/tools/test_resolver_algorithm.py"
LABEL="calculators (vectors, properties)"; run "$LABEL" python3 "$ROOT/packages/core/tools/test_calc_contract.py"
LABEL="Dart BigInt semantics (calculators)"; run "$LABEL" python3 "$ROOT/packages/core/tools/test_dart_bigint_port.py"
LABEL="focus rules (vectors, properties, SQL parity)"; run "$LABEL" python3 "$ROOT/packages/core/tools/test_focus_contract.py"
LABEL="Dart consistency checker";         run "$LABEL" python3 "$ROOT/infra/scripts/tests/test_dart_consistency.py"
LABEL="SigV4 signer selftest";            run "$LABEL" python3 "$ROOT/infra/cloudflare/r2-spike/r2_spike.py" --selftest
printf '\n%s\n' "$([ "$rc" = 0 ] && echo 'ALL SUITES PASSED' || echo 'SOME SUITES FAILED')"
exit "$rc"

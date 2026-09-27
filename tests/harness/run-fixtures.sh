#!/usr/bin/env bash
# Unit tests для validators: fixtures с ожидаемыми exit codes (§45–46).
# Запускается из check-all.sh — aggregate harness падает при любом несовпадении.
set -euo pipefail

cd "$(dirname "$0")/../.."

failures=0
expect() { # expected_exit label command...
  local expected="$1" label="$2"; shift 2
  local actual
  if "$@" >/dev/null 2>&1; then actual=0; else actual=$?; fi
  if [[ "$actual" -ne "$expected" ]]; then
    echo "FAIL: $label expected exit $expected, got $actual" >&2
    failures=1
  else
    echo "ok: $label (exit $actual)"
  fi
}

FIX=tests/harness/fixtures

# §46 Test 1: COMPLETED с CHANGES_REQUIRED → FAIL
expect 1 "invalid-state-verdict"  env STATE_FILE="$FIX/invalid-state-verdict/STATE.md" bash tests/harness/check-state.sh
# §46 Test 2: REVIEW_READY→IMPLEMENTATION_PENDING с APPROVED → FAIL
expect 1 "invalid-transition"     env STATE_FILE="$FIX/invalid-transition/STATE.md" bash tests/harness/check-state.sh
# §46 Test 3: REVIEW_READY→IMPLEMENTATION_PENDING с CHANGES_REQUIRED → PASS
expect 0 "valid-changes-required" env STATE_FILE="$FIX/valid-changes-required/STATE.md" bash tests/harness/check-state.sh
# §46 Test 4: WAITING_HUMAN без suspended state → FAIL
expect 1 "invalid-waiting-human"  env STATE_FILE="$FIX/invalid-waiting-human/STATE.md" bash tests/harness/check-state.sh
# §46 Test 5: HALTED с невалидной причиной → FAIL
expect 1 "invalid-halted"         env STATE_FILE="$FIX/invalid-halted/STATE.md" bash tests/harness/check-state.sh
# §46 Test 6: глобальный duplicate ID → FAIL
expect 1 "duplicate-id"           env CONTRACTS_GLOB="$FIX/duplicate-id/*.md" bash tests/harness/check-contracts.sh
# dangling reference → FAIL
expect 1 "dangling-reference"     env CONTRACTS_GLOB="$FIX/dangling-reference/*.md" bash tests/harness/check-contracts.sh
# positive contracts fixture → PASS
expect 0 "valid-contracts"        env CONTRACTS_GLOB="$FIX/valid-contracts/*.md" bash tests/harness/check-contracts.sh

if [[ "$failures" -eq 0 ]]; then
  echo "PASS: all fixture tests behave as expected"
fi
exit "$failures"

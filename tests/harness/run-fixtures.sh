#!/usr/bin/env bash
# Unit tests для validators: fixtures с ожидаемыми exit codes (§35–36).
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
state() { env STATE_FILE="$FIX/$1/STATE.md" bash tests/harness/check-state.sh; }
contracts() { env CONTRACTS_GLOB="$FIX/$1/*.md" bash tests/harness/check-contracts.sh; }

# --- Terminal state: COMPLETED (REQ-HARNESS-018) ---
expect 0 "valid-completed-approved"                state valid-completed-approved
expect 0 "valid-completed-approved-with-changes"   state valid-completed-approved-with-changes
expect 1 "invalid-state-verdict (CHANGES_REQUIRED)" state invalid-state-verdict
expect 1 "invalid-completed-rejected"              state invalid-completed-rejected

# --- Verdict routing REVIEW_READY (REQ-HARNESS-019/020) ---
expect 0 "valid-changes-required"                  state valid-changes-required
expect 1 "invalid-transition (APPROVED)"           state invalid-transition
expect 0 "valid-architecture-rejected"             state valid-architecture-rejected
expect 1 "invalid-architecture-transition"         state invalid-architecture-transition

# --- WAITING_HUMAN (REQ-HARNESS-026/027) ---
expect 1 "invalid-waiting-human (no suspended)"    state invalid-waiting-human
expect 1 "invalid-waiting-human-no-q"              state invalid-waiting-human-no-q
expect 1 "invalid-waiting-human-unknown-q"         state invalid-waiting-human-unknown-q

# --- HALTED (REQ-HARNESS-021/028) ---
expect 1 "invalid-halted (bad reason)"             state invalid-halted
expect 1 "invalid-halted-no-reason"                state invalid-halted-no-reason
expect 1 "invalid-halted-no-evidence"              state invalid-halted-no-evidence

# --- INIT taint (§36) ---
expect 1 "invalid-init-historical"                 state invalid-init-historical
expect 1 "invalid-init-commit"                     state invalid-init-commit

# --- Template mode (REQ-HARNESS-025) ---
expect 0 "valid-template-init" env AGENT_ARTIFACTS_DIR="$FIX/valid-template-init/agent" STATE_FILE="$FIX/valid-template-init/STATE.md" bash tests/harness/check-state.sh
expect 1 "invalid-template-completed" env AGENT_ARTIFACTS_DIR="$FIX/valid-template-completed/agent" STATE_FILE="$FIX/invalid-template-completed/STATE.md" bash tests/harness/check-state.sh
expect 1 "invalid-template-contaminated" env AGENT_ARTIFACTS_DIR="$FIX/invalid-template-contaminated/agent" STATE_FILE="$FIX/invalid-template-contaminated/STATE.md" bash tests/harness/check-state.sh

# --- Contracts (REQ-HARNESS-014/015) ---
expect 1 "duplicate-id"                            contracts duplicate-id
expect 1 "dangling-reference"                      contracts dangling-reference
expect 0 "valid-contracts"                         contracts valid-contracts

if [[ "$failures" -eq 0 ]]; then
  echo "PASS: all fixture tests behave as expected"
fi
exit "$failures"

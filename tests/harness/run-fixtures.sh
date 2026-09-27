#!/usr/bin/env bash
# Unit tests для validators: fixtures с ожидаемым исходом И причиной отказа (§35–36).
# Каждый негативный кейс проверяет не только exit code, но и подстроку в ошибке —
# иначе fixture может «проходить» по неверной причине (см. P0-регрессию escalation).
set -euo pipefail

cd "$(dirname "$0")/../.."

failures=0
FIX=tests/harness/fixtures

expect_pass() { # label command...
  local label="$1"; shift
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "FAIL: $label expected exit 0, got $rc: $out" >&2
    failures=1
  else
    echo "ok: $label (exit 0)"
  fi
}

expect_fail() { # label expected_message_substring command...
  local label="$1" want="$2"; shift 2
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL: $label expected failure, got exit 0" >&2
    failures=1
  elif [[ "$out" != *"$want"* ]]; then
    echo "FAIL: $label failed for the wrong reason (want '*${want}*'): $out" >&2
    failures=1
  else
    echo "ok: $label (exit $rc, reason matched)"
  fi
}

state() { env STATE_FILE="$FIX/$1/STATE.md" bash tests/harness/check-state.sh; }
template_state() { env AGENT_ARTIFACTS_DIR="$FIX/$1/agent" STATE_FILE="$FIX/$1/STATE.md" bash tests/harness/check-state.sh; }
contracts() { env CONTRACTS_GLOB="$FIX/$1/*.md" bash tests/harness/check-contracts.sh; }

# --- Escalation transitions (§6–8): escape route из любого non-terminal ---
expect_pass "valid-init-halted"                 state valid-init-halted
expect_pass "valid-init-waiting-human"          state valid-init-waiting-human
expect_fail "invalid-waiting-human-self-loop"   "illegal transition: WAITING_HUMAN -> WAITING_HUMAN" state invalid-waiting-human-self-loop

# --- Terminal state: COMPLETED (REQ-HARNESS-018) ---
expect_pass "valid-completed-approved"                 state valid-completed-approved
expect_pass "valid-completed-approved-with-changes"    state valid-completed-approved-with-changes
expect_fail "invalid-state-verdict"                    "COMPLETED with verdict" state invalid-state-verdict
expect_fail "invalid-completed-rejected"               "COMPLETED with verdict" state invalid-completed-rejected

# --- Verdict routing REVIEW_READY (REQ-HARNESS-019/020) ---
expect_pass "valid-changes-required"                   state valid-changes-required
expect_fail "invalid-transition"                       "requires verdict CHANGES_REQUIRED" state invalid-transition
expect_pass "valid-architecture-rejected"              state valid-architecture-rejected
expect_fail "invalid-architecture-transition"          "must be null or REJECTED" state invalid-architecture-transition

# --- WAITING_HUMAN (REQ-HARNESS-026/027) ---
expect_fail "invalid-waiting-human"                    "suspended state is 'null'" state invalid-waiting-human
expect_fail "invalid-waiting-human-no-q"               "blocking question is 'null'" state invalid-waiting-human-no-q
expect_fail "invalid-waiting-human-unknown-q"          "references unknown Q-999" state invalid-waiting-human-unknown-q

# --- HALTED (REQ-HARNESS-021/028 + связка reason↔counters) ---
expect_fail "invalid-halted"                           "not a valid halt_reason" state invalid-halted
expect_fail "invalid-halted-no-reason"                 "not a valid halt_reason" state invalid-halted-no-reason
expect_fail "invalid-halted-no-evidence"               "halt evidence is null" state invalid-halted-no-evidence
expect_fail "invalid-halted-limit-mismatch"            "does not exceed limit" state invalid-halted-limit-mismatch
expect_pass "valid-halted-iteration-limit"             state valid-halted-iteration-limit

# --- INIT taint (§36 / REQ-HARNESS-025) ---
expect_fail "invalid-init-historical"                  "historical workflow evidence" state invalid-init-historical
expect_fail "invalid-init-commit"                      "historical workflow evidence" state invalid-init-commit

# --- Template mode (REQ-HARNESS-025) ---
expect_pass "valid-template-init"                      template_state valid-template-init
expect_fail "invalid-template-completed"               "template mode declared but State" template_state invalid-template-completed
expect_fail "invalid-template-contaminated"            "must not live in the active workflow directory" template_state invalid-template-contaminated

# --- Contracts (REQ-HARNESS-014/015) ---
expect_fail "duplicate-id"                             "duplicate global identifier" contracts duplicate-id
expect_fail "dangling-reference"                       "dangling identifier" contracts dangling-reference
expect_pass "valid-contracts"                          contracts valid-contracts

if [[ "$failures" -eq 0 ]]; then
  echo "PASS: all fixture tests behave as expected"
fi
exit "$failures"

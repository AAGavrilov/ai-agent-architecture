#!/usr/bin/env bash
# Проверяет docs/agent/STATE.md:
#  - state и verdict валидны (по .agents/STATE_MACHINE.md);
#  - счётчики — целые числа в пределах лимитов (REQ-HARNESS-015/016);
#  - для текущего state есть обязательные артефакты и Git evidence (REQ-HARNESS-017);
#  - последний transition легален (REQ-HARNESS-012).
# Источники: Git, файловая система, разбор Markdown. Без LLM.
#
# Использование: check-state.sh [путь-к-STATE.md]  (или env STATE_FILE=...)
set -euo pipefail

cd "$(dirname "$0")/../.."
STATE_FILE="${STATE_FILE:-${1:-docs/agent/STATE.md}}"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$STATE_FILE" ]] || fail "STATE file not found: $STATE_FILE"

field() {
  grep -m1 -E "^- $1: " "$STATE_FILE" | sed -E "s/^- $1: //" || true
}

is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }

commit_exists() { git cat-file -e "$1^{commit}" 2>/dev/null; }

VALID_STATES="INIT ARCHITECTURE_PENDING ARCHITECTURE_READY IMPLEMENTATION_PENDING IMPLEMENTATION_READY REVIEW_PENDING REVIEW_READY WAITING_HUMAN COMPLETED HALTED"
VALID_VERDICTS="APPROVED APPROVED_WITH_CHANGES CHANGES_REQUIRED REJECTED"
HALT_REASONS="ITERATION_LIMIT ARCHITECTURE_REVISION_LIMIT NO_PROGRESS ILLEGAL_TRANSITION MISSING_ARTIFACT MISSING_COMMIT CONTRACT_VIOLATION UNRECOVERABLE_ERROR"

MAX_IMPL_ITERATIONS=3
MAX_ARCH_REVISIONS=3
MAX_NO_PROGRESS=2

STATE="$(field 'State')"
CYCLE="$(field 'Cycle')"
ARCH_REV="$(field 'Architecture revision')"
IMPL_ITER="$(field 'Implementation iteration')"
REVIEW_ITER="$(field 'Review iteration')"
NOPROGRESS="$(field 'No-progress count')"
ARCH_COMMIT="$(field 'Architecture commit')"
PREV_IMPL_COMMIT="$(field 'Previous implementation commit')"
CUR_IMPL_COMMIT="$(field 'Current implementation commit')"
REVIEW_COMMIT="$(field 'Review commit')"
VERDICT="$(field 'Verdict')"
SUSPENDED="$(field 'Suspended state')"
BLOCKING_Q="$(field 'Blocking question')"
FROM="$(field 'From')"
TO="$(field 'To')"
REASON="$(field 'Reason')"

# --- Базовая валидность полей ---

[[ -n "$STATE" ]] || fail "State is missing"
grep -qw "$STATE" <<<"$VALID_STATES" || fail "unknown state: '$STATE'"

for c in "$CYCLE" "$ARCH_REV" "$IMPL_ITER" "$REVIEW_ITER" "$NOPROGRESS"; do
  is_int "$c" || fail "counter is not a non-negative integer: '$c'"
done

[[ -z "$VERDICT" || "$VERDICT" == "null" || "$VERDICT" == "none" ]] && VERDICT="null"
[[ "$VERDICT" == "null" ]] || grep -qw "$VERDICT" <<<"$VALID_VERDICTS" || fail "unknown verdict: '$VERDICT'"

null_if() { [[ "$1" == "null" || "$1" == "none" || -z "$1" ]] && echo null || echo "$1"; }
ARCH_COMMIT="$(null_if "$ARCH_COMMIT")"
PREV_IMPL_COMMIT="$(null_if "$PREV_IMPL_COMMIT")"
CUR_IMPL_COMMIT="$(null_if "$CUR_IMPL_COMMIT")"
REVIEW_COMMIT="$(null_if "$REVIEW_COMMIT")"
SUSPENDED="$(null_if "$SUSPENDED")"
BLOCKING_Q="$(null_if "$BLOCKING_Q")"
FROM="$(null_if "$FROM")"

# --- Git evidence для не-null коммитов ---

for pair in "Architecture commit:$ARCH_COMMIT" "Previous implementation commit:$PREV_IMPL_COMMIT" "Current implementation commit:$CUR_IMPL_COMMIT" "Review commit:$REVIEW_COMMIT"; do
  label="${pair%%:*}"; sha="${pair#*:}"
  [[ "$sha" == "null" ]] && continue
  commit_exists "$sha" || fail "$label '$sha' does not resolve to a commit"
done

# --- Обязательные артефакты по состоянию (§43) ---

require_commit() { # state-list label sha
  local states="$1" label="$2" sha="$3"
  if grep -qw "$STATE" <<<"$states"; then
    [[ "$sha" != "null" ]] || fail "STATE=$STATE but $label is null"
  fi
}

require_commit "ARCHITECTURE_READY IMPLEMENTATION_PENDING IMPLEMENTATION_READY REVIEW_PENDING REVIEW_READY COMPLETED HALTED" "Architecture commit" "$ARCH_COMMIT"
require_commit "IMPLEMENTATION_READY REVIEW_PENDING REVIEW_READY COMPLETED HALTED" "Current implementation commit" "$CUR_IMPL_COMMIT"
require_commit "REVIEW_READY COMPLETED HALTED" "Review commit" "$REVIEW_COMMIT"

if [[ "$STATE" == "COMPLETED" ]]; then
  grep -qw "$VERDICT" <<<"APPROVED APPROVED_WITH_CHANGES" || fail "STATE=COMPLETED but verdict is '$VERDICT'"
fi
if grep -qw "$STATE" <<<"REVIEW_READY COMPLETED"; then
  [[ "$VERDICT" != "null" ]] || fail "STATE=$STATE but Verdict is null"
fi

if [[ "$STATE" == "WAITING_HUMAN" ]]; then
  grep -qw "$SUSPENDED" <<<"$VALID_STATES" || fail "WAITING_HUMAN but suspended state is '$SUSPENDED'"
  [[ "$BLOCKING_Q" =~ ^Q-[0-9]{3}$ ]] || fail "WAITING_HUMAN but blocking question is '$BLOCKING_Q'"
fi

if [[ "$STATE" == "HALTED" ]]; then
  grep -qw "$REASON" <<<"$HALT_REASONS" || fail "HALTED but reason '$REASON' is not a valid halt_reason"
fi

# --- Согласованность счётчиков и коммитов ---

if [[ "$ARCH_COMMIT" != "null" ]]; then
  (( ARCH_REV >= 1 )) || fail "Architecture commit is set but Architecture revision is $ARCH_REV"
fi
if [[ "$CUR_IMPL_COMMIT" != "null" ]]; then
  (( IMPL_ITER >= 1 )) || fail "Current implementation commit is set but Implementation iteration is $IMPL_ITER"
fi
if [[ "$REVIEW_COMMIT" != "null" ]]; then
  (( REVIEW_ITER >= 1 )) || fail "Review commit is set but Review iteration is $REVIEW_ITER"
fi
if [[ "$ARCH_COMMIT" == "null" ]]; then
  (( ARCH_REV == 0 )) || fail "Architecture commit is null but Architecture revision is $ARCH_REV"
fi

# --- Легальность последнего transition (REQ-HARNESS-012) ---

[[ "$TO" == "$STATE" ]] || fail "Last transition To='$TO' but current State='$STATE'"

transition_allowed() { # from to
  local from="$1" to="$2"
  case "$from" in
    null) [[ "$to" == "INIT" ]] ;;
    INIT) [[ "$to" == "ARCHITECTURE_PENDING" ]] ;;
    ARCHITECTURE_PENDING) [[ "$to" == "ARCHITECTURE_READY" ]] ;;
    ARCHITECTURE_READY) [[ "$to" == "IMPLEMENTATION_PENDING" ]] ;;
    IMPLEMENTATION_PENDING) [[ "$to" == "IMPLEMENTATION_READY" ]] ;;
    IMPLEMENTATION_READY) [[ "$to" == "REVIEW_PENDING" ]] ;;
    REVIEW_PENDING) [[ "$to" == "REVIEW_READY" ]] ;;
    REVIEW_READY) [[ "$to" == "COMPLETED" || "$to" == "IMPLEMENTATION_PENDING" || "$to" == "ARCHITECTURE_PENDING" ]] ;;
    WAITING_HUMAN) [[ -n "$SUSPENDED" && "$SUSPENDED" != "null" && "$to" == "$SUSPENDED" ]] ;;
    COMPLETED|HALTED) return 1 ;; # terminal: no outgoing transitions
    *) [[ "$to" == "WAITING_HUMAN" || "$to" == "HALTED" ]] ;;
  esac
}

transition_allowed "$FROM" "$TO" || fail "illegal transition: $FROM -> $TO (state machine: .agents/STATE_MACHINE.md)"

# --- Deterministic enforcement лимитов (REQ-HARNESS-015/016) ---

(( IMPL_ITER > MAX_IMPL_ITERATIONS )) && { [[ "$STATE" == "HALTED" && "$REASON" == "ITERATION_LIMIT" ]] || fail "implementation_iteration $IMPL_ITER exceeds limit $MAX_IMPL_ITERATIONS but state is not HALTED/ITERATION_LIMIT"; }
(( ARCH_REV > MAX_ARCH_REVISIONS )) && { [[ "$STATE" == "HALTED" && "$REASON" == "ARCHITECTURE_REVISION_LIMIT" ]] || fail "architecture_revision $ARCH_REV exceeds limit $MAX_ARCH_REVISIONS but state is not HALTED/ARCHITECTURE_REVISION_LIMIT"; }
(( NOPROGRESS >= MAX_NO_PROGRESS )) && { [[ "$STATE" == "HALTED" && "$REASON" == "NO_PROGRESS" ]] || fail "no_progress_count $NOPROGRESS exceeds limit $MAX_NO_PROGRESS but state is not HALTED/NO_PROGRESS"; }

echo "PASS: $STATE_FILE (state=$STATE, from=$FROM, to=$TO)"

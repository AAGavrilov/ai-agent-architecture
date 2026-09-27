#!/usr/bin/env bash
# Проверяет docs/agent/STATE.md синтаксически И семантически:
#  - state и verdict валидны (по .agents/STATE_MACHINE.md);
#  - per-state invariants: INIT/ARCHITECTURE_*/IMPLEMENTATION_*/REVIEW_*/COMPLETED/HALTED/WAITING_HUMAN;
#  - semantic transition matrix и verdict routing (REQ-HARNESS-018/019/020);
#  - commit subjects и нумерация соответствуют counters (Iteration N == implementation_iteration);
#  - SHA резолвятся, лимиты enforced (REQ-HARNESS-016/017);
#  - HALTED: halt_reason из enum, suspended == last valid state (REQ-HARNESS-021);
#  - WAITING_HUMAN: suspended + blocking Q (существует в артефактах) + suspension reason (REQ-HARNESS-022).
# Источники: Git, файловая система, разбор Markdown. Без LLM.
#
# Использование: check-state.sh [путь-к-STATE.md]  (или env STATE_FILE=...)
set -euo pipefail

# shellcheck source=tests/harness/lib/commit-protocol.sh
. "$(dirname "$0")/lib/commit-protocol.sh"

cd "$(dirname "$0")/../.."
STATE_FILE="${STATE_FILE:-${1:-docs/agent/STATE.md}}"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$STATE_FILE" ]] || fail "STATE file not found: $STATE_FILE"

field() { grep -m1 -E "^- $1: " "$STATE_FILE" | sed -E "s/^- $1: //" || true; }
is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }
commit_exists() { git cat-file -e "$1^{commit}" 2>/dev/null; }
null_if() { [[ "$1" == "null" || "$1" == "none" || -z "$1" ]] && echo null || echo "$1"; }

# Известное отклонение: de-facto Architecture 1 коммит с неконформным сообщением
# (спека итерации 1 закоммичена до появления формата; история не переписывается).
EXEMPT_ARCH_FULL="df160b2c033278e1f58263b959e2957bd372038c"
is_exempt_arch() { [[ "$(git rev-parse "$1" 2>/dev/null)" == "$EXEMPT_ARCH_FULL" ]]; }

VALID_STATES="INIT ARCHITECTURE_PENDING ARCHITECTURE_READY IMPLEMENTATION_PENDING IMPLEMENTATION_READY REVIEW_PENDING REVIEW_READY WAITING_HUMAN COMPLETED HALTED"
VALID_VERDICTS="APPROVED APPROVED_WITH_CHANGES CHANGES_REQUIRED REJECTED"
HALT_REASONS="ITERATION_LIMIT ARCHITECTURE_REVISION_LIMIT NO_PROGRESS ILLEGAL_TRANSITION MISSING_ARTIFACT MISSING_COMMIT CONTRACT_VIOLATION UNRECOVERABLE_ERROR"

MAX_IMPL_ITERATIONS=3
MAX_ARCH_REVISIONS=3
MAX_NO_PROGRESS=2

STATE="$(null_if "$(field 'State')")"
CYCLE="$(field 'Cycle')"
ARCH_REV="$(field 'Architecture revision')"
IMPL_ITER="$(field 'Implementation iteration')"
REVIEW_ITER="$(field 'Review iteration')"
NOPROGRESS="$(field 'No-progress count')"
ARCH_COMMIT="$(null_if "$(field 'Architecture commit')")"
PREV_IMPL_COMMIT="$(null_if "$(field 'Previous implementation commit')")"
CUR_IMPL_COMMIT="$(null_if "$(field 'Current implementation commit')")"
REVIEW_COMMIT="$(null_if "$(field 'Review commit')")"
VERDICT="$(null_if "$(field 'Verdict')")"
SUSPENDED="$(null_if "$(field 'Suspended state')")"
BLOCKING_Q="$(null_if "$(field 'Blocking question')")"
SUSPENSION_REASON="$(null_if "$(field 'Suspension reason')")"
HALT_REASON="$(null_if "$(field 'Halt reason')")"
HALT_EVIDENCE="$(null_if "$(field 'Halt evidence')")"
FROM="$(null_if "$(field 'From')")"
TO="$(null_if "$(field 'To')")"
REASON="$(field 'Reason')"

# --- Базовая синтаксическая валидность ---

[[ "$STATE" != "null" ]] || fail "State is missing"
grep -qw "$STATE" <<<"$VALID_STATES" || fail "unknown state: '$STATE'"

for c in "$CYCLE" "$ARCH_REV" "$IMPL_ITER" "$REVIEW_ITER" "$NOPROGRESS"; do
  is_int "$c" || fail "counter is not a non-negative integer: '$c'"
done

[[ "$VERDICT" == "null" ]] || grep -qw "$VERDICT" <<<"$VALID_VERDICTS" || fail "unknown verdict: '$VERDICT'"

for pair in "Architecture commit:$ARCH_COMMIT" "Previous implementation commit:$PREV_IMPL_COMMIT" "Current implementation commit:$CUR_IMPL_COMMIT" "Review commit:$REVIEW_COMMIT"; do
  label="${pair%%:*}"; sha="${pair#*:}"
  [[ "$sha" == "null" ]] && continue
  commit_exists "$sha" || fail "$label '$sha' does not resolve to a commit"
done

[[ "$TO" == "$STATE" ]] || fail "Last transition To='$TO' but current State='$STATE'"

# --- Per-state invariants ---

if [[ "$STATE" == "INIT" ]]; then
  # §7: INIT не содержит следов исторического workflow
  for c in "$CYCLE" "$ARCH_REV" "$IMPL_ITER" "$REVIEW_ITER" "$NOPROGRESS"; do
    [[ "$c" == "0" ]] || fail "INIT state contains historical workflow evidence (counter=$c)"
  done
  for v in "$ARCH_COMMIT" "$PREV_IMPL_COMMIT" "$CUR_IMPL_COMMIT" "$REVIEW_COMMIT" "$VERDICT" "$SUSPENDED" "$BLOCKING_Q" "$SUSPENSION_REASON" "$HALT_REASON" "$HALT_EVIDENCE" "$FROM"; do
    [[ "$v" == "null" ]] || fail "INIT state contains historical workflow evidence ($v)"
  done
  [[ "$TO" == "INIT" ]] || fail "INIT state: last transition To must be INIT, got '$TO'"
fi

# --- Template mode (REQ-HARNESS-025): main = reusable framework template ---
# Маркер — декларация в шапке STATE.md; отдельного runtime-поля не вводится.
if grep -qi "reusable framework template" "$STATE_FILE"; then
  [[ "$STATE" == "INIT" ]] || fail "template mode declared but State is '$STATE' (REQ-HARNESS-025 requires a fresh instance: INIT)"
  agent_dir="${AGENT_ARTIFACTS_DIR:-docs/agent}"
  for artifact in IMPLEMENTATION.md REVIEW_REPORT.md; do
    [[ -f "$agent_dir/$artifact" ]] && fail "template mode: historical artifact $agent_dir/$artifact must not live in the active workflow directory (move to docs/examples/)"
  done
  true
fi

if [[ "$STATE" == "ARCHITECTURE_PENDING" ]]; then
  # §8
  (( ARCH_REV >= 1 )) || fail "ARCHITECTURE_PENDING but Architecture revision is $ARCH_REV"
  (( CYCLE >= 1 )) || fail "ARCHITECTURE_PENDING but Cycle is $CYCLE"
  [[ "$VERDICT" == "null" || "$VERDICT" == "REJECTED" ]] || fail "ARCHITECTURE_PENDING but Verdict is '$VERDICT' (must be null or REJECTED)"
  [[ "$FROM" != "REVIEW_READY" || "$VERDICT" == "REJECTED" ]] || fail "ARCHITECTURE_PENDING after REVIEW_READY requires verdict REJECTED, got '$VERDICT'"
fi

require_commit() { # states-list label sha
  if grep -qw "$STATE" <<<"$1"; then
    [[ "$3" != "null" ]] || fail "STATE=$STATE but $2 is null"
  fi
}

require_commit "ARCHITECTURE_READY IMPLEMENTATION_PENDING IMPLEMENTATION_READY REVIEW_PENDING REVIEW_READY COMPLETED" "Architecture commit" "$ARCH_COMMIT"
require_commit "IMPLEMENTATION_READY REVIEW_PENDING REVIEW_READY COMPLETED" "Current implementation commit" "$CUR_IMPL_COMMIT"
require_commit "REVIEW_READY COMPLETED" "Review commit" "$REVIEW_COMMIT"

if [[ "$STATE" == "ARCHITECTURE_READY" ]]; then
  # §9
  (( ARCH_REV >= 1 )) || fail "ARCHITECTURE_READY but Architecture revision is $ARCH_REV"
  (( CYCLE >= 1 )) || fail "ARCHITECTURE_READY but Cycle is $CYCLE"
fi

if [[ "$STATE" == "IMPLEMENTATION_PENDING" ]]; then
  # §10
  (( ARCH_REV >= 1 )) || fail "IMPLEMENTATION_PENDING but Architecture revision is $ARCH_REV"
  (( CYCLE >= 1 )) || fail "IMPLEMENTATION_PENDING but Cycle is $CYCLE"
  (( IMPL_ITER >= 1 )) || fail "IMPLEMENTATION_PENDING but Implementation iteration is $IMPL_ITER"
  if [[ "$FROM" == "REVIEW_READY" ]]; then
    [[ "$VERDICT" == "CHANGES_REQUIRED" ]] || fail "IMPLEMENTATION_PENDING after REVIEW_READY requires verdict CHANGES_REQUIRED, got '$VERDICT'"
  fi
  if [[ "$FROM" == "ARCHITECTURE_READY" ]]; then
    [[ "$VERDICT" == "null" ]] || fail "IMPLEMENTATION_PENDING after ARCHITECTURE_READY requires verdict null, got '$VERDICT'"
  fi
fi

if [[ "$STATE" == "IMPLEMENTATION_READY" ]]; then
  # §11
  (( IMPL_ITER >= 1 )) || fail "IMPLEMENTATION_READY but Implementation iteration is $IMPL_ITER"
fi

if [[ "$STATE" == "REVIEW_PENDING" ]]; then
  # §12
  [[ "$REVIEW_COMMIT" == "null" ]] || fail "REVIEW_PENDING but Review commit is '$REVIEW_COMMIT'"
  [[ "$VERDICT" == "null" ]] || fail "REVIEW_PENDING but Verdict is '$VERDICT' (must be null until review exists)"
fi

if [[ "$STATE" == "REVIEW_READY" ]]; then
  # §13
  grep -qw "$VERDICT" <<<"$VALID_VERDICTS" || fail "REVIEW_READY but Verdict is '$VERDICT'"
fi

if [[ "$STATE" == "COMPLETED" ]]; then
  # §16: ложный COMPLETED запрещён
  grep -qw "$VERDICT" <<<"APPROVED APPROVED_WITH_CHANGES" || fail "COMPLETED with verdict '$VERDICT' (only APPROVED or APPROVED_WITH_CHANGES permit completion)"
fi

if [[ "$STATE" == "HALTED" ]]; then
  # §19–21: HALTED не требует Architecture commit; хранит последнее валидное состояние
  grep -qw "$HALT_REASON" <<<"$HALT_REASONS" || fail "HALTED but halt reason '$HALT_REASON' is not a valid halt_reason"
  [[ "$SUSPENDED" != "null" ]] || fail "HALTED but suspended state (last valid state) is null"
  grep -qw "$SUSPENDED" <<<"$VALID_STATES" || fail "HALTED but suspended state '$SUSPENDED' is not a valid state"
  [[ "$FROM" == "$SUSPENDED" ]] || fail "HALTED: suspended state '$SUSPENDED' must equal last transition From '$FROM'"
  [[ "$HALT_EVIDENCE" != "null" ]] || fail "HALTED but halt evidence is null (REQ-HARNESS-028 requires evidence of the halt condition)"
  case "$HALT_REASON" in
    ITERATION_LIMIT)
      (( IMPL_ITER > MAX_IMPL_ITERATIONS )) || fail "HALTED/ITERATION_LIMIT but implementation_iteration $IMPL_ITER does not exceed limit $MAX_IMPL_ITERATIONS" ;;
    ARCHITECTURE_REVISION_LIMIT)
      (( ARCH_REV > MAX_ARCH_REVISIONS )) || fail "HALTED/ARCHITECTURE_REVISION_LIMIT but architecture_revision $ARCH_REV does not exceed limit $MAX_ARCH_REVISIONS" ;;
    NO_PROGRESS)
      (( NOPROGRESS >= MAX_NO_PROGRESS )) || fail "HALTED/NO_PROGRESS but no_progress_count $NOPROGRESS is below limit $MAX_NO_PROGRESS" ;;
  esac
fi

if [[ "$STATE" == "WAITING_HUMAN" ]]; then
  # §22–24
  grep -qw "$SUSPENDED" <<<"$VALID_STATES" || fail "WAITING_HUMAN but suspended state is '$SUSPENDED'"
  [[ "$BLOCKING_Q" =~ ^Q-[0-9]{3}$ ]] || fail "WAITING_HUMAN but blocking question is '$BLOCKING_Q'"
  [[ "$SUSPENSION_REASON" != "null" ]] || fail "WAITING_HUMAN but suspension reason is null"
  grep -rq --exclude='STATE.md' -e "$BLOCKING_Q" docs/agent/ \
    || fail "WAITING_HUMAN references unknown $BLOCKING_Q (not found in docs/agent artifacts)"
fi

# --- Transition relation (§6–8, §14–15): NORMAL + ESCALATION ---
# NORMAL — рабочие переходы; ESCALATION — escape route из любого non-terminal
# состояния в WAITING_HUMAN / HALTED (без self-loop и без выхода из terminal).

normal_transition_allowed() {
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
    WAITING_HUMAN) [[ "$SUSPENDED" != "null" && "$to" == "$SUSPENDED" ]] ;;
    *) return 1 ;; # terminal states and unknown sources have no normal transitions
  esac
}

escalation_transition_allowed() {
  local from="$1" to="$2"
  [[ "$from" != "COMPLETED" && "$from" != "HALTED" ]] || return 1 # terminal: no outgoing transitions
  [[ "$from" != "$to" ]] || return 1                              # no self-loop
  [[ "$to" == "WAITING_HUMAN" || "$to" == "HALTED" ]]
}

normal_transition_allowed "$FROM" "$TO" \
  || escalation_transition_allowed "$FROM" "$TO" \
  || fail "illegal transition: $FROM -> $TO (state machine: .agents/STATE_MACHINE.md)"

case "$FROM->$TO" in
  "REVIEW_READY->COMPLETED")
    grep -qw "$VERDICT" <<<"APPROVED APPROVED_WITH_CHANGES" || fail "REVIEW_READY -> COMPLETED requires verdict APPROVED or APPROVED_WITH_CHANGES, got '$VERDICT'"
    ;;
  "REVIEW_READY->IMPLEMENTATION_PENDING")
    [[ "$VERDICT" == "CHANGES_REQUIRED" ]] || fail "REVIEW_READY -> IMPLEMENTATION_PENDING requires CHANGES_REQUIRED, got '$VERDICT'"
    ;;
  "REVIEW_READY->ARCHITECTURE_PENDING")
    [[ "$VERDICT" == "REJECTED" ]] || fail "REVIEW_READY -> ARCHITECTURE_PENDING requires REJECTED, got '$VERDICT'"
    ;;
esac

# --- Commit subjects и нумерация (§17–18, §55) ---

if [[ "$ARCH_COMMIT" != "null" ]]; then
  if is_exempt_arch "$ARCH_COMMIT"; then
    (( ARCH_REV >= 1 )) || fail "Architecture commit set but Architecture revision is $ARCH_REV"
  else
    nums="$(commit_ref_nums "$ARCH_COMMIT" 'Architecture')"
    [[ -n "$nums" ]] || fail "Architecture commit $ARCH_COMMIT has non-conforming subject: '$(commit_subject "$ARCH_COMMIT")'"
    [[ "${nums% *}" == "$CYCLE" && "${nums#* }" == "$ARCH_REV" ]] \
      || fail "Architecture commit is 'Architecture ${nums% *}.${nums#* }' but expected 'Architecture $CYCLE.$ARCH_REV'"
  fi
fi

# Текущий implementation commit — последний implementation-артефакт, не HEAD (REQ-HARNESS-029).
# Счётчики цикловые: если коммит принадлежит текущему циклу — применяются соотношения
# с implementation_iteration; если прошлому (например, после START нового цикла) —
# коммит считается историей, и счётчики текущего цикла его не описывают.
# Состояния, где текущий цикл уже имеет implementation/review артефакт:
# commit-поля обязаны ссылаться на артефакт текущего цикла (а не прошлого).
requires_current_cycle_impl() { grep -qw "$STATE" <<<"IMPLEMENTATION_READY REVIEW_PENDING REVIEW_READY COMPLETED"; }
requires_current_cycle_review() { grep -qw "$STATE" <<<"REVIEW_READY COMPLETED"; }

if [[ "$CUR_IMPL_COMMIT" != "null" ]]; then
  nums="$(commit_ref_nums "$CUR_IMPL_COMMIT" 'Iteration')"
  [[ -n "$nums" ]] || fail "Current implementation commit $CUR_IMPL_COMMIT has non-conforming subject: '$(commit_subject "$CUR_IMPL_COMMIT")'"
  c="${nums% *}"; n="${nums#* }"
  if requires_current_cycle_impl; then
    (( c == CYCLE )) || fail "Current implementation commit belongs to cycle $c but STATE=$STATE requires the current cycle ($CYCLE) artifact"
  else
    (( c <= CYCLE )) || fail "Current implementation commit belongs to cycle $c but current cycle is $CYCLE"
  fi
  if (( c == CYCLE )); then
    if [[ "$STATE" == "IMPLEMENTATION_READY" ]]; then
      [[ "$n" == "$IMPL_ITER" ]] || fail "Current implementation commit is 'Iteration $c.$n' but implementation_iteration is $IMPL_ITER"
    else
      (( n <= IMPL_ITER )) || fail "Current implementation commit is 'Iteration $c.$n' but implementation_iteration is only $IMPL_ITER"
    fi
  fi
fi

if [[ "$REVIEW_COMMIT" != "null" ]]; then
  nums="$(commit_ref_nums "$REVIEW_COMMIT" 'Review')"
  [[ -n "$nums" ]] || fail "Review commit $REVIEW_COMMIT has non-conforming subject: '$(commit_subject "$REVIEW_COMMIT")'"
  c="${nums% *}"; n="${nums#* }"
  if requires_current_cycle_review; then
    (( c == CYCLE )) || fail "Review commit belongs to cycle $c but STATE=$STATE requires the current cycle ($CYCLE) artifact"
  else
    (( c <= CYCLE )) || fail "Review commit belongs to cycle $c but current cycle is $CYCLE"
  fi
  if (( c == CYCLE )); then
    if [[ "$STATE" == "REVIEW_READY" ]]; then
      [[ "$n" == "$REVIEW_ITER" ]] || fail "Review commit is 'Review $c.$n' but review_iteration is $REVIEW_ITER"
    else
      (( n <= REVIEW_ITER )) || fail "Review commit is 'Review $c.$n' but review_iteration is only $REVIEW_ITER"
    fi
  fi
fi

if [[ "$PREV_IMPL_COMMIT" != "null" ]]; then
  nums="$(commit_ref_nums "$PREV_IMPL_COMMIT" 'Iteration')"
  [[ -n "$nums" ]] || fail "Previous implementation commit $PREV_IMPL_COMMIT has non-conforming subject: '$(commit_subject "$PREV_IMPL_COMMIT")'"
  c="${nums% *}"; n="${nums#* }"
  (( c <= CYCLE )) || fail "Previous implementation commit belongs to cycle $c but current cycle is $CYCLE"
  if (( c == CYCLE )); then
    (( IMPL_ITER >= 2 )) || fail "Previous implementation commit belongs to the current cycle but Implementation iteration is $IMPL_ITER"
    if [[ "$STATE" == "IMPLEMENTATION_READY" ]]; then
      (( n == IMPL_ITER - 1 )) || fail "Previous implementation commit is 'Iteration $c.$n' but expected 'Iteration $CYCLE.$((IMPL_ITER - 1))'"
    else
      (( n < IMPL_ITER )) || fail "Previous implementation commit is 'Iteration $c.$n' but implementation_iteration is $IMPL_ITER"
    fi
  fi
fi

# --- Согласованность счётчиков и коммитов ---
# Соотношение "коммит ⇒ счётчик ≥ 1" действует только для коммитов текущего цикла:
# после старта нового цикла commit-поля ещё указывают на артефакты прошлого.

cur_impl_cycle="${CUR_IMPL_COMMIT:+$(commit_ref_nums "$CUR_IMPL_COMMIT" 'Iteration')}"
review_cycle="${REVIEW_COMMIT:+$(commit_ref_nums "$REVIEW_COMMIT" 'Review')}"
if [[ "$CUR_IMPL_COMMIT" != "null" && "${cur_impl_cycle% *}" == "$CYCLE" ]]; then
  (( IMPL_ITER >= 1 )) || fail "Current implementation commit is in cycle $CYCLE but Implementation iteration is $IMPL_ITER"
fi
if [[ "$REVIEW_COMMIT" != "null" && "${review_cycle% *}" == "$CYCLE" ]]; then
  (( REVIEW_ITER >= 1 )) || fail "Review commit is in cycle $CYCLE but Review iteration is $REVIEW_ITER"
fi
if [[ "$ARCH_COMMIT" == "null" && "$STATE" != "HALTED" ]]; then (( ARCH_REV == 0 )) || fail "Architecture commit is null but Architecture revision is $ARCH_REV"; fi

# --- Deterministic enforcement лимитов (REQ-HARNESS-016/017) ---
# NO_PROGRESS semantics канонически определены в .agents/ORCHESTRATOR.md (раздел 10);
# здесь — только numeric enforcement (no_progress_count >= 2 → HALTED/NO_PROGRESS).

(( IMPL_ITER > MAX_IMPL_ITERATIONS )) && { [[ "$STATE" == "HALTED" && "$HALT_REASON" == "ITERATION_LIMIT" ]] || fail "implementation_iteration $IMPL_ITER exceeds limit $MAX_IMPL_ITERATIONS but state is not HALTED/ITERATION_LIMIT"; }
(( ARCH_REV > MAX_ARCH_REVISIONS )) && { [[ "$STATE" == "HALTED" && "$HALT_REASON" == "ARCHITECTURE_REVISION_LIMIT" ]] || fail "architecture_revision $ARCH_REV exceeds limit $MAX_ARCH_REVISIONS but state is not HALTED/ARCHITECTURE_REVISION_LIMIT"; }
(( NOPROGRESS >= MAX_NO_PROGRESS )) && { [[ "$STATE" == "HALTED" && "$HALT_REASON" == "NO_PROGRESS" ]] || fail "no_progress_count $NOPROGRESS exceeds limit $MAX_NO_PROGRESS but state is not HALTED/NO_PROGRESS"; }

echo "PASS: $STATE_FILE (state=$STATE, from=$FROM, to=$TO, verdict=$VERDICT)"

#!/usr/bin/env bash
# Проверяет git-протокол артефактных коммитов:
#  - форматы 'Architecture N:' / 'Iteration N:' / 'Review N:';
#  - непрерывность нумерации каждого типа (N: 1..max без пропусков и дублей);
#  - для Iteration N>1 существование Iteration N-1 как baseline;
#  - соответствие счётчикам STATE.md (если счётчик > 0, коммитов этого типа >= счётчику);
#  - SHA из STATE.md резолвятся в коммиты.
# Источники: Git, разбор STATE.md. Без LLM.
set -euo pipefail

cd "$(dirname "$0")/../.."
STATE_FILE="${STATE_FILE:-${1:-docs/agent/STATE.md}}"

fail() { echo "FAIL: $*" >&2; exit 1; }

count() { [[ -z "$1" ]] && echo 0 || wc -l <<<"$1" | tr -d ' '; }

SUBJECTS="$(git log --format=%s)"

check_series() { # type: извлекает номера, проверяет непрерывность и уникальность
  local type="$1"
  local nums
  nums="$(grep -E "^${type} [0-9]+:" <<<"$SUBJECTS" | sed -E "s/^${type} ([0-9]+):.*/\1/" | sort -n)"
  [[ -z "$nums" ]] && return 0
  echo "$nums"
  local dups max expected
  dups="$(uniq -d <<<"$nums" | grep -v '^$' || true)"
  [[ -z "$dups" ]] || fail "duplicate ${type} commit numbers: $(tr '\n' ' ' <<<"$dups")"
  max="$(tail -1 <<<"$nums")"
  expected="$(seq 1 "$max" | tr '\n' ' ')"
  [[ "$(tr '\n' ' ' <<<"$nums")" == "$expected " || "$(tr '\n' ' ' <<<"$nums")" == "$expected" ]] \
    || fail "${type} commits are not numbered continuously 1..${max}: $(tr '\n' ' ' <<<"$nums")"
}

arch_nums="$(check_series "Architecture")"
impl_nums="$(check_series "Iteration")"
review_nums="$(check_series "Review")"

# baseline: для Iteration N>1 должен существовать Iteration N-1 (гарантируется непрерывностью,
# но проверяем явно для ясности отказа)
if [[ -n "$impl_nums" ]]; then
  n="$(wc -l <<<"$impl_nums")"
  for i in $(seq 2 "$n"); do
    grep -qx "$((i - 1))" <<<"$impl_nums" || fail "Iteration $i has no Iteration $((i - 1)) baseline"
  done
fi

# соответствие счётчикам STATE.md
if [[ -f "$STATE_FILE" ]]; then
  cnt() { grep -m1 -E "^- $1: " "$STATE_FILE" | sed -E "s/^- $1: //"; }
  arch_rev="$(cnt 'Architecture revision')"
  impl_iter="$(cnt 'Implementation iteration')"
  review_iter="$(cnt 'Review iteration')"
  [[ "$arch_rev" =~ ^[0-9]+$ ]] || fail "STATE.md: Architecture revision is not an integer"
  [[ "$impl_iter" =~ ^[0-9]+$ ]] || fail "STATE.md: Implementation iteration is not an integer"
  [[ "$review_iter" =~ ^[0-9]+$ ]] || fail "STATE.md: Review iteration is not an integer"
  (( arch_rev == 0 )) || (( $(count "$arch_nums") >= arch_rev )) || fail "STATE.md claims Architecture revision $arch_rev but only $(count "$arch_nums") Architecture commits exist"
  (( impl_iter == 0 )) || (( $(count "$impl_nums") >= impl_iter )) || fail "STATE.md claims Implementation iteration $impl_iter but only $(count "$impl_nums") Iteration commits exist"
  (( review_iter == 0 )) || (( $(count "$review_nums") >= review_iter )) || fail "STATE.md claims Review iteration $review_iter but only $(count "$review_nums") Review commits exist"

  # SHA из STATE.md резолвятся
  for label in 'Architecture commit' 'Previous implementation commit' 'Current implementation commit' 'Review commit'; do
    sha="$(cnt "$label")"
    [[ "$sha" == "null" || -z "$sha" ]] && continue
    git cat-file -e "$sha^{commit}" 2>/dev/null || fail "STATE.md $label '$sha' does not resolve to a commit"
  done
fi

echo "PASS: git protocol (Architecture commits: $(count "$arch_nums"), Iteration commits: $(count "$impl_nums"), Review commits: $(count "$review_nums"))"

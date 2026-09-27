#!/usr/bin/env bash
# Проверяет git-протокол артефактных коммитов (REQ-HARNESS-006/007/008/009/032).
#
# Нумерация цикловая: '<Type> <cycle>.<counter>:'. Legacy-форма без цикла
# ('<Type> <N>:') нормализуется в cycle 1 — история не переписывается.
#
# Проверяет:
#  - непрерывность нумерации внутри каждого цикла (1..max без пропусков и дублей);
#  - baseline: Iteration <c>.<n> при n>1 требует существования Iteration <c>.<n-1>;
#  - счётчики STATE.md для текущего цикла не превышают число коммитов;
#  - SHA из STATE.md резолвятся в коммиты.
#
# Env: STATE_FILE (default docs/agent/STATE.md), GIT_REPO_ROOT (default repo root; для fixtures).
set -euo pipefail

ROOT="${GIT_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$ROOT"
STATE_FILE="${STATE_FILE:-docs/agent/STATE.md}"

fail() { echo "FAIL: $*" >&2; exit 1; }
count_rows() { [[ -z "$1" ]] && echo 0 || printf '%s\n' "$1" | grep -c . || true; }
in_cycle() { printf '%s\n' "$1" | awk -v c="$2" 'NF==2 && $1==c {print $2}' | sort -n; }

SUBJECTS="$(git log --format=%s)"

series() { # type -> строки "cycle counter"
  grep -E "^$1 [0-9]+(\.[0-9]+)?:" <<<"$SUBJECTS" \
    | sed -E "s/^$1 ([0-9]+)\.([0-9]+):.*/\1 \2/; s/^$1 ([0-9]+):.*/1 \1/" \
    | sort -n -k1,1 -k2,2 || true
}

validate_series() { # type rows
  local type="$1" rows="$2" cyc max expected actual dups
  [[ -z "$rows" ]] && return 0
  dups="$(printf '%s\n' "$rows" | uniq -d || true)"
  [[ -z "$dups" ]] || fail "duplicate ${type} numbers (cycle.counter): $(tr '\n' ' ' <<<"$dups")"
  for cyc in $(printf '%s\n' "$rows" | awk 'NF==2{print $1}' | sort -nu); do
    actual="$(in_cycle "$rows" "$cyc" | tr '\n' ' ')"
    max="$(in_cycle "$rows" "$cyc" | tail -1)"
    expected="$(seq 1 "$max" | tr '\n' ' ')"
    [[ "$actual" == "$expected" || "$actual" == "$expected " ]] \
      || fail "${type} in cycle ${cyc} is not numbered continuously 1..${max}: $actual"
  done
}

arch_rows="$(series "Architecture")"
# Известное отклонение: de-facto Architecture 1 коммит с неконформным сообщением
# (спека итерации 1 закоммичена до появления формата; история не переписывается).
# Считаем его Architecture 1.1; при появлении настоящего 'Architecture 1.1:' коммита
# серия даст дубликат и проверка упадёт — явный сигнал устранить неоднозначность.
EXEMPT_ARCH_FULL="df160b2c033278e1f58263b959e2957bd372038c"
if git cat-file -e "$EXEMPT_ARCH_FULL^{commit}" 2>/dev/null; then
  arch_rows="$( { [[ -n "$arch_rows" ]] && printf '%s\n' "$arch_rows"; echo "1 1"; } | sort -n -k1,1 -k2,2 )"
fi
impl_rows="$(series "Iteration")"
review_rows="$(series "Review")"

validate_series "Architecture" "$arch_rows"
validate_series "Iteration" "$impl_rows"
validate_series "Review" "$review_rows"

# baseline внутри цикла: Iteration <c>.<n> при n>1 требует Iteration <c>.<n-1>
if [[ -n "$impl_rows" ]]; then
  while read -r cyc n; do
    [[ -z "${cyc:-}" || -z "${n:-}" ]] && continue
    if (( n > 1 )); then
      printf '%s\n' "$impl_rows" | grep -qx "$cyc $((n - 1))" \
        || fail "Iteration $cyc.$n has no Iteration $cyc.$((n - 1)) baseline"
    fi
  done <<<"$impl_rows"
fi

# соответствие счётчикам STATE.md (для текущего цикла) + резолвинг SHA
if [[ -f "$STATE_FILE" ]]; then
  cnt() { grep -m1 -E "^- $1: " "$STATE_FILE" | sed -E "s/^- $1: //" || true; }
  cycle="$(cnt 'Cycle')"
  arch_rev="$(cnt 'Architecture revision')"
  impl_iter="$(cnt 'Implementation iteration')"
  review_iter="$(cnt 'Review iteration')"
  [[ "$cycle" =~ ^[0-9]+$ ]] || fail "STATE.md: Cycle is not an integer"
  [[ "$arch_rev" =~ ^[0-9]+$ ]] || fail "STATE.md: Architecture revision is not an integer"
  [[ "$impl_iter" =~ ^[0-9]+$ ]] || fail "STATE.md: Implementation iteration is not an integer"
  [[ "$review_iter" =~ ^[0-9]+$ ]] || fail "STATE.md: Review iteration is not an integer"

  if (( cycle > 0 )); then
    [[ "$arch_rev" == 0 ]]   || (( $(in_cycle "$arch_rows" "$cycle" | grep -c . || true) >= arch_rev )) \
      || fail "STATE.md claims Architecture revision $arch_rev in cycle $cycle but only $(in_cycle "$arch_rows" "$cycle" | grep -c . || true) such commits exist"
    [[ "$impl_iter" == 0 ]]  || (( $(in_cycle "$impl_rows" "$cycle" | grep -c . || true) >= impl_iter )) \
      || fail "STATE.md claims Implementation iteration $impl_iter in cycle $cycle but only $(in_cycle "$impl_rows" "$cycle" | grep -c . || true) such commits exist"
    [[ "$review_iter" == 0 ]] || (( $(in_cycle "$review_rows" "$cycle" | grep -c . || true) >= review_iter )) \
      || fail "STATE.md claims Review iteration $review_iter in cycle $cycle but only $(in_cycle "$review_rows" "$cycle" | grep -c . || true) such commits exist"
  fi

  for label in 'Architecture commit' 'Previous implementation commit' 'Current implementation commit' 'Review commit'; do
    sha="$(cnt "$label")"
    [[ "$sha" == "null" || -z "$sha" ]] && continue
    git cat-file -e "$sha^{commit}" 2>/dev/null || fail "STATE.md $label '$sha' does not resolve to a commit"
  done
fi

echo "PASS: git protocol (cycle-scoped; Architecture: $(count_rows "$arch_rows"), Iteration: $(count_rows "$impl_rows"), Review: $(count_rows "$review_rows") commits)"

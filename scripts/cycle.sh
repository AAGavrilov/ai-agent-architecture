#!/usr/bin/env bash
# cycle.sh — навигатор по протоколу: где мы сейчас и что разрешено.
#
# Принцип: скрипт НЕ переписывает правила, а читает их из источников истины:
#   - текущее состояние и счётчики  → docs/agent/STATE.md
#   - требуемый STATE для роли      → STATE GATE соответствующего промта
#   - нормальные переходы           → .agents/STATE_MACHINE.md
# Если источник изменился и не парсится, скрипт падает с явной ошибкой,
# а не показывает устаревшую подсказку.
#
# Использование:
#   bash scripts/cycle.sh                # status (по умолчанию)
#   bash scripts/cycle.sh status
#   bash scripts/cycle.sh architect|code|review
#   bash scripts/cycle.sh check          # полный harness
set -euo pipefail

cd "$(dirname "$0")/.."
STATE_FILE="${STATE_FILE:-docs/agent/STATE.md}"
MACHINE=".agents/STATE_MACHINE.md"

die() { echo "cycle.sh: $*" >&2; exit 1; }

field() { grep -m1 -E "^- $1: " "$STATE_FILE" 2>/dev/null | sed -E "s/^- $1: //" || true; }

[[ -f "$STATE_FILE" ]] || die "не найден $STATE_FILE"
[[ -f "$MACHINE" ]] || die "не найден $MACHINE"

STATE="$(field 'State')"
CYCLE="$(field 'Cycle')"
ARCH_REV="$(field 'Architecture revision')"
IMPL_ITER="$(field 'Implementation iteration')"
REVIEW_ITER="$(field 'Review iteration')"
NOPROGRESS="$(field 'No-progress count')"
VERDICT="$(field 'Verdict')"
[[ -n "$STATE" ]] || die "в $STATE_FILE нет поля 'State'"

# --- нормальные переходы из canonical spec (единственный источник) ---
GRAPH="$(
  awk '
    /^### Normal transitions/ { section = "normal"; next }
    /^### / { if (section == "normal") section = "" }
    section == "normal" && /^[A-Z_]+$/ { from = $0 }
    section == "normal" && /^  -> [A-Z_]+/ { sub(/^  -> /, ""); print from, $0 }
  ' "$MACHINE"
)"
[[ -n "$GRAPH" ]] || die "не удалось разобрать normal transitions из $MACHINE (изменился формат?)"

find_path() { # from to -> "A → B → C" (пусто, если нормального пути нет)
  local from="$1" to="$2" cur dst node path
  declare -A parent=()
  local queue=("$from") head=0
  while (( head < ${#queue[@]} )); do
    cur="${queue[$head]}"; head=$((head + 1))
    while read -r src dst; do
      [[ -n "${src:-}" && "$src" == "$cur" ]] || continue
      [[ -z "${parent[$dst]:-}" && "$dst" != "$from" ]] || continue
      parent[$dst]="$cur"
      if [[ "$dst" == "$to" ]]; then
        path="$dst"; node="$dst"
        while [[ "$node" != "$from" ]]; do node="${parent[$node]}"; path="$node → $path"; done
        echo "$path"; return 0
      fi
      queue+=("$dst")
    done <<<"$GRAPH"
  done
  return 1
}

gate_for() { # role -> требуемое состояние из STATE GATE промта
  local prompt="$1" gate
  gate="$(grep -oE 'STATE == [A-Z_]+' "$prompt" | head -1 | sed -E 's/STATE == //')"
  [[ -n "$gate" ]] || die "в $prompt не найден 'STATE == <STATE>' (STATE GATE изменился?)"
  echo "$gate"
}

limits_status() {
  local impl="$1" arch="$2" noprog="$3"
  printf '  implementation-итерации: %s/3%s\n' "$impl" "$( (( impl >= 3 )) && echo '  ← предел' || true)"
  printf '  architecture-ревизии:    %s/3%s\n' "$arch" "$( (( arch >= 3 )) && echo '  ← предел' || true)"
  printf '  no-progress подряд:     %s/2%s\n' "$noprog" "$( (( noprog >= 1 )) && echo '  ← следующий NO_PROGRESS = HALTED' || true)"
}

next_commit() { # type counter -> строка формата
  local type="$1" counter="$2" next_cycle next_counter
  next_cycle="$CYCLE"; (( next_cycle == 0 )) && next_cycle=1
  next_counter=$((counter + 1))
  printf '%s %s.%s: <краткое описание>\n' "$type" "$next_cycle" "$next_counter"
}

show_status() {
  echo "WORKFLOW STATE"
  echo "  состояние:        $STATE"
  echo "  cycle:            $CYCLE"
  echo "  вершина истории:  $(git log -1 --format='%h %s' 2>/dev/null || echo '—')"
  echo "  verdict:          $VERDICT"
  echo "  коммиты в STATE:  arch=$(field 'Architecture commit') impl=$(field 'Current implementation commit') review=$(field 'Review commit')"
  echo "  лимиты (per cycle):"
  limits_status "$IMPL_ITER" "$ARCH_REV" "$NOPROGRESS"
  echo
  echo "Роль в текущем состоянии:"
  for pair in "architect:01-analysis.md" "code:02-implementation.md" "review:03-review.md"; do
    local role="${pair%%:*}" prompt=".agents/prompts/${pair#*:}" gate
    gate="$(gate_for "$prompt")"
    if [[ "$STATE" == "$gate" ]]; then
      echo "  $role: разрешена (STATE GATE: $gate)"
    else
      local path
      if path="$(find_path "$STATE" "$gate")"; then
        echo "  $role: запрещена — нужен переход: $path"
      else
        echo "  $role: запрещена (нужно $gate; нормального пути из $STATE нет — см. $MACHINE)"
      fi
    fi
  done
  echo
  echo "Перед push: bash tests/harness/check-all.sh (или git push — сработает pre-push hook)"
  echo "STATE.md не должен ссылаться на ещё не существующий SHA (ORCHESTRATOR §11)."
}

role_guidance() { # role prompt gate type counter
  local role="$1" prompt="$2" gate="$3" type="$4" counter="$5"
  if [[ "$STATE" != "$gate" ]]; then
    local path
    echo "Роль '$role' запрещена: STATE=$STATE, требуется $gate." >&2
    if path="$(find_path "$STATE" "$gate")"; then
      echo "Нужный переход: $path" >&2
    else
      echo "Нормального пути из $STATE в $gate нет — разберись по $MACHINE и ORCHESTRATOR §2." >&2
    fi
    exit 1
  fi
  echo "Роль:             $role"
  echo "Текущее состояние: $STATE (cycle $CYCLE)"
  echo "Промт роли:        $prompt"
  echo "Ожидаемый коммит:"
  echo "  $(next_commit "$type" "$counter")"
  echo "После коммита обнови $STATE_FILE и сделай state-коммит:"
  echo "  State <N>: <transition description>"
}

cmd="${1:-status}"

case "$cmd" in
  status) show_status ;;
  architect) role_guidance architect .agents/prompts/01-analysis.md "$(gate_for .agents/prompts/01-analysis.md)" Architecture "$ARCH_REV" ;;
  code)      role_guidance code      .agents/prompts/02-implementation.md "$(gate_for .agents/prompts/02-implementation.md)" Iteration "$IMPL_ITER" ;;
  review)    role_guidance review    .agents/prompts/03-review.md "$(gate_for .agents/prompts/03-review.md)" Review "$REVIEW_ITER" ;;
  check)     exec bash tests/harness/check-all.sh ;;
  *)         die "неизвестная команда '$cmd' (status|architect|code|review|check)" ;;
esac

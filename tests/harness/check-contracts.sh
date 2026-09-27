#!/usr/bin/env bash
# Глобальная проверка contract identifiers (REQ-HARNESS-014/015).
#
# Scope definitions/references:
#   docs/ (agent + architecture), .agents/*.md, .agents/adapters/*.md,
#   Memory.md, AGENTS.md, README.md
# Явные исключения (не сканируются):
#   .agents/prompts/ — канонические примеры форматов БЛОК 0.1 (шаблоны, не ID);
#   tests/harness/    — код валидаторов и fixtures.
#
# Definition patterns (синтаксические, владение по артефакту):
#   - bold:        **REQ-001**
#   - heading:     ### REQ-HARNESS-001
#   - table cell:  первая ячейка таблицы с заголовком 'ID' (PROJECT_SPEC/IMPLEMENTATION)
#                  или 'REV-ID' (только REVIEW_REPORT — REV-* определяет ревьюер).
# Проверяет:
#   - формат PREFIX-NNN (или REQ-HARNESS-NNN) вне code spans;
#   - глобальную уникальность definitions (дубликаты → FAIL);
#   - dangling references (REFERENCES - DEFINITIONS → FAIL, без молчаливых исключений).
# Источники: файловая система, разбор Markdown. Без LLM.
#
# Использование: check-contracts.sh [CONTRACTS_GLOB]  (env CONTRACTS_GLOB="dir/*.md")
set -euo pipefail

cd "$(dirname "$0")/../.."

PREFIXES='REQ|DEC|REV|BLK|BIMP|CONFLICT|Q|ASM'
ID_RE="(${PREFIXES})(-HARNESS)?-[0-9]{3}"
# Кандидат на malformed: после дефиса первая позиция — цифра (отсекает метки вида 'REV-ID').
BAD_RE="(${PREFIXES})(-HARNESS)?-[0-9][0-9A-Za-z]*"

failures=0
fail() { echo "FAIL: $*" >&2; failures=1; }

if [[ -n "${CONTRACTS_GLOB:-}" ]]; then
  scope_glob="$CONTRACTS_GLOB"
else
  scope_glob="docs/*/*.md docs/*/*/*.md .agents/*.md .agents/adapters/*.md Memory.md AGENTS.md README.md"
fi

files=()
for g in $scope_glob; do
  for f in $g; do [[ -f "$f" ]] && files+=("$f"); done
done
[[ "${#files[@]}" -gt 0 ]] || { echo "FAIL: no files match scope: $scope_glob" >&2; exit 1; }

strip_code() { # удаляет fenced-блоки и inline-code, чтобы команды вида grep "DEC-00" не считались ID
  awk '/^```/{infence=!infence;next} !infence' "$1" | sed -E 's/`[^`]*`//g'
}

table_defs() { # table-first-cell definitions с владением по артефакту
  awk -v idre="$ID_RE" '
    /^\s*\|/ {
      n = split($0, cells, "|")
      first = cells[2]
      gsub(/^[ \t]+|[ \t]+$/, "", first)
      if (header == "") { header = first; next }
      if (first ~ /^:?-+:?$/) next
      if ((header == "ID" || header == "REV-ID") && first ~ "^`?" idre "`?$") { gsub(/`/, "", first); print first }
      next
    }
    { header = "" }
  ' "$1"
}

table_owner_ok() { # prefix file — REV-* определяет только REVIEW_REPORT
  case "$1" in
    REV-*) [[ "$2" == *REVIEW_REPORT.md ]] ;;
    *)     [[ "$2" == *PROJECT_SPEC.md || "$2" == *IMPLEMENTATION.md ]] ;;
  esac
}

DEFS_ALL=""
for f in "${files[@]}"; do
  stripped="$(strip_code "$f")"

  # malformed identifiers
  while IFS= read -r tok; do
    [[ "$tok" =~ ^${ID_RE}$ || "$tok" =~ ^REQ-HARNESS-[0-9]{3}$ ]] || fail "$f: malformed identifier '$tok'"
  done < <(grep -oE "$BAD_RE" <<<"$stripped" | sort -u)

  # definitions: bold + headings + табличные (с владением)
  defs="$(
    { grep -oE "\*\*${ID_RE}\*\*" <<<"$stripped" | sed -E 's/^\*\*|\*\*$//g'
      grep -E "^#{1,6} ${ID_RE}\s*$" <<<"$stripped" | grep -oE "$ID_RE"
      while IFS= read -r id; do
        table_owner_ok "$id" "$f" && echo "$id"
      done < <(table_defs "$f")
      true
    } | sort -u
  )"
  DEFS_ALL="$DEFS_ALL
$defs"
done

# Глобальные дубликаты definitions
dups="$(sort <<<"$(grep -v '^$' <<<"$DEFS_ALL")" | uniq -d | grep -v '^$' || true)"
[[ -z "$dups" ]] || fail "duplicate global identifier definitions: $(tr '\n' ' ' <<<"$dups")"

# Dangling references
for f in "${files[@]}"; do
  stripped="$(strip_code "$f")"
  while IFS= read -r ref; do
    grep -qx "$ref" <<<"$DEFS_ALL" || fail "$f: dangling identifier '$ref'"
  done < <(grep -oE "$ID_RE" <<<"$stripped" | sort -u)
done

if [[ "$failures" -eq 0 ]]; then
  echo "PASS: global contract identifiers (${#files[@]} files, defs: $(grep -v '^$' <<<"$DEFS_ALL" | sort -u | wc -l | tr -d ' '))"
fi
exit "$failures"

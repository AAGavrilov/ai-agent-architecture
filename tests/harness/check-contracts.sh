#!/usr/bin/env bash
# Проверяет идентификаторы артефактов в docs/agent/*.md:
#  - формат PREFIX-NNN (или REQ-HARNESS-NNN) вне code spans;
#  - отсутствие дубликатов определений одного ID в одном файле;
#  - отсутствие ссылок на несуществующие REQ-* (определение REQ-*: bold **REQ-...**
#    или первая ячейка таблицы с заголовком 'ID'/'REV-ID').
# Источники: файловая система, разбор Markdown. Без LLM.
set -euo pipefail

cd "$(dirname "$0")/../.."

PREFIXES='REQ|DEC|REV|BLK|BIMP|CONFLICT|Q|ASM'
ID_RE="(${PREFIXES})(-HARNESS)?-[0-9]{3}"
# Кандидат на malformed: после дефиса первая позиция — цифра (отсекает метки вида 'REV-ID').
BAD_RE="(${PREFIXES})(-HARNESS)?-[0-9][0-9A-Za-z]*"

failures=0
fail() { echo "FAIL: $*" >&2; failures=1; }

strip_code() { # удаляет fenced-блоки и inline-code, чтобы команды вида grep "DEC-00" не считались ID
  awk '/^```/{infence=!infence;next} !infence' "$1" | sed -E 's/`[^`]*`//g'
}

table_defs() { # ID из первых ячеек таблиц с заголовком 'ID' или 'REV-ID'
  awk -v idre="$ID_RE" '
    /^\s*\|/ {
      n = split($0, cells, "|")
      first = cells[2]
      gsub(/^[ \t]+|[ \t]+$/, "", first)
      if (header == "") { header = first; next }
      if (first ~ /^:?-+:?$/) next
      if ((header == "ID" || header == "REV-ID") && first ~ "^`?" idre "`?$") print first
      next
    }
    { header = "" }
  ' "$1"
}

REQ_DEFS_ALL=""
for f in docs/agent/*.md; do
  [[ -f "$f" ]] || continue
  stripped="$(strip_code "$f")"

  # malformed identifiers
  while IFS= read -r tok; do
    [[ "$tok" =~ ^${ID_RE}$ || "$tok" =~ ^REQ-HARNESS-[0-9]{3}$ ]] || fail "$f: malformed identifier '$tok'"
  done < <(grep -oE "$BAD_RE" <<<"$stripped" | sort -u)

  # definitions: bold + табличные; дубликаты в пределах файла
  defs="$({ grep -oE "\*\*${ID_RE}\*\*" <<<"$stripped" | sed -E 's/^\*\*|\*\*$//g'; table_defs "$f"; } | sort)"
  dups="$(uniq -d <<<"$defs" | grep -v '^$' || true)"
  [[ -z "$dups" ]] || fail "$f: duplicate identifier definitions: $(tr '\n' ' ' <<<"$dups")"

  # REQ-definitions для проверки dangling references
  REQ_DEFS_ALL="$REQ_DEFS_ALL
$(grep -oE "\*\*REQ(-HARNESS)?-[0-9]{3}\*\*" <<<"$stripped" | sed -E 's/^\*\*|\*\*$//g')
$(table_defs "$f" | grep -E '^REQ(-HARNESS)?-[0-9]{3}$' || true)"
done

REQ_DEFS_ALL="$(sort -u <<<"$REQ_DEFS_ALL" | grep -v '^$' || true)"

# dangling REQ references
for f in docs/agent/*.md; do
  [[ -f "$f" ]] || continue
  stripped="$(strip_code "$f")"
  while IFS= read -r ref; do
    grep -qx "$ref" <<<"$REQ_DEFS_ALL" || fail "$f: reference to non-existing requirement '$ref'"
  done < <(grep -oE "REQ(-HARNESS)?-[0-9]{3}" <<<"$stripped" | sort -u)
done

if [[ "$failures" -eq 0 ]]; then
  echo "PASS: contract identifiers in docs/agent/ (REQ defs: $(wc -l <<<"$REQ_DEFS_ALL"))"
fi
exit "$failures"

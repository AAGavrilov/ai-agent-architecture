#!/usr/bin/env bash
# Проверяет битовую идентичность БЛОК 0 во всех трёх role prompts (§47 REQ-HARNESS-011).
set -euo pipefail

cd "$(dirname "$0")/../.."

PROMPTS=(
  ".agents/prompts/01-analysis.md"
  ".agents/prompts/02-implementation.md"
  ".agents/prompts/03-review.md"
)

extract_block0() {
  # БЛОК 0: от заголовка '### БЛОК 0.' до первого '### ' ПОСЛЕ ПОСЛЕДНЕГО '#### 0.x'.
  # Прежнее правило «до следующего '### '» обрывало блок на '### Правила стабильности'
  # (подзаголовок внутри блока) и покрывало только 0.1 — теперь проверяется весь контракт.
  awk '
    /^### БЛОК 0\./ { start = NR; inblock = 1 }
    inblock && /^#### 0\./ { last_sub = NR }
    inblock { line[NR] = $0; last_line = NR }
    END {
      stop = last_line + 1
      for (i = last_sub + 1; i <= last_line; i++) {
        if (line[i] ~ /^### /) { stop = i; break }
      }
      for (i = start; i < stop; i++) print line[i]
    }
  ' "$1"
}

hashes=()
for p in "${PROMPTS[@]}"; do
  [[ -f "$p" ]] || { echo "FAIL: prompt not found: $p" >&2; exit 1; }
  hashes+=("$(extract_block0 "$p" | sha256sum | awk '{print $1}')")
done

status=0
for i in 1 2; do
  if [[ "${hashes[0]}" != "${hashes[$i]}" ]]; then
    echo "FAIL: БЛОК 0 differs between ${PROMPTS[0]} and ${PROMPTS[$i]}" >&2
    status=1
  fi
done

if [[ "$status" -eq 0 ]]; then
  echo "PASS: БЛОК 0 identical in all three prompts (sha256 ${hashes[0]})"
fi
exit "$status"

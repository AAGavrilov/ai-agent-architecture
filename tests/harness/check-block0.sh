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
  # БЛОК 0: от заголовка '### БЛОК 0.' до следующего заголовка '### ' (не включая его).
  awk '/^### БЛОК 0\./{flag=1;next} /^### /{flag=0} flag' "$1"
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

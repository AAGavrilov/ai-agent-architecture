#!/usr/bin/env bash
# Aggregate deterministic harness (REQ-HARNESS-023): workflow продолжается
# (и CI зелёный) только если все checks и fixtures pass.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

scripts=(
  "tests/harness/check-block0.sh"
  "tests/harness/check-state.sh"
  "tests/harness/check-contracts.sh"
  "tests/harness/check-git-protocol.sh"
)

for script in "${scripts[@]}"; do
    echo "==> $script"
    bash "$script"
done

echo "==> tests/harness/run-fixtures.sh"
bash tests/harness/run-fixtures.sh

echo
echo "All harness checks passed."

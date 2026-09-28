#!/usr/bin/env bash
# Устанавливает versioned git-хуки из scripts/hooks/ в .git/hooks.
#
# Зачем отдельный установщик: git не версионирует .git/hooks, поэтому в чистом
# клоне хуков нет. Идемпотентно: повторный запуск обновляет хук; чужой
# (отличающийся) хук сохраняется рядом как <name>.bak-<timestamp>.
#
# Использование: bash scripts/install-hooks.sh
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

src_dir="scripts/hooks"
[[ -d "$src_dir" ]] || { echo "нет каталога $src_dir" >&2; exit 1; }

hooks_dir="$(git rev-parse --git-path hooks)"
mkdir -p "$hooks_dir"

installed=0
for src in "$src_dir"/*; do
  [[ -f "$src" ]] || continue
  name="$(basename "$src")"
  dst="$hooks_dir/$name"

  if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then
    backup="$dst.bak-$(date +%Y%m%d%H%M%S)"
    cp "$dst" "$backup"
    echo "существующий хук сохранён: $backup"
  fi

  cp "$src" "$dst"
  chmod +x "$dst" 2>/dev/null || true
  echo "установлен: $name"
  installed=$((installed + 1))
done

[[ "$installed" -gt 0 ]] || { echo "в $src_dir нет хуков" >&2; exit 1; }
echo "готово: хуков установлено — $installed (каталог: $hooks_dir)"

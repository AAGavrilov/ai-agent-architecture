#!/usr/bin/env bash
# Единая реализация разбора subject артефактных коммитов (REQ-HARNESS-032).
# Формат cycle-scoped нумерации живёт ровно здесь и используется всеми
# validator'ами (sourced by check-state.sh и check-git-protocol.sh).
#
#   <Type> <cycle>.<counter>: <описание>   — основной формат
#   <Type> <counter>: <описание>           — legacy cycle 1 (нормализуется в 1.<counter>)

# commit_subject SHA -> subject коммита
commit_subject() { git log -1 --format=%s "$1" 2>/dev/null; }

# commit_ref_nums SHA TYPE -> "cycle counter" (пусто, если subject не конформный)
commit_ref_nums() {
  local subj
  subj="$(commit_subject "$1")"
  if [[ "$subj" =~ ^$2\ ([0-9]+)\.([0-9]+): ]]; then
    echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
  elif [[ "$subj" =~ ^$2\ ([0-9]+): ]]; then
    echo "1 ${BASH_REMATCH[1]}"
  fi
}

# commit_series SUBJECTS TYPE -> строки "cycle counter", отсортированные
commit_series() {
  grep -E "^$2 [0-9]+(\.[0-9]+)?:" <<<"$1" \
    | sed -E "s/^$2 ([0-9]+)\.([0-9]+):.*/\1 \2/; s/^$2 ([0-9]+):.*/1 \1/" \
    | sort -n -k1,1 -k2,2 || true
}

#!/usr/bin/env bash
# Jump to an open window, or open a repo from @agent-status-repos-dir in a new window.
# "pick.sh windows" lists open windows only.
self=$(realpath "$0")
repos_dir=$(tmux show -gqv @agent-status-repos-dir)
repos_dir=${repos_dir:-$HOME/dev}
repos_dir=${repos_dir/#\~/$HOME}

if [ "$1" = preview ]; then
  if [ "$2" = w ]; then
    tmux capture-pane -ep -t "$3"
  else
    git -C "$3" log --oneline --color=always -20 2>/dev/null || ls "$3"
  fi
  exit 0
fi

W=$'\t'
open=$(tmux list-windows -F "w${W}#{window_id}${W}#{window_name}${W}#{?window_active,▌, } #{window_index} #{window_name}#{?@dup, (#{@dup}),}  #{?#{==:#{@agent},waiting},"$'\e[33m'"● waiting"$'\e[0m'",}#{?#{==:#{@agent},running},"$'\e[32m'"◐ running"$'\e[0m'",}#{?#{==:#{@agent},done},"$'\e[34m'"✓ done"$'\e[0m'",}")
names=$(cut -f3 <<<"$open")

[ "$1" = windows ] || repos=$(for g in "$repos_dir"/*/.git; do
  d=${g%/.git}
  grep -qxF "${d##*/}" <<<"$names" || printf 'r\t%s\t%s\t\e[90m  + %s\e[0m\n' "$d" "${d##*/}" "${d##*/}"
done)

sel=$(printf '%s\n%s\n' "$open" "$repos" | grep -v '^$' |
  fzf --ansi --delimiter="$W" --with-nth=4 --prompt="$( [ "$1" = windows ] && echo 'switch> ' || echo 'open> ' )" --no-sort \
      --preview="$self preview {1} {2}" --preview-window=right,60%) || exit 0

IFS="$W" read -r kind target name _ <<<"$sel"
if [ "$kind" = w ]; then
  tmux select-window -t "$target"
else
  tmux new-window -c "$target"
fi

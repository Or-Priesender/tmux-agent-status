#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$DIR/scripts/agent-status.sh"
HOOK_INDEX=73

opt() {
  local v
  v=$(tmux show -gqv "$1")
  echo "${v:-$2}"
}

waiting=$(opt @agent-status-waiting '#[fg=yellow] ●')
running=$(opt @agent-status-running '#[fg=green] ◐')
done_=$(opt @agent-status-done '#[fg=colour67] ✓')
if [ "$(opt @agent-status-blink off)" = on ]; then
  # strftime drops non-ASCII text, so the timed part holds only the seconds parity.
  tmux set -g @agent-status-blink-tick '#{e|%%:%S,2}'
  tmux set -g status-interval 1
  waiting="#{?#{T:@agent-status-blink-tick},$waiting,$(opt @agent-status-blink-off '  ')}"
fi
status="#{?#{==:#{@agent},waiting},$waiting,}#{?#{==:#{@agent},running},$running,}#{?#{==:#{@agent},done},$done_,}"
dup='#{?@dup, (#{@dup}),}'
hidden='#{?@hidden_count,#[fg=colour244]+#{@hidden_count} more ,}#{?@hidden_waiting,#[fg=yellow]#{@hidden_waiting} waiting ● ,}'
mru=$(opt @agent-status-mru 0)

interpolate() {
  local s="$1"
  s=${s//'#{agent_status}'/"$status"}
  s=${s//'#{agent_status_dup}'/"$dup"}
  s=${s//'#{agent_status_hidden}'/"$hidden"}
  echo "$s"
}

for o in status-left status-right; do
  tmux set -g "$o" "$(interpolate "$(tmux show -gv "$o")")"
done

for o in window-status-format window-status-current-format; do
  v=$(tmux show -gwv "$o")
  if [[ $v != *'#{agent_status}'* && $v != *'#{@agent}'* && $(opt @agent-status-auto on) = on ]]; then
    v="$v#{agent_status}"
  fi
  v=$(interpolate "$v")
  if [ "$o" = window-status-format ] && [ "$mru" -gt 0 ] 2>/dev/null && [[ $v != '#{?@mru_show,'* ]]; then
    v="#{?@mru_show,$v,}"
  fi
  tmux set -gw "$o" "$v"
done

for h in session-window-changed client-session-changed after-new-window; do
  tmux set-hook -g "$h[$HOOK_INDEX]" "run-shell -b '\"$SCRIPT\" refresh #{q:session_id}'"
done
tmux set-hook -g "window-unlinked[$HOOK_INDEX]" "run-shell -b '\"$SCRIPT\" refresh'"

key=$(opt @agent-status-picker-key '')
[ -n "$key" ] && tmux bind-key "$key" display-popup -w 80% -h 70% -E "\"$DIR/scripts/pick.sh\""
key=$(opt @agent-status-windows-key '')
[ -n "$key" ] && tmux bind-key "$key" display-popup -w 80% -h 70% -E "\"$DIR/scripts/pick.sh\" windows"

"$SCRIPT" refresh

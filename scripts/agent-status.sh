#!/usr/bin/env bash
# Agent status per window, and the "N most recent windows" status line.
#
#   agent-status.sh set <running|waiting|done|clear>   Claude hooks (hook JSON on stdin)
#   agent-status.sh refresh [session-id]               tmux hooks; with a session id,
#                                                      also marks its current window as seen
#
# Window options:  @agent (running|waiting|done), @last_seen (epoch), @mru_show (1 = in the bar),
#                  @dup (2, 3, ... when another window in the session has the same name)
# Session options: @hidden_count, @hidden_waiting
TAB=$'\t'

refresh() {
  local MAX
  MAX=$(tmux show -gqv @agent-status-mru)
  [ "${MAX:-0}" -gt 0 ] 2>/dev/null || MAX=1000000

  if [ -n "$1" ]; then
    local w
    w=$(tmux display -p -t "$1" '#{window_id}') || return
    tmux set -w -t "$w" @last_seen "$(date +%s)"
    [ "$(tmux show -wqv -t "$w" @agent)" = done ] && tmux set -wu -t "$w" @agent
  fi

  {
  tmux list-windows -a -F '#{session_id} #{window_id} #{?@last_seen,#{@last_seen},0} #{window_activity} #{?@mru_show,1,0} #{?@agent,#{@agent},-}' |
    sort -k1,1 -k3,3nr -k4,4nr |
    awk -v max="$MAX" '
      function flush() {
        if (sess == "") return
        printf "set -t \x27%s\x27 @hidden_count %d\n", sess, hidden
        if (waiting) printf "set -t \x27%s\x27 @hidden_waiting %d\n", sess, waiting
        else printf "set -u -t \x27%s\x27 @hidden_waiting\n", sess
      }
      $1 != sess { flush(); sess = $1; n = 0; hidden = 0; waiting = 0 }
      {
        show = (++n <= max)
        if (show && !$5) printf "set -w -t %s @mru_show 1\n", $2
        if (!show && $5) printf "set -wu -t %s @mru_show\n", $2
        if (!show) { hidden++; if ($6 == "waiting") waiting++ }
      }
      END { flush() }'

  # Same name twice in a session: the later window gets @dup 2, 3, ... ("tmux-wt (2)").
  tmux list-windows -a -F "#{session_id}${TAB}#{window_index}${TAB}#{window_id}${TAB}#{?@dup,#{@dup},0}${TAB}#{window_name}" |
    sort -t "$TAB" -k1,1 -k2,2n |
    awk -F "$TAB" '{
      c = ++seen[$1 SUBSEP $5]; want = (c > 1) ? c : 0
      if (want != $4) print (want ? "set -w -t " $3 " @dup " want : "set -wu -t " $3 " @dup")
    }'
  } | tmux source-file -

  tmux list-clients -F '#{client_name}' | while read -r c; do tmux refresh-client -S -t "$c"; done
}

set_status() {
  [ -n "$TMUX_PANE" ] || exit 0
  local input state=$1 cur
  input=$(cat)
  # Claude also notifies after 60s idle; that is not a real wait.
  if [ "$state" = waiting ] && grep -q '"notification_type" *: *"idle_prompt"' <<<"$input"; then
    exit 0
  fi
  # A finished agent in the window you look at needs no marker.
  if [ "$state" = done ] && [ "$(tmux display -p -t "$TMUX_PANE" '#{&&:#{window_active},#{session_attached}}')" = 1 ]; then
    state=clear
  fi
  cur=$(tmux show -wqv -t "$TMUX_PANE" @agent)
  if [ "$state" = clear ]; then
    [ -n "$cur" ] || exit 0
    tmux set -wu -t "$TMUX_PANE" @agent
  else
    [ "$cur" = "$state" ] && exit 0
    tmux set -w -t "$TMUX_PANE" @agent "$state"
  fi
  refresh
}

case "$1" in
  set) set_status "$2" ;;
  refresh) refresh "$2" ;;
  *) echo "usage: $0 set <running|waiting|done|clear> | refresh [session-id]" >&2; exit 2 ;;
esac

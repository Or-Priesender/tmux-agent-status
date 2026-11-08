# tmux-agent-status

Shows the status of each [Claude Code](https://claude.com/claude-code) agent on its tmux window:

| Icon | Status |
|---|---|
| `◐` (green) | The agent is working |
| `●` (yellow) | The agent waits for you (permission prompt or question) |
| `✓` (blue) | The agent finished. The mark goes away when you open the window. |

Optional extras:
- Show only the N most recently used windows in the status bar, with a "+3 more, 1 waiting ●" counter.
- An fzf popup to jump to a window (with its agent status) or open a repo in a new window.

This repo has two plugins. Install both.

## Install

### 1. tmux plugin (with [TPM](https://github.com/tmux-plugins/tpm))

Add to `tmux.conf`, before the TPM `run` line:

```tmux
set -g @plugin 'Or-Priesender/tmux-agent-status'
```

Then press `prefix + I`.

Without TPM: clone the repo and add `run-shell /path/to/tmux-agent-status/agent-status.tmux` at the end of `tmux.conf`.

### 2. Claude Code plugin

In Claude Code:

```
/plugin marketplace add Or-Priesender/tmux-agent-status
/plugin install tmux-agent-status@tmux-agent-status
```

The plugin adds its own hooks. It does not change your `settings.json`.

## Configure

The plugin does not replace your status bar. It fills in these placeholders in your formats:

| Placeholder | Use in | Shows |
|---|---|---|
| `#{agent_status}` | `window-status-format`, `window-status-current-format` | The agent icon |
| `#{agent_status_hidden}` | `status-left`, `status-right` | "+N more" and "N waiting ●" for hidden windows (needs `@agent-status-mru`) |
| `#{agent_status_dup}` | window formats | " (2)" when two windows in a session have the same name |

If a window format has no `#{agent_status}`, the plugin adds it at the end. Set `@agent-status-auto off` to stop this.

Example:

```tmux
setw -g window-status-format ' #I #W#{agent_status_dup}#{agent_status} '
setw -g window-status-current-format '#[bold] #I #W#{agent_status_dup}#{agent_status} '
set -g status-right '#{agent_status_hidden}%H:%M'
```

Options (all optional):

| Option | Default | Effect |
|---|---|---|
| `@agent-status-mru` | `0` (off) | Show only the N most recently used windows in the status bar |
| `@agent-status-picker-key` | none | Key (after prefix) for the popup with open windows and repos |
| `@agent-status-windows-key` | none | Key (after prefix) for the popup with open windows only |
| `@agent-status-repos-dir` | `~/dev` | Folder with the git repos the popup lists |
| `@agent-status-waiting` | `#[fg=yellow] ●` | Icon for "waiting" |
| `@agent-status-running` | `#[fg=green] ◐` | Icon for "running" |
| `@agent-status-done` | `#[fg=colour67] ✓` | Icon for "done" |
| `@agent-status-auto` | `on` | Add `#{agent_status}` to window formats that do not have it |
| `@agent-status-blink` | `off` | Make the "waiting" icon blink (see below) |
| `@agent-status-blink-off` | two spaces | What shows in the "off" step of the blink. Use the same width as your waiting icon. |

### Blink

Some terminals (for example Ghostty) do not show the tmux `blink` style, so `#[blink]` can hide the icon. `@agent-status-blink on` makes its own blink instead: the icon goes on and off each second. For this, the plugin sets `status-interval 1`, so tmux redraws the status bar each second. This uses almost no CPU. But if your status bar has `#(...)` shell commands, tmux runs them each second too.

The popup needs tmux 3.2 or later and [fzf](https://github.com/junegunn/fzf).

## How it works

The Claude Code hooks run `scripts/agent-status.sh set <status>`. The script sets the `@agent` option on the window of the Claude pane (`$TMUX_PANE`). The tmux plugin adds hooks (at index 73, so your own hooks stay) that run `agent-status.sh refresh` when you change windows. The refresh clears "done" when you see the window and updates the MRU list.

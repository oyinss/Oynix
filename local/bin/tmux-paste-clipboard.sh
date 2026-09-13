#!/bin/sh
# Paste the Wayland clipboard into the current tmux pane.
#
# Stock tmux binds middle click (MouseDown2Pane) to `paste-buffer`, which uses
# tmux's own paste buffer rather than the system clipboard, so middle-click can
# paste stale text. tmux can only *write* to the clipboard (OSC 52) and cannot
# read it, so this shells out to wl-paste instead.

set -u

content="$(wl-paste --no-newline 2>/dev/null || true)"

if [ -z "$content" ]; then
    # System clipboard empty or unreadable: keep tmux's original behaviour.
    tmux paste-buffer -p 2>/dev/null || true
    exit 0
fi

buf="tmux-clipboard"
printf '%s' "$content" | tmux load-buffer -b "$buf" - 2>/dev/null || exit 0
tmux paste-buffer -b "$buf" -d -p 2>/dev/null || true
exit 0

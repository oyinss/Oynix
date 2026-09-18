#!/bin/sh
#
# tmux-path.sh — print a pane's directory for the tmux status bar with $HOME collapsed
# to `~` (e.g. ~/code/myproject).
#
# Used by status-format[1] in config/tmux/tmux.conf. tmux's own format variables only
# offer #{b:...} (basename) and #{d:...} (dirname) -- there is no home-shortening -- and
# writing the literal home path in the config would hardcode this machine's username.
# The chip styling stays in the tmux format; this only prints the text.

p=${1:-$PWD}

case $p in
  "$HOME")   printf '~\n' ;;
  "$HOME"/*) printf '~%s\n' "${p#"$HOME"}" ;;
  /*)        printf '%s\n' "$p" ;;
  *)         printf '%s\n' "$PWD/$p" ;;
esac

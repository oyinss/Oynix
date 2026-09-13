#!/bin/sh
#
# tmux status-line git indicator.
#
# Used by status-format[1] in config/tmux/tmux.conf: prints a rounded chip with the
# branch and dirty counts for the git repo containing the given directory (default:
# the current directory). Prints nothing at all when the directory is not inside a
# git repo, so the second status line stays empty.
#
# Styling is emitted as tmux #[...] sequences -- tmux parses styles returned by
# #() command output, so the chip can be built here instead of in the format string.

dir=${1:-$PWD}
[ -n "$dir" ] && [ -d "$dir" ] || exit 0

# Nerd Font half-circles used to round the chip: U+E0B6 (left) / U+E0B4 (right).
lc=$(printf '\356\202\266')
rc=$(printf '\356\202\264')

git -C "$dir" --no-optional-locks status --porcelain=v2 --branch \
    --untracked-files=normal 2>/dev/null |
  awk -v lc="$lc" -v rc="$rc" '
    /^# branch.head / { branch = substr($0, 15) }
    /^# branch.oid /  { oid = substr($0, 14, 7) }
    /^# branch.ab /   { ahead = substr($3, 2) + 0; behind = substr($4, 2) + 0 }
    /^[12u] /         { xy = substr($0, 3, 2)
                        if (substr(xy, 1, 1) != ".") staged++
                        if (substr(xy, 2, 1) != ".") modified++ }
    /^\? /            { untracked++ }
    END {
      if (branch == "" ) exit
      if (branch == "(detached)") branch = oid

      chip = "#[fg=#2A2F41,bg=#1A1B26]" lc
      chip = chip "#[fg=#9ece6a,bg=#2A2F41,bold] " branch " "
      if (ahead)   chip = chip "#[fg=#7aa2f7,bg=#2A2F41] \342\207\241" ahead " "
      if (behind)  chip = chip "#[fg=#7aa2f7,bg=#2A2F41] \342\207\243" behind " "
      if (staged)  chip = chip "#[fg=#9ece6a,bg=#2A2F41] +" staged " "
      if (modified) chip = chip "#[fg=#ff9e64,bg=#2A2F41] !" modified " "
      if (untracked) chip = chip "#[fg=#7aa2f7,bg=#2A2F41] ?" untracked " "
      chip = chip "#[fg=#2A2F41,bg=#1A1B26]" rc
      printf "%s", chip
    }'

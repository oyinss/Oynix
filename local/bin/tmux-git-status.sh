#!/bin/sh
#
# tmux-git-status.sh — git branch and status for the tmux status line, drawn as one fused
# powerline chip: <octocat> <branch glyph> <branch name> [staged] [modified] [untracked]
# [ahead] [behind].
#
# Used by status-format[2] in config/tmux/tmux.conf, immediately AFTER the directory chip
# (tmux-path.sh), to which it is fused. This script owns BOTH edges of that seam: the
# transition into the git colours when there is a repository to show, and the directory
# chip's closing half-circle when there is not. That is why the format string leaves the
# directory chip unclosed, and why this script still prints something outside a repo.
#
# Colour carries the status, in the bar's palette, dark text on every block:
#   branch      green while the tree is clean, peach as soon as anything has changed
#   +staged     blue     !modified  peach     ?untracked  purple     ⇡ahead/⇣behind  cyan
# Blocks are separated by a single space and joined with half-circle transitions (U+E0B8)
# so the colours fuse instead of stepping.
#
# Styling is emitted as tmux #[...] sequences; tmux parses styles returned by #().

# Colours -- keep in step with config/tmux/tmux.conf (GREY is the directory chip's colour)
BAR='#1A1B26' DARK='#1A1B26' GREEN='#9ece6a' PEACH='#ff9e64'
BLUE='#7aa2f7' PURPLE='#bb9af7' CYAN='#7dcfff' GREY='#2A2F41'

# Glyphs built from byte escapes so the exact codepoints cannot be mangled:
#   U+E0B4 right cap / U+E0B8 colour-to-colour transition
#   U+F09B octocat / U+E0A0 branch / U+21E1 ahead / U+21E3 behind
rc=$(printf '\356\202\264')
tr=$(printf '\356\202\270')
octo=$(printf '\357\202\233')
br=$(printf '\356\202\240')
up=$(printf '\342\207\241')
down=$(printf '\342\207\243')

dir=${1:-$PWD}
if [ -z "$dir" ] || [ ! -d "$dir" ]; then
  printf '#[fg=%s,bg=%s]%s' "$GREY" "$BAR" "$rc"    # still close the directory chip
  exit 0
fi

# One git call gives the branch header plus per-file codes (porcelain v2): lines starting
# 1/2/u carry XY in columns 3-4 (X = staged, Y = worktree change), '?' = untracked.
git -C "$dir" --no-optional-locks status --porcelain=v2 --branch \
    --untracked-files=normal 2>/dev/null |
  awk -v bar="$BAR" -v dark="$DARK" -v grey="$GREY" -v green="$GREEN" -v peach="$PEACH" \
      -v blue="$BLUE" -v purple="$PURPLE" -v cyan="$CYAN" \
      -v rc="$rc" -v tr="$tr" -v octo="$octo" -v br="$br" \
      -v up="$up" -v down="$down" '
    /^# branch.head / { branch = substr($0, 15) }
    /^# branch.oid /  { oid = substr($0, 14, 7) }
    /^# branch.ab /   { ahead = substr($3, 2) + 0; behind = substr($4, 2) + 0 }
    /^[12u] /         { xy = substr($0, 3, 2)
                        if (substr(xy, 1, 1) != ".") staged++
                        if (substr(xy, 2, 1) != ".") modified++ }
    /^\? /            { untracked++ }
    END {
      # Outside a repository: no git chip, but the directory chip is still ours to close,
      # so the row does not end on a bare edge.
      if (branch == "") {
        print "#[fg=" grey ",bg=" bar "]" rc
        exit
      }
      if (branch == "(detached)") branch = oid
      dirty = (staged + modified + untracked) > 0

      n = 0
      col[n] = dirty ? peach : green; txt[n] = " " octo " " br " " branch; n++
      if (ahead)     { col[n] = cyan;   txt[n] = " " up ahead;    n++ }
      if (behind)    { col[n] = cyan;   txt[n] = " " down behind; n++ }
      if (staged)    { col[n] = blue;   txt[n] = " +" staged;     n++ }
      if (modified)  { col[n] = peach;  txt[n] = " !" modified;   n++ }
      if (untracked) { col[n] = purple; txt[n] = " ?" untracked;  n++ }

      # Starts with the grey-to-status transition, NOT a left cap: the directory chip sits
      # against this edge, so the two backgrounds have to meet directly.
      chip = "#[fg=" grey ",bg=" col[0] "]" tr
      for (i = 0; i < n; i++) {
        if (i) chip = chip "#[fg=" col[i-1] ",bg=" col[i] "]" tr
        chip = chip "#[fg=" dark ",bg=" col[i] ",bold]" txt[i]
      }
      chip = chip " #[fg=" col[n-1] ",bg=" bar "]" rc
      print chip
    }'

#!/bin/zsh

# Add a visible icon to Ctrl-R history entries while keeping the original
# history event number in the first field so fzf can still recover the command.

fzf-history-widget() {
  local selected extracted_with_perl=0
  # Default to a colorful terminal glyph; keep it overrideable via FZF_CTRL_R_ICON.
  local icon
  icon="${FZF_CTRL_R_ICON:-$(printf '\033[38;5;45m\033[38;5;213m\033[0m')}"
  setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases no_glob no_sh_glob no_ksharrays extendedglob 2>/dev/null

  if zmodload -F zsh/parameter p:{commands,history} 2>/dev/null && (( ${+commands[perl]} )); then
    selected="$(
      printf '%s\t%s\000' "${(kv)history[@]}" |
        FZF_CTRL_R_ICON="$icon" perl -0 -ne '
          if (!$seen{(/^\s*[0-9]+\**\t(.*)/s, $1)}++) {
            if (my ($event, $cmd) = /^\s*([0-9]+\**)\t(.*)\z/s) {
              $cmd =~ s/\n/\n\t/g;
              print "$event\t$ENV{FZF_CTRL_R_ICON} $cmd\0";
            }
          }
        ' |
        FZF_DEFAULT_OPTS=$(__fzf_defaults "" "--ansi -n2..,.. --scheme=history --bind=ctrl-r:toggle-sort,alt-r:toggle-raw --wrap-sign '\t↳ ' --highlight-line --multi ${FZF_CTRL_R_OPTS-} --query=${(qqq)LBUFFER} --read0") \
        FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd)
    )"
    extracted_with_perl=1
  else
    selected="$(
      fc -rl 1 | __fzf_exec_awk -v icon="$icon" '
        function trim_history(line,   cmd) {
          cmd = line
          sub(/^[ \t]*[0-9]+\**[ \t]+/, "", cmd)
          return cmd
        }
        {
          cmd = trim_history($0)
          if (!seen[cmd]++) {
            match($0, /^[[:blank:]]*([0-9]+\**)[[:blank:]]+(.*)$/, m)
            if (m[2] != "") {
              gsub(/\n/, "\n\t", m[2])
              print m[1] "\t" icon " " m[2]
            }
          }
        }
      ' |
        FZF_DEFAULT_OPTS=$(__fzf_defaults "" "--ansi -n2..,.. --scheme=history --bind=ctrl-r:toggle-sort,alt-r:toggle-raw --wrap-sign '\t↳ ' --highlight-line --multi ${FZF_CTRL_R_OPTS-} --query=${(qqq)LBUFFER}") \
        FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd)
    )"
  fi

  local ret=$?
  local -a cmds
  local -a mbegin mend match
  if [ -n "$selected" ]; then
    if ((( extracted_with_perl )) && [[ $selected == <->$'\t'* ]]) ||
    ((( ! extracted_with_perl )) && [[ $selected == [[:blank:]]#<->(  |\* )* ]]); then
      for line in ${(ps:\n:)selected}; do
        if (( extracted_with_perl )); then
          if [[ $line == (#b)(<->)(#B)$'\t'* ]]; then
            (( ${+history[${match[1]}]} )) && cmds+=("${history[${match[1]}]}")
          fi
        elif [[ $line == [[:blank:]]#(#b)(<->)(#B)(  |\* )* ]]; then
          zle .push-line
          zle vi-fetch-history -n ${match[1]}
          (( ${#BUFFER} )) && cmds+=("${BUFFER}")
          BUFFER=""
          zle .get-line
        fi
      done
    else
      cmds=("${(@ps:\n:)selected}")
    fi

    if [[ ${#cmds[@]} -gt 0 ]]; then
      BUFFER="${cmds[1]}"
      CURSOR=$#BUFFER
    fi
  fi

  zle reset-prompt
  return $ret
}

zle -N fzf-history-widget
bindkey -M emacs '^R' fzf-history-widget
bindkey -M vicmd '^R' fzf-history-widget
bindkey -M viins '^R' fzf-history-widget

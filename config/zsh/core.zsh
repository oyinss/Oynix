#!/bin/zsh

# ███ ███ █ █ ███ ███
#   █ █   █ █ █ █ █
#  █   █  ███ ██  █
# █     █ █ █ █ █ █
# ███ ███ █ █ █ █ ███

# -------------------------------------------------------
# Constants
# -------------------------------------------------------
ZSH_CONFIG_DIR="$HOME/.config/zsh"
P10K_CONFIG="$HOME/.p10k.zsh"
DIRHISTORY_PLUGIN="$ZSH_CONFIG_DIR/custom_plugins/dirhistory.plugin.zsh"
FIGFONTDIR="$HOME/.config/zsh/figlet-fonts"
export BET365_BROWSER_PATH="/usr/bin/google-chrome-stable"

# -------------------------------------------------------
# Display username banner
# -------------------------------------------------------
if [[ -f "$FIGFONTDIR/dosrebel.flf" ]]; then
  figlet -d "$FIGFONTDIR" -f dosrebel "$(echo $USER | tr '[:lower:]' '[:upper:]' | head -c 1)${USER:1}" | lolcat
else
  echo "$USER" | lolcat
fi

# -------------------------------------------------------
# Install & source Zap
# -------------------------------------------------------
if [[ ! -f "$HOME/.local/share/zap/zap.zsh" ]]; then
  mkdir -p "$HOME/.local/share/zap"
  git clone https://github.com/zap-zsh/zap.git "$HOME/.local/share/zap" >/dev/null 2>&1
fi
[[ -f "$HOME/.local/share/zap/zap.zsh" ]] && source "$HOME/.local/share/zap/zap.zsh"

# -------------------------------------------------------
# Plugins
# -------------------------------------------------------
plug "zsh-users/zsh-autosuggestions"
plug "zsh-users/zsh-syntax-highlighting"
plug "zsh-users/zsh-history-substring-search"
plug "zap-zsh/supercharge"
plug "oyinss/ginit"
plug "zap-zsh/vim"
plug "zap-zsh/fzf"
plug "zap-zsh/sudo"
plug "djui/alias-tips"
plug "esc/conda-zsh-completion"
plug "hlissner/zsh-autopair"
plug "romkatv/powerlevel10k"

# -------------------------------------------------------
# Load dirhistory without OMZ
# -------------------------------------------------------
if [[ ! -f "$DIRHISTORY_PLUGIN" ]]; then
  mkdir -p "$ZSH_CONFIG_DIR/custom_plugins"
  curl -sL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/dirhistory/dirhistory.plugin.zsh \
    -o "$DIRHISTORY_PLUGIN"
fi
[[ -f "$DIRHISTORY_PLUGIN" ]] && source "$DIRHISTORY_PLUGIN"

# -------------------------------------------------------
# History format
# -------------------------------------------------------
export HISTTIMEFORMAT="%F %T "

# -------------------------------------------------------
# Powerlevel10k instant prompt
# -------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -------------------------------------------------------
# Load custom aliases and functions
# -------------------------------------------------------
if [[ -d "$ZSH_CONFIG_DIR/custom_plugins" ]]; then
  for file in "$ZSH_CONFIG_DIR/custom_plugins/"*.zsh(N); do source "$file"; done
fi

if [[ -d "$ZSH_CONFIG_DIR/aliases" ]]; then
  for file in "$ZSH_CONFIG_DIR/aliases/"*.zsh(N); do source "$file"; done
fi

if [[ -d "$ZSH_CONFIG_DIR/extensions" ]]; then
  for file in "$ZSH_CONFIG_DIR/extensions/"*.zsh(N); do source "$file"; done
fi

if [[ -d "$ZSH_CONFIG_DIR/extensions" ]]; then
  for file in "$ZSH_CONFIG_DIR/extensions/"*.zsh(N); do source "$file"; done
fi

# -------------------------------------------------------
# Powerlevel10k config
# -------------------------------------------------------
# NOTE: `p10k configure` only leaves ~/.zshrc alone when it finds BOTH the instant prompt
# source line (above) and a `source <config>` line in a form it recognises -- `~/.p10k.zsh`
# is one of them. A variable indirection such as `source $P10K_CONFIG` is NOT recognised,
# and the wizard then rewrites ~/.zshrc with `mv`, which replaces the symlink to this file
# with a regular copy. Keep this literal line here.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# -------------------------------------------------------
# Powerlevel10k: keep the git chip live while idle at the prompt
# -------------------------------------------------------
# p10k asks gitstatusd for the repo state only when it draws a new prompt (precmd), so the
# branch/dirty chip goes stale whenever the repo changes behind the shell's back -- an editor
# saving a file, another terminal committing, tmux. tmux itself does not have that problem
# because it re-runs the `#()` jobs in its status line every status-interval; this section gives
# the prompt the same treatment.
#
# Nothing needs to be recomputed from scratch: gitstatusd keeps a cached, mtime-checked answer
# (sub-millisecond), so the fix is to poke it on a timer and let p10k's own async callback
# (_p9k_vcs_resume) re-render the VCS segment. TMOUT + TRAPALRM is the zsh idiom for "run this
# while idle at the prompt": the alarm is armed only while zsh waits for a command line, so it
# never fires while a command, a pager or a `read` prompt is running, and a child process that
# owns the terminal (fzf, an editor) blocks it for free.
#
# The trap can still fire while a zsh widget is waiting for its next key, and repainting the
# prompt then would land in the middle of that widget's display. So only a bare prompt with an
# empty edit buffer is ever touched: $CONTEXT is `start` only at PS1 (it is `vared` in vared and
# `select` in a select loop), and $BUFFER is empty only when there is no half-typed line and no
# completion in progress. The cost is that a partially typed line keeps a stale chip until the
# next prompt -- which is precisely when p10k refreshes on its own anyway.
#
# Override the cadence with P10K_GIT_REFRESH_INTERVAL (seconds) before this file is sourced.
# A second TRAPALRM elsewhere in the config would shadow this one; chain it here if that ever
# becomes necessary.
if [[ -o interactive ]]; then
  typeset -g P10K_GIT_REFRESH_INTERVAL=${P10K_GIT_REFRESH_INTERVAL:-3}

  function _p10k_git_refresh() {
    # Bare PS1 prompt only: never paint over a completion list, vared, a select menu or typing.
    [[ ${CONTEXT-} == start && -z ${BUFFER-} ]] || return 0
    # No daemon means p10k fell back to plain `git status` on precmd: there is no cached answer
    # to refresh, and a repaint would only redraw the same stale chip.
    (( $+GITSTATUS_DAEMON_PID_POWERLEVEL9K )) || return 0
    # These are p10k's own async plumbing; skip quietly on a p10k that no longer defines them.
    (( $+functions[gitstatus_query_p9k_] && $+functions[_p9k_vcs_resume] &&
       $+functions[_p9k_vcs_status_for_dir] )) || return 0
    # Only repos p10k has already seen are worth a tick, so sitting in $HOME or /tmp stays silent.
    _p9k_vcs_status_for_dir || return 0
    # -t 0 makes the query async: the callback repaints the prompt, the line editor never blocks.
    gitstatus_query_p9k_ -d $PWD -t 0 -c '_p9k_vcs_resume 1' POWERLEVEL9K 2>/dev/null
    return 0
  }

  TMOUT=$P10K_GIT_REFRESH_INTERVAL
  TRAPALRM() { _p10k_git_refresh }
fi

# -------------------------------------------------------
# tmux status bar: keep the directory in step with cd
# -------------------------------------------------------
if [[ -n ${TMUX:-} ]]; then
  # tmux only re-runs the `#()` jobs in the status line every status-interval (5s), so the
  # directory and git chip lag behind a cd. A status refresh re-runs them on the spot, so
  # ask for one from chpwd rather than polling harder.
  #
  # The binary is resolved ONCE, by absolute path. A name lookup here runs on every cd and
  # has already produced `zsh: command not found: tmux` -- same failure mode as eza in
  # aliases/list.zsh: the file exists and PATH is fine, but the shell's command hash is
  # stale. Fall back to the usual system locations, and if tmux still cannot be found the
  # hook degrades to a silent no-op that records the evidence once per cd in
  # $XDG_CACHE_HOME/tmux-refresh-miss.log. A missing binary must never print an error on
  # every cd.
  _tmux_bin=${commands[tmux]:-}
  if [[ -z $_tmux_bin ]]; then
    for _c in /usr/bin/tmux /usr/local/bin/tmux /bin/tmux; do
      [[ -x $_c ]] && { _tmux_bin=$_c; break }
    done
    unset _c
  fi

  _tmux_refresh_status() {
    if [[ -n $_tmux_bin ]]; then
      "$_tmux_bin" refresh-client -S 2>/dev/null
    else
      # grouped so the stderr redirect applies BEFORE the >> is opened: if the cache
      # directory is missing, a bare `>>file 2>/dev/null` still prints the open failure
      {
        printf '%s PATH=%s TMUX=%s\n' "$(date '+%F %T')" "$PATH" "${TMUX:-}" \
          >>"${XDG_CACHE_HOME:-$HOME/.cache}/tmux-refresh-miss.log"
      } 2>/dev/null
    fi
    return 0   # a chpwd hook returning non-zero warns on every cd
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _tmux_refresh_status
fi

# -------------------------------------------------------
# Additional setopts (not covered by supercharge)
# -------------------------------------------------------
setopt correct             # auto correct mistakes
setopt magicequalsubst     # enable filename expansion for arguments of the form 'anything=expression'
setopt notify              # report the status of background jobs immediately
setopt numericglobsort     # sort filenames numerically when it makes sense
setopt promptsubst         # enable command substitution in prompt

# -------------------------------------------------------
# History extras
# -------------------------------------------------------
setopt sharehistory        # share history across sessions
setopt histignoredups      # alternative spelling, ensure dedup
HISTDUP=erase              # erase duplicates in history

# -------------------------------------------------------
# Path management functions
# -------------------------------------------------------
function pathappend() {
    for ARG in "$@"; do
        if [ -d "$ARG" ] && [[ ":$PATH:" != *":$ARG:"* ]]; then
            PATH="${PATH:+"$PATH:"}$ARG"
        fi
    done
}

function pathprepend() {
    for ARG in "$@"; do
        if [ -d "$ARG" ] && [[ ":$PATH:" != *":$ARG:"* ]]; then
            PATH="$ARG${PATH:+":$PATH"}"
        fi
    done
}

pathprepend "$HOME/.local/bin"
pathappend "$HOME/.bun/bin"

# -------------------------------------------------------
# Yazi: cd on exit wrapper
# -------------------------------------------------------
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# -------------------------------------------------------
# Utility functions
# -------------------------------------------------------

# Start a program detached from terminal
function runfree() {
    "$@" > /dev/null 2>&1 & disown
}

# Copy file with a progress bar (rsync preferred, strace fallback)
function cpp() {
    if [[ -x "$(command -v rsync)" ]]; then
        rsync -ah --info=progress2 "${1}" "${2}"
    else
        set -e
        strace -q -ewrite cp -- "${1}" "${2}" 2>&1 \
        | awk '{
        count += $NF
        if (count % 10 == 0) {
            percent = count / total_size * 100
            printf "%3d%% [", percent
            for (i=0;i<=percent;i++)
                printf "="
                printf ">"
                for (i=percent;i<100;i++)
                    printf " "
                    printf "]\r"
                }
            }
        END { print "" }' total_size=$(stat -c '%s' "${1}") count=0
    fi
}

# Copy and go to directory
function cpg() {
    if [[ -d "$2" ]]; then
        cp "$1" "$2" && cd "$2"
    else
        cp "$1" "$2"
    fi
}

# Move and go to directory
function mvg() {
    if [[ -d "$2" ]]; then
        mv "$1" "$2" && cd "$2"
    else
        mv "$1" "$2"
    fi
}

# Create directory and go into it
function mkdirg() {
    mkdir -p "$@" && cd "$@"
}

# Print random Unicode bar chart across terminal width
function random_bars() {
    columns=$(tput cols)
    chars=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
    for ((i = 1; i <= $columns; i++)); do
        echo -n "${chars[RANDOM%${#chars} + 1]}"
    done
    echo
}

# Add to ~/.zshrc to ignore history for commands containing secrets:
setopt HIST_IGNORE_SPACE
export HISTIGNORE='sudo -S *'
export CUA_DRIVER_RS_ENABLE_WAYLAND=1

# `p10k configure` searches this file for its instant-prompt line and a recognised
# `source ~/.p10k.zsh` line; both now live in the prompt section above, which is what
# stops the wizard from rewriting ~/.zshrc (and replacing the symlink to this file with
# a regular copy). See the NOTE in that section before changing those two lines.

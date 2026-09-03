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
[[ -f "$P10K_CONFIG" ]] && source "$P10K_CONFIG"

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

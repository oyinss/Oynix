#!/bin/zsh

# ███ █ █ ███ ███ ███ ███ ███
# █   █ █ █ █ █ █ █ █  █  █
# ███  █  ███ █ █ ██   █   █
# █   █ █ █   █ █ █ █  █    █
# ███ █ █ █   ███ █ █  █  ███

# -------------------------------------------------------
# Editors
# -------------------------------------------------------
export EDITOR="nvim"
export VISUAL="nvim"
export SUDO_EDITOR="nvim"
export FCEDIT="nvim"

# -------------------------------------------------------
# Terminal & Browser
# -------------------------------------------------------
export TERMINAL="kitty"
export BROWSER="brave"

# -------------------------------------------------------
# Man
# -------------------------------------------------------
export MANPAGER='nvim +Man!'
export MANWIDTH=999

# -------------------------------------------------------
# SSL & Build Flags
# -------------------------------------------------------
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export PYTHON_CONFIGURE_OPTS="--with-openssl=/usr"
export LDFLAGS="-L/usr/library"
export CPPFLAGS="-I/usr/include"

# -------------------------------------------------------
# Language & Locale
# -------------------------------------------------------
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

# -------------------------------------------------------
# Desktop Environment
# -------------------------------------------------------
export QT_QPA_PLATFORMTHEME="kvantum"
export XDG_CURRENT_DESKTOP="Wayland"

# -------------------------------------------------------
# Chrome (for puppeteer, playwright, etc.)
# -------------------------------------------------------
export CHROME_EXECUTABLE=/usr/bin/google-chrome-stable

# -------------------------------------------------------
# Pager
# -------------------------------------------------------
if [[ -x "$(command -v bat)" ]]; then
  export PAGER=bat
fi

# -------------------------------------------------------
# FZF theming
# -------------------------------------------------------
if [[ -x "$(command -v fzf)" ]] && [[ -z "${FZF_DEFAULT_OPTS##*--color*}" ]]; then
  export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
    --info=inline-right \
    --ansi \
    --layout=reverse \
    --border=rounded \
    --color=border:#27a1b9 \
    --color=fg:#c0caf5 \
    --color=gutter:#16161e \
    --color=header:#ff9e64 \
    --color=hl+:#2ac3de \
    --color=hl:#2ac3de \
    --color=info:#545c7e \
    --color=marker:#ff007c \
    --color=pointer:#ff007c \
    --color=prompt:#2ac3de \
    --color=query:#c0caf5:regular \
    --color=scrollbar:#27a1b9 \
    --color=separator:#ff9e64 \
    --color=spinner:#ff007c \
  "
fi

# -------------------------------------------------------
# Load .shell.env if it exists
# -------------------------------------------------------
if [[ -f "$HOME/.shell.env" ]]; then
  source "$HOME/.shell.env"
fi

# -------------------------------------------------------
# PATH
# -------------------------------------------------------
path=(
  "$HOME/.local/bin"
  "$HOME/.cargo/bin"
  "$HOME/.local/share/go/bin"
  "$HOME/.local/share/neovim/bin"
  "$HOME/.npm-global/bin"
  "$HOME/.foundry/bin"
  "$HOME/go/bin"
  "/usr/local/go/bin"
  "$HOME/flutter/bin"
  "$HOME/.opencode/bin"
  "$HOME/.kilo/bin"
  "$path[@]"
)
export PATH

# -------------------------------------------------------
# Golang
# -------------------------------------------------------
export GOROOT=/usr/local/go
export GOPATH=$HOME/go

# -------------------------------------------------------
# Java
# -------------------------------------------------------
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk

# -------------------------------------------------------
# Zoxide
# -------------------------------------------------------
if [[ -x /usr/bin/zoxide ]]; then
  zoxide_init="$(/usr/bin/zoxide init zsh)"
  zoxide_init="${zoxide_init//\\command zoxide//usr/bin/zoxide}"
  eval "$zoxide_init"
  unset zoxide_init
fi

# -------------------------------------------------------
# Vite+
# -------------------------------------------------------
[[ -f "$HOME/.vite-plus/env" ]] && . "$HOME/.vite-plus/env"

# -------------------------------------------------------
# SSH Alias for Kitty Terminal
# -------------------------------------------------------
if [[ $TERM == "xterm-kitty" ]]; then
  alias ssh="kitty +kitten ssh"
fi

# -------------------------------------------------------
# Ctrl+Space to accept autosuggestions
# -------------------------------------------------------
bindkey '^ ' autosuggest-accept

# -------------------------------------------------------
# Disable paste highlight
# -------------------------------------------------------
zle_highlight=('paste:none')

# -------------------------------------------------------
# Keybinds for zsh-history-substring-search
# -------------------------------------------------------
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

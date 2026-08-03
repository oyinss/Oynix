#!/bin/zsh

# -------------------------------------------------------
# asdf version manager
# -------------------------------------------------------
if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
  . "$HOME/.asdf/asdf.sh"
  fpath=("$HOME/.asdf/completions" $fpath)
fi

# -------------------------------------------------------
# Completion initialization
# -------------------------------------------------------
autoload -Uz compinit && compinit

# -------------------------------------------------------
# Completion styling
# -------------------------------------------------------
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes

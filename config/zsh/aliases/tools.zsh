#!/bin/zsh

# Tool aliases

# lazygit
if [[ -x "$(command -v lazygit)" ]]; then
    alias lg='lazygit'
fi

# Codex Desktop
if [[ -x "$(command -v codex-desktop)" ]]; then
    alias codexm='codex-desktop'
fi

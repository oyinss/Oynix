#!/bin/bash

set -euo pipefail

cat << "EOF"

███ ███ █ █ ██    ███ █ █ ███ █   █ ███ ███
█   █ █ █ █ █ █    █  █ █ █   ██ ██ █   █
█   ██  █ █ ██     █  ███ ███ █ █ █ ███  █
█ █ █ █ █ █ █ █    █  █ █ █   █   █ █     █
███ █ █ ███ ██     █  █ █ ███ █   █ ███ ███

EOF

# ------------------------------------------------------
# Check and create ~/Tmp directory
# ------------------------------------------------------
TMP_DIR="$HOME/Tmp"
if [ ! -d "$TMP_DIR" ]; then
  mkdir "$TMP_DIR"
fi

# ------------------------------------------------------
# Clone or update the grub2-themes repo
# ------------------------------------------------------
REPO_DIR="$TMP_DIR/grub2-themes"

if [ -d "$REPO_DIR/.git" ]; then
  cd "$REPO_DIR"
  git pull --rebase --autostash origin master  # Update the existing version
else
  git clone "https://github.com/vinceliuice/grub2-themes.git" "$REPO_DIR"
  cd "$REPO_DIR"
fi

# ------------------------------------------------------
# Install grub themes
# ------------------------------------------------------
pkexec "$REPO_DIR/install.sh" -b -t tela


#!/bin/bash

# File location: ~/Oynix/backup.sh

set -euo pipefail
IFS=$'\n\t'

# ───────────────────────────────────────────────────────────────
# Config
# ───────────────────────────────────────────────────────────────
BACKUP_DIR="/backup"

# Home of the owner of this script — resolves correctly even when
# systemd runs it as root (where $HOME would be /root).
USER_HOME="$(getent passwd "$(stat -c '%U' "$0")" | cut -d: -f6)"

RSYNC_FLAGS=(-aAXv)

# Directories under the home dir to back up. Only things you can NOT
# re-download from a server go here: personal files, code, dotfiles,
# browser profiles (bookmarks/passwords), email, keys, phone photos.
HOME_DIRS=(
  "$USER_HOME/Documents"
  "$USER_HOME/Pictures"
  "$USER_HOME/DCIM"
  "$USER_HOME/Music"
  "$USER_HOME/Videos"
  "$USER_HOME/Recordings"
  "$USER_HOME/Android"
  "$USER_HOME/Apex"
  "$USER_HOME/Oynix"
  "$USER_HOME/.ssh"
  "$USER_HOME/.shell.env"
  "$USER_HOME/.gnupg"
  "$USER_HOME/.password-store"
  "$USER_HOME/.thunderbird"
  "$USER_HOME/.config/BraveSoftware"   # bookmarks, passwords, history
  "$USER_HOME/.local/share/kwalletd"   # KDE wallet
)

# System dirs that can't be re-downloaded (configs, cron jobs)
SYSTEM_DIRS=(
  "/etc/pacman.d"
  "/etc/fstab"
  "/etc/samba"
  "/var/spool/cron"
)

# Paths to always skip (caches, temp, re-downloadable). These are
# matched anywhere in the tree by rsync's exclude rules.
EXCLUDES=(
  "*/node_modules/"
  "*/vendor/"
  "*/Cache/"
  "*/CachedData/"
  "*/Code Cache/"
  "*/GPUCache/"
  "*/Service Worker/"
  "*/tmp/"
  "*.log"
  "*.sql"
  "*.AppImage"
  "*.mkv"
  "*.mp4"
)

# ───────────────────────────────────────────────────────────────
# Exit if backup partition is not mounted
# ───────────────────────────────────────────────────────────────
if ! mountpoint -q "$BACKUP_DIR"; then
  echo "[✘] Backup directory $BACKUP_DIR is not mounted. Aborting."
  exit 1
fi

# ───────────────────────────────────────────────────────────────
# Stylized banner
# ───────────────────────────────────────────────────────────────
cat << "EOF"
▄▖▄▖▄▖▄▖▄▖  ▄▖▖▖▄▖  ▄ ▄▖▄▖▖▖▖▖▄▖
▚ ▐ ▌▌▙▘▐   ▚ ▌▌▚   ▙▘▌▌▌ ▙▘▌▌▙▌
▄▌▐ ▛▌▌▌▐   ▄▌▐ ▄▌  ▙▘▛▌▙▖▌▌▙▌▌
EOF

# ───────────────────────────────────────────────────────────────
# Build exclude arguments
# ───────────────────────────────────────────────────────────────
EXCLUDE_ARGS=()
for pattern in "${EXCLUDES[@]}"; do
  EXCLUDE_ARGS+=(--exclude="$pattern")
done

# ───────────────────────────────────────────────────────────────
# Collect every directory to back up
# ───────────────────────────────────────────────────────────────
dirs=()
for dir in "${HOME_DIRS[@]}"; do
  if [[ -e "$dir" ]]; then
    dirs+=("$dir")
  else
    echo "[·] Skipping missing $dir"
  fi
done
for dir in "${SYSTEM_DIRS[@]}"; do
  [[ -e "$dir" ]] && dirs+=("$dir")
done

if (( ${#dirs[@]} == 0 )); then
  echo "[✘] No directories to back up."
  exit 1
fi

# ───────────────────────────────────────────────────────────────
# Run the whole backup under a single pkexec (one password prompt).
# Already root (e.g. systemd timer) → run directly, no pkexec.
# ───────────────────────────────────────────────────────────────
printf -v rsync_args '%q ' "${RSYNC_FLAGS[@]}" "${EXCLUDE_ARGS[@]}"

INNER='
  set -e
  BACKUP_DIR=$1
  shift
  rsync_args=$1
  shift
  mkdir -p "$BACKUP_DIR"
  for dir in "$@"; do
    echo "[+] Backing up $dir"
    eval "rsync $rsync_args \"$dir\" \"$BACKUP_DIR\""
  done
'

if [[ $(id -u) -eq 0 ]]; then
  bash -c "$INNER" _ "$BACKUP_DIR" "$rsync_args" "${dirs[@]}"
else
  pkexec bash -c "$INNER" _ "$BACKUP_DIR" "$rsync_args" "${dirs[@]}"
fi

# ───────────────────────────────────────────────────────────────
# Footer
# ───────────────────────────────────────────────────────────────
cat << "EOF"

██  ███ █   █ ███
█ █ █ █ ██  █ █
█ █ █ █ █ █ █ ███
█ █ █ █ █  ██ █
██  ███ █   █ ███

Backup completed successfully.
EOF

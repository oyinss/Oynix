
#!/bin/bash

# File location: ~/Oynix/backup.sh

set -euo pipefail
IFS=$'\n\t'

# ───────────────────────────────────────────────────────────────
# Config
# ───────────────────────────────────────────────────────────────
BACKUP_DIR="/backup"
RSYNC_FLAGS=(-aAXv)

# Directories under $HOME to back up. Only things you can NOT
# re-download from a server go here: personal files, code, dotfiles,
# browser profiles (bookmarks/passwords), email, keys, phone photos.
HOME_DIRS=(
  "$HOME/Documents"
  "$HOME/Pictures"
  "$HOME/DCIM"
  "$HOME/Music"
  "$HOME/Videos"
  "$HOME/Recordings"
  "$HOME/Android"
  "$HOME/Apex"
  "$HOME/Oynix"
  "$HOME/.ssh"
  "$HOME/.shell.env"
  "$HOME/.gnupg"
  "$HOME/.password-store"
  "$HOME/.thunderbird"
  "$HOME/.config/BraveSoftware"   # bookmarks, passwords, history
  "$HOME/.local/share/kwalletd"   # KDE wallet
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
# Ensure backup directory exists
# ───────────────────────────────────────────────────────────────
sudo mkdir -p "$BACKUP_DIR"

# ───────────────────────────────────────────────────────────────
# Build exclude arguments
# ───────────────────────────────────────────────────────────────
EXCLUDE_ARGS=()
for pattern in "${EXCLUDES[@]}"; do
  EXCLUDE_ARGS+=(--exclude="$pattern")
done

# ───────────────────────────────────────────────────────────────
# Backup personal home dirs
# ───────────────────────────────────────────────────────────────
for dir in "${HOME_DIRS[@]}"; do
  if [[ -e "$dir" ]]; then
    echo "[+] Backing up $dir"
    sudo rsync "${RSYNC_FLAGS[@]}" "${EXCLUDE_ARGS[@]}" "$dir" "$BACKUP_DIR"
  else
    echo "[·] Skipping missing $dir"
  fi
done

# ───────────────────────────────────────────────────────────────
# Backup system dirs
# ───────────────────────────────────────────────────────────────
for dir in "${SYSTEM_DIRS[@]}"; do
  if [[ -e "$dir" ]]; then
    echo "[+] Backing up $dir"
    sudo rsync "${RSYNC_FLAGS[@]}" "${EXCLUDE_ARGS[@]}" "$dir" "$BACKUP_DIR"
  fi
done

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

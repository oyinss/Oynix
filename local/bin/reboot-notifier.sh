#!/usr/bin/env bash
set -euo pipefail

# Reboot notifier for Hyprland (root-free).
# Notifies once per boot when an installed kernel is newer than the running one,
# or when the systemd /var/run/reboot-required flag is present.

run_path="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
marker="$run_path/reboot-notifier.done"

is_newer() { # is_newer <installed> <running>  (e.g. "7.1.8.arch1" "7.1.8-arch1-3")
    local installed="$1" running="$2"
    installed="${installed%%-*}"
    running="${running%%-*}"
    # compare dotted numeric segments numerically
    local a b
    read -r -a a <<< "${installed//[^0-9]/ }"
    read -r -a b <<< "${running//[^0-9]/ }"
    for i in 0 1 2; do
        local x="${a[$i]:-0}" y="${b[$i]:-0}"
        (( x > y )) && return 0
        (( x < y )) && return 1
    done
    return 1
}

reboot_needed() {
    [[ -f /var/run/reboot-required ]] && { echo "flag|||"; return 0; }
    local running installed pkg
    running="$(uname -r)"
    for pkg in $(pacman -Qq 2>/dev/null | grep -E '^(linux|linux-lts|linux-zen|linux-hardened)$'); do
        installed="$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')"
        [[ -n "$installed" ]] || continue
        if is_newer "$installed" "$running"; then
            echo "kernel|${pkg}|${installed}|${running}"
            return 0
        fi
    done
    return 1
}

reason="$(reboot_needed || true)"
body="The system needs to restart to finish applying updates."

if [[ "$reason" == kernel\|* ]]; then
    IFS='|' read -r _ pkg installed running <<< "$reason" || true
    body="A newer kernel ($pkg $installed) is installed. Restart to boot into it (running $running)."
fi

if [[ -n "$reason" ]]; then
    # notify only once per boot
    if [[ ! -f "$marker" ]]; then
        : > "$marker"
        notify-send \
            --urgency=critical \
            --app-name="Reboot Notifier" \
            --icon="system-reboot" \
            "Reboot required" \
            "$body"
    fi
fi

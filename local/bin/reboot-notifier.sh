#!/usr/bin/env bash
set -euo pipefail

# Reboot notifier for Hyprland (root-free).
# Notifies once per reason when a kernel update, NVIDIA driver mismatch,
# or /var/run/reboot-required flag requires a restart.

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
    # DKMS updates replace the on-disk driver while the old module stays loaded.
    # Only compare when NVIDIA is loaded and the current kernel's module exists;
    # absent NVIDIA hardware or a failed module lookup must not produce an alert.
    if [[ -r /sys/module/nvidia/version ]] && command -v modinfo >/dev/null 2>&1; then
        running="$(cat /sys/module/nvidia/version)"
        installed="$(modinfo -k "$(uname -r)" -F version nvidia 2>/dev/null || true)"
        if [[ -n "$running" && -n "$installed" && "$installed" != "$running" ]]; then
            echo "nvidia|nvidia|${installed}|${running}"
            return 0
        fi
    fi
    return 1
}

reason="$(reboot_needed || true)"
body="The system needs to restart to finish applying updates."

if [[ "$reason" == kernel\|* ]]; then
    IFS='|' read -r _ pkg installed running <<< "$reason" || true
    body="A newer kernel ($pkg $installed) is installed. Restart to boot into it (running $running)."
elif [[ "$reason" == nvidia\|* ]]; then
    IFS='|' read -r _ pkg installed running <<< "$reason" || true
    body="The NVIDIA driver was updated to $installed, but $running is still loaded. Restart to finish applying the graphics driver update."
fi

if [[ -n "$reason" ]]; then
    # Notify once per reboot reason, not once per boot: another kernel update
    # can arrive before the user restarts. Older empty markers are retried.
    if [[ ! -f "$marker" || "$(< "$marker")" != "$reason" ]]; then
        notify-send \
            --urgency=critical \
            --app-name="Reboot Notifier" \
            --icon="system-reboot" \
            "Reboot required" \
            "$body"
        printf '%s\n' "$reason" > "$marker"
    fi
fi

#!/usr/bin/env bash
# Detect clipboard contents received from a paired KDE Connect phone and
# fire a notification so the user knows a phone clipboard sync landed.
#
# ## Why this exists
#
# KDE Connect's clipboard plugin has no DBus signal and logs nothing on a
# successful incoming clipboard. It only prints "Ignoring clipboard without
# timestamp" for the edge case, so we cannot tail the daemon log or listen on
# a signal. Instead, this daemon correlates two independent events:
#
#   1. The Wayland text clipboard changed (via `wl-paste --type text --watch`).
#   2. The persistent TCP socket between kdeconnectd and the phone received
#      data very recently (`lastrcv` field from `ss -tni` is small).
#
# When both happen within a short window, the change almost certainly came
# from the phone rather than a local copy. It is deliberately best-effort.
#
# ## Usage
#
#   hypr-kdeconnect-clip-notify.sh          # foreground
#   systemd: hypr-kdeconnect-clip-notify.service (graphical-session.target)
#
# Requires: wl-paste (wayland-utils), ss (iproute2), notify-send (libnotify),
# and a reachable paired KDE Connect device over LAN. The phone IP/port are
# auto-detected from `ss` by matching kdeconnectd's established socket.

set -u

RUN_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr-kdeconnect-clip-notify"

mkdir -p "$RUN_DIR"
LOCK="$RUN_DIR/lock"
# Single instance: bail if already running (survives Hyprland reloads).
# Bypassed when invoked as the wl-paste __watch_handler (clipboard event),
# which is handled at the bottom of this script.
if [ "${1:-}" != "__watch_handler" ]; then
    exec 9>"$LOCK"; flock -n 9 || exit 0
fi
echo "$$" > "$RUN_DIR/pid"

# How recently the kdeconnect socket must have received data to attribute a
# clipboard change to the phone (milliseconds). KDE Connect processes the
# received packet and sets the clipboard within tens of milliseconds, so a
# 1500 ms window is generous but still rejects unrelated local copies.
RECV_WINDOW_MS="${HYPR_KC_CLIP_RECV_WINDOW_MS:-1500}"
# Debounce: ignore further events this long after firing (milliseconds).
DEBOUNCE_MS="${HYPR_KC_CLIP_DEBOUNCE_MS:-2000}"
NOTIF_APP_NAME="KDE Connect"
NOTIF_ICON="${HYPR_KC_CLIP_ICON:-phone-sync}"
NOTIF_SUMMARY="Clipboard synced from phone"
# Limit preview length to avoid enormous notifications.
PREVIEW_LEN="${HYPR_KC_CLIP_PREVIEW_LEN:-120}"

now_ms() { date +%s%3N; }

# Resolve the phone's TCP socket block from `ss -tni`.
# Output: the phone-IP connection's "lastrcv:<n>" field, or "-1" if none.
kde_last_rcv_ms() {
    # ss prints one connection line, then an indented metrics line. We want the
    # metrics (lastrcv) for the ESTABLISHED socket connecting to the KDE Connect
    # remote port 1716. We do NOT require "kdeconnectd" on the conn line: the
    # users() field is only present when ss has the needed privileges, and the
    # remote :1716 endpoint is specific enough.
    ss -tni 2>/dev/null | awk '
        /^ESTAB/ { have_kde=($0 ~ /:1716$/) }
        /^[[:space:]]/ && have_kde {
            for (i=1; i<=NF; i++) if ($i ~ /^lastrcv:/) {
                v=$i; sub(/^lastrcv:/,"",v); print v; exit
            }
        }
    '
}

fire_notification() {
    local content preview
    content="$(wl-paste --type text 2>/dev/null)"
    if [ -z "$content" ]; then
        preview="(empty)"
    else
        # Collapse newlines/tabs, trim, clamp length.
        preview="$(printf '%s' "$content" | tr '\t\n' '  ' | sed -E 's/  +/ /g; s/(^ | $)//g')"
        if [ "${#preview}" -gt "$PREVIEW_LEN" ]; then
            preview="${preview:0:$PREVIEW_LEN}…"
        fi
    fi
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "$NOTIF_APP_NAME" -i "$NOTIF_ICON" -t 4000 \
            -- "$NOTIF_SUMMARY" "$preview" >/dev/null 2>&1 && return 0
    fi
    # Fallback to swaync if notify-send is absent or fails.
    if command -v swaync-client >/dev/null 2>&1; then
        swaync-client -tw -a "$NOTIF_APP_NAME" -i "$NOTIF_ICON" \
            -- "$NOTIF_SUMMARY" "$preview" >/dev/null 2>&1 || true
    fi
}

# Called by wl-paste --watch on every text clipboard change.
on_clip_change() {
    local data; data="$1"
    local now recv_ms last_fire
    now="$(now_ms)"

    recv_ms="$(kde_last_rcv_ms)"
    [ -z "$recv_ms" ] && recv_ms=-1

    # Persistent debounce: last-fire time is stored in a file because each
    # wl-paste --watch event re-execs this script as a fresh process, so an
    # in-memory variable would reset to 0 on every call.
    last_fire="${RUN_DIR}/last_fire_ms"
    if [ -f "$last_fire" ]; then
        if [ "$((now - $(cat "$last_fire" 2>/dev/null || echo 0)))" -lt "$DEBOUNCE_MS" ]; then
            return 0
        fi
    fi

    # -1 means no kdeconnect socket right now: definitely not from the phone.
    if [ "$recv_ms" -lt 0 ] || [ "$recv_ms" -gt "$RECV_WINDOW_MS" ]; then
        return 0
    fi

    fire_notification
    printf '%s' "$now" > "$last_fire"
}

# Main: start the text clipboard watch. Each event re-execs this script, which
# is cheaper than a long-lived awker and avoids races.
#
# Trampoline: wl-paste --watch invokes us with "__watch_handler" on every
# change and pipes the new content on stdin. Because all helper functions and
# config vars are defined above, this can live here; the single-instance flock
# is deliberately bypassed so the handler never bails on the main daemon's lock.
if [ "${1:-}" = "__watch_handler" ]; then
    on_clip_change "$(cat)" </dev/null
    exit 0
fi

exec wl-paste --type text --watch "$0" __watch_handler
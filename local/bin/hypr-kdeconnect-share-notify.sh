#!/usr/bin/env bash
# Fire a notification when a link/text is received from a paired KDE Connect
# phone via the Share plugin (e.g. "Share -> open in browser").
#
# Unlike clipboard sync, KDE Connect's Share plugin exposes a proper DBus
# signal: org.kde.kdeconnect.device.share.shareReceived(url). We subscribe to
# it with `gdbus monitor` and post a notify-send / swaync notification.
#
# Usage:
#   hypr-kdeconnect-share-notify.sh                # foreground / systemd
#
# Requires: gdbus (glib2), notify-send (libnotify), a paired+reachable phone.

set -u

RUN_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr-kdeconnect-share-notify"
mkdir -p "$RUN_DIR"
LOCK="$RUN_DIR/lock"
# Single instance (survives Hyprland reloads / systemd restarts).
exec 9>"$LOCK"; flock -n 9 || exit 0
echo "$$" > "$RUN_DIR/pid"

NOTIF_APP_NAME="KDE Connect"
NOTIF_ICON="${HYPR_KC_SHARE_ICON:-emblem-shared}"
NOTIF_SUMMARY="Link shared from phone"
PREVIEW_LEN="${HYPR_KC_SHARE_PREVIEW_LEN:-160}"
# Hyprland window class of the default browser, focused after a link arrives.
# Override with HYPR_KC_SHARE_BROWSER_CLASS if your browser differs.
BROWSER_CLASS="${HYPR_KC_SHARE_BROWSER_CLASS:-brave-browser}"

# KDE Connect daemon's session bus name. The share object path is
# /modules/kdeconnect/devices/<deviceId>/share; the device ID is resolved at
# runtime from the first paired+reachable phone.
daemon="org.kde.kdeconnect"

device_share_path() {
    # `kdeconnect-cli --list-devices` prints lines like:
    #   - Name: abc123_... on 192.168.x.y via LAN (paired and reachable)
    # The first token after the colon is the device ID.
    local dev
    dev="$(kdeconnect-cli --list-devices 2>/dev/null | awk -F': ' '/paired/ && !dev {print $2; dev=1}' | cut -d' ' -f1)"
    [ -n "$dev" ] && printf '%s' "/modules/kdeconnect/devices/$dev/share"
}

# Focus the default browser window in Hyprland. This build's `hyprctl dispatch`
# evaluates Lua, so we pass the whole focus call as one quoted expression and
# resolve the browser's current window address from `hyprctl clients`.
focus_browser() {
    [ -z "$BROWSER_CLASS" ] && return 0
    if ! command -v hyprctl >/dev/null 2>&1; then
        return 0
    fi
    local addr
    addr="$(hyprctl clients -j 2>/dev/null \
        | jq -r --arg cls "$BROWSER_CLASS" '.[] | select(.class==$cls) | .address' \
        | head -1)"
    [ -z "$addr" ] && return 0
    hyprctl dispatch "hl.dsp.focus({ window = \"address:${addr}\" })" >/dev/null 2>&1
}

notify_link() {
    local raw url preview
    raw="$1"
    # gdbus monitor output looks like:
    #   /modules/kdeconnect/devices/<id>/share: org.kde.kdeconnect.device.share.shareReceived ('https://…',)
    # Extract the URL between the quotes (handle the quoted-string form).
    url="$(printf '%s' "$raw" | grep -oE "shareReceived \('[^']*'" | sed "s/.*('//; s/'$//")"
    [ -z "$url" ] && url="$raw"
    # Clamp for the notification body.
    if [ "${#url}" -gt "$PREVIEW_LEN" ]; then
        preview="${url:0:$PREVIEW_LEN}…"
    else
        preview="$url"
    fi
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "$NOTIF_APP_NAME" -i "$NOTIF_ICON" -t 5000 \
            -- "$NOTIF_SUMMARY" "$preview" >/dev/null 2>&1 && return 0
    fi
    if command -v swaync-client >/dev/null 2>&1; then
        swaync-client -tw -a "$NOTIF_APP_NAME" -i "$NOTIF_ICON" \
            -- "$NOTIF_SUMMARY" "$preview" >/dev/null 2>&1 || true
    fi
}

path="$(device_share_path)"
if [ -z "$path" ]; then
    echo "no reachable paired KDE Connect device with a share plugin found" >&2
    exit 1
fi

# Continuously monitor the share signal. Each line matching shareReceived is a
# share from the phone; notify and (optionally) read the next line's payload.
gdbus monitor --session --dest "$daemon" --object-path "$path" 2>/dev/null | \
while IFS= read -r line; do
    case "$line" in
        *shareReceived*)
            notify_link "$line"
            # Focus the browser only when the share looks like a URL link,
            # not plain text.
            if printf '%s' "$line" | grep -qE "shareReceived \('https?://"; then
                focus_browser
            fi
            ;;
    esac
done
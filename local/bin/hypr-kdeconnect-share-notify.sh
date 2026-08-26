#!/usr/bin/env bash
# Fire a notification when something is shared from a paired KDE Connect
# phone:
#
#   - links  -> "Link shared from phone" (+ browser focus)
#   - files  -> "File received from phone" with the full path as body,
#               "Copy path" / "Open" action buttons, and an image thumbnail
#               for images
#
# KDE Connect's Share plugin exposes one DBus signal for both:
# org.kde.kdeconnect.device.share.shareReceived(url). For file transfers the
# daemon emits it on transfer completion with the saved file's file:// URL
# (see SharePlugin::finished in shareplugin.cpp). We subscribe with
# `gdbus monitor` and branch on the URL scheme.
#
# Usage:
#   hypr-kdeconnect-share-notify.sh                       # foreground / systemd
#   hypr-kdeconnect-share-notify.sh __handle '<gdbus line>'  # test one event
#
# Requires: gdbus (glib2), notify-send (libnotify), a paired+reachable phone.

set -u

RUN_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr-kdeconnect-share-notify"
mkdir -p "$RUN_DIR"
LOCK="$RUN_DIR/lock"
# Single instance (survives Hyprland reloads / systemd restarts). Bypassed in
# __handle test mode so the handler never bails on the main daemon's lock.
if [ "${1:-}" != "__handle" ]; then
    exec 9>"$LOCK"; flock -n 9 || exit 0
fi
echo "$$" > "$RUN_DIR/pid"

NOTIF_APP_NAME="KDE Connect"
NOTIF_ICON="${HYPR_KC_SHARE_ICON:-emblem-shared}"
LINK_SUMMARY="Link shared from phone"
FILE_SUMMARY="File received from phone"
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

# Extract the URL from a gdbus monitor signal line:
#   /modules/kdeconnect/devices/<id>/share: org.kde.kdeconnect.device.share.shareReceived ('<url>',)
# NOTE: filenames containing a single quote would truncate the match (rare).
signal_url() {
    printf '%s' "$1" | grep -oE "shareReceived \('[^']*'" | sed "s/.*('//; s/'$//"
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

send_notify() {
    local icon="$1" summary="$2" body="$3"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "$NOTIF_APP_NAME" -i "$icon" -t 6000 \
            -- "$summary" "$body" >/dev/null 2>&1 && return 0
    fi
    if command -v swaync-client >/dev/null 2>&1; then
        swaync-client -tw -a "$NOTIF_APP_NAME" -i "$icon" \
            -- "$summary" "$body" >/dev/null 2>&1 || true
    fi
}

copy_image_to_clipboard() {
    local path="$1" mime="$2" unit
    unit="kdeconnect-image-clipboard-$(date +%s%N)"

    if command -v magick >/dev/null 2>&1; then
        systemd-run --user --quiet --collect --unit="$unit" \
            bash -c 'magick "$1" png:- 2>/dev/null | wl-copy --foreground --type image/png' _ "$path"
    else
        systemd-run --user --quiet --collect --unit="$unit" \
            bash -c 'wl-copy --foreground --type "$1" < "$2"' _ "$mime" "$path"
    fi
}

notify_file() {
    local url="$1" path icon mime action summary
    # QUrl::toString() keeps paths mostly decoded; unquote any leftover %XX.
    path="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1], errors="replace"))' \
        "${url#file://}" 2>/dev/null || printf '%s' "${url#file://}")"
    # Images get a real thumbnail as the notification image.
    icon="$NOTIF_ICON"
    summary="$FILE_SUMMARY"
    mime="$(file -b --mime-type -- "$path" 2>/dev/null)"
    case "$mime" in
        image/*)
            if [ -f "$path" ]; then
                icon="$path"
                summary="Image received and copied"
                copy_image_to_clipboard "$path" "$mime"
            fi
            ;;
    esac

    # Body is the full path so the panel's built-in copy button copies
    # something useful. Action buttons provide one-click copy/open; clicking
    # one makes notify-send return early with the chosen key.
    action="$(notify-send -a "$NOTIF_APP_NAME" -i "$icon" -t 8000 \
        -A "copyPath=Copy path" -A "open=Open" \
        -- "$summary" "$path" 2>/dev/null)"

    case "$action" in
        copyPath)
            printf '%s' "$path" | wl-copy
            ;;
        open)
            xdg-open "$path" >/dev/null 2>&1 &
            ;;
    esac
}

notify_link() {
    local url preview
    url="$1"
    if [ "${#url}" -gt "$PREVIEW_LEN" ]; then
        preview="${url:0:$PREVIEW_LEN}…"
    else
        preview="$url"
    fi
    send_notify "$NOTIF_ICON" "$LINK_SUMMARY" "$preview"
}

handle_share() {
    local raw url
    raw="$1"
    url="$(signal_url "$raw")"
    [ -z "$url" ] && url="$raw"

    case "$url" in
        file://*)
            notify_file "$url"
            ;;
        https://* | http://*)
            notify_link "$url"
            focus_browser
            ;;
        *)
            # Text shares and action-triggered emissions: announce as link-ish.
            notify_link "$url"
            ;;
    esac
}

# Test hook: process one gdbus monitor line without touching the daemon lock.
if [ "${1:-}" = "__handle" ]; then
    handle_share "${2:-}"
    exit 0
fi

path="$(device_share_path)"
if [ -z "$path" ]; then
    echo "no reachable paired KDE Connect device with a share plugin found" >&2
    exit 1
fi

# Continuously monitor the share signal. Each shareReceived line is one share
# from the phone (link or completed file transfer).
gdbus monitor --session --dest "$daemon" --object-path "$path" 2>/dev/null | \
while IFS= read -r line; do
    case "$line" in
        *shareReceived*)
            handle_share "$line"
            ;;
    esac
done

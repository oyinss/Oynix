#!/usr/bin/env bash
# Surface new local PISOL OTPs as desktop notifications and auto-copy the code
# to the Wayland clipboard. They land in the Quickshell notification center,
# whose copy button also puts the code on the clipboard. The notification body
# is the code alone.
#
# Source of truth: the plaintext dev OTP log written by the local backend
# (see `_pisol_show_local_otp` in config/zsh/extensions/pisol.zsh). Tailing
# starts at EOF, so codes from earlier sessions are never replayed.

set -u

ROOT="${PISOL_ROOT:-$HOME/Apex/primordial/pisol}"
LOG="${PISOL_OTP_LOG:-$ROOT/.dsh-artifacts/otp_codes.log}"

# systemd --user exports XDG_RUNTIME_DIR and the session bus, but not
# WAYLAND_DISPLAY. This service therefore inherits libwayland's default of
# `wayland-0` while the live socket is `wayland-1`, so wl-copy refuses to
# connect and the code never reaches the clipboard. Resolving here also covers
# a service that starts before the compositor creates its socket: this runs at
# copy time, not once at startup. Prefer the inherited display when it is live.
resolve_wayland_display() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    local socket_path

    if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "$runtime_dir/$WAYLAND_DISPLAY" ]; then
        return 0
    fi

    for socket_path in "$runtime_dir"/wayland-*; do
        [ -S "$socket_path" ] || continue
        WAYLAND_DISPLAY="${socket_path##*/}"
        export WAYLAND_DISPLAY
        return 0
    done

    return 1
}

tail -n 0 -F -- "$LOG" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *"[PISOL local BVN email OTP]"*) kind="bvn_email" ;;
        *"[PISOL local BVN SMS OTP]"*)   kind="bvn_sms" ;;
        *"[PISOL local email OTP]"*) kind="email" ;;
        *"[PISOL local OTP]"*)       kind="phone" ;;
        *) continue ;;
    esac

    code="${line##*: }"
    [ -n "$code" ] || continue

    account="${line%: *}"
    account="${account##*] }"

    if [ "$kind" = "bvn_email" ]; then
        summary="PISOL test BVN email OTP"
    elif [ "$kind" = "bvn_sms" ]; then
        summary="PISOL test BVN SMS OTP"
    elif [ "$kind" = "email" ]; then
        summary="PISOL email OTP"
    else
        summary="PISOL OTP"
    fi
    [ -n "$account" ] && summary="$summary ($account)"

    if command -v wl-copy >/dev/null 2>&1; then
        if ! resolve_wayland_display; then
            printf 'pisol-otp-notify: no Wayland socket under %s; skipped clipboard copy\n' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" >&2
        elif ! printf '%s' "$code" | wl-copy >/dev/null 2>&1; then
            printf 'pisol-otp-notify: wl-copy failed (WAYLAND_DISPLAY=%s)\n' "$WAYLAND_DISPLAY" >&2
        fi
    fi

    notify-send -a "PISOL" -i "dialog-password" -u normal -- "$summary" "$code" >/dev/null 2>&1 || true
done

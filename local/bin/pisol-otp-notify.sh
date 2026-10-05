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

tail -n 0 -F -- "$LOG" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *"[PISOL local email OTP]"*) kind="email" ;;
        *"[PISOL local OTP]"*)       kind="phone" ;;
        *) continue ;;
    esac

    code="${line##*: }"
    [ -n "$code" ] || continue

    account="${line%: *}"
    account="${account##*] }"

    if [ "$kind" = "email" ]; then
        summary="PISOL email OTP"
    else
        summary="PISOL OTP"
    fi
    [ -n "$account" ] && summary="$summary ($account)"

    if command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$code" | wl-copy >/dev/null 2>&1 || true
    fi

    notify-send -a "PISOL" -i "dialog-password" -u normal -- "$summary" "$code" >/dev/null 2>&1 || true
done

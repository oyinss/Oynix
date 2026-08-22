#!/usr/bin/env bash

# Rofi script mode for listing and focusing native Hyprland windows.
set -u

readonly dir="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/launchers"
readonly theme="$dir/clipboard.rasi"

# Icon-theme search roots. Includes the active GTK icon theme plus every
# other installed theme (and hicolor), so an icon is found even when the
# active theme lacks it but a sibling theme provides it. Used to verify that a
# candidate icon actually exists before reporting it.
_icon_roots() {
    local root theme
    for root in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons /usr/share/pixmaps; do
        if [[ -d "$root" ]]; then
            for theme in "$root"/*/; do
                [[ -f "$theme/index.theme" ]] && echo "${theme%/}"
            done
        fi
    done
    echo /usr/share/icons/hicolor
}

# Explicit class -> icon-name mappings for apps whose window class does not
# match any installed icon name. Verified against the search roots below.
_icon_map() {
    case "${1:-}" in
        brave-browser) echo "brave-desktop" ;;
        brave)         echo "brave-desktop" ;;
        codium)        echo "vscodium" ;;
        Enpass|enpass) echo "enpass" ;;
        *) return 1 ;;
    esac
}

# Map a window class to an icon-theme name so more windows show an icon.
# Resolution order: explicit mapping, exact class (rofi/GTK resolve org.* apps
# like org.gnome.Nautilus / org.kde.dolphin via hicolor), a normalized
# lowercased form, a canonical file-manager icon, then a generic fallback.
# Each candidate is verified to actually exist in the search roots.
_icon_name() {
    local c="${1:-}" norm candidate mapped exists
    c="${c//\//-}"
    c="${c%-float}"
    c="${c%-wayland}"
    [[ -n "$c" ]] || c="application-x-executable"

    norm="${c,,}"
    norm="${norm//[^a-zA-Z0-9._+-]/-}"

    for candidate in "$(_icon_map "$c")" "$c" "$norm"; do
        [[ -n "$candidate" ]] || continue
        exists=$(for root in $(_icon_roots); do
            [[ -d "$root" ]] && find "$root" -iname "${candidate}.*" -print -quit 2>/dev/null
        done | head -n 1)
        if [[ -n "$exists" ]]; then
            echo "$candidate"
            return
        fi
    done

    case "${norm}" in
        *nautilus*|*dolphin*|*filemanager*|*file-manager*|*explorer*) echo "system-file-manager"; return ;;
    esac

    echo "application-x-executable"
}

list_windows() {
    hyprctl clients -j 2>/dev/null \
        | jq -r '.[] | select(.mapped == true) | [.address, .title, .class, .workspace.name] | @tsv' \
        | while IFS=$'\t' read -r address title class workspace; do
            [[ -n "$title" ]] || title="Untitled"
            [[ -n "$class" ]] || class="Unknown"
            printf '%s  [%s]  (%s)\0info\x1f%s\x1ficon\x1f%s\n' \
                "$title" "$class" "$workspace" "$address" "$(_icon_name "$class")"
        done
}

activate_window() {
    local window_address="$1"
    [[ "$window_address" =~ ^0x[0-9a-fA-F]+$ ]] || return 1

    local target_workspace open_special special_name
    target_workspace=$(hyprctl clients -j 2>/dev/null \
        | jq -r --arg address "$window_address" \
            '.[] | select(.address == $address) | .workspace.name' \
        | head -n 1)

    # A visible special workspace sits above the normal workspace. Hide it
    # before focusing a normal window, otherwise the target receives focus
    # underneath the still-visible special workspace.
    if [[ "$target_workspace" != special:* ]]; then
        open_special=$(hyprctl monitors -j 2>/dev/null \
            | jq -r '.[] | select(.focused == true) | .specialWorkspace.name // empty' \
            | head -n 1)
        special_name=${open_special#special:}
        if [[ "$open_special" == special:* && "$special_name" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
            hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$special_name\")" >/dev/null
        fi
    fi

    hyprctl dispatch "hl.dsp.focus({ window = \"address:$window_address\" })" >/dev/null
}

show_window_menu() {
    local -a addresses entries icons
    local address title class workspace selected_index index

    while IFS=$'\t' read -r address title class workspace; do
        [[ -n "$address" ]] || continue
        [[ -n "$title" ]] || title="Untitled"
        [[ -n "$class" ]] || class="Unknown"
        addresses+=("$address")
        entries+=("$title  [$class]  ($workspace)")
        icons+=("$(_icon_name "$class")")
    done < <(
        hyprctl clients -j 2>/dev/null \
            | jq -r '.[] | select(.mapped == true) | [.address, .title, .class, .workspace.name] | @tsv'
    )

    ((${#entries[@]} > 0)) || return 0

    # Returning the selected row index is reliable for both keyboard and mouse.
    # Rofi exits before activate_window runs, preventing its focus restoration
    # from overriding the selected Hyprland window.
    selected_index=$(
        for index in "${!entries[@]}"; do
            printf '%s\0icon\x1f%s\n' "${entries[$index]}" "${icons[$index]}"
        done | rofi -dmenu -i -show-icons -format i -p "Windows" -theme "$theme"
    ) || return 0

    [[ "$selected_index" =~ ^[0-9]+$ ]] || return 0
    ((selected_index < ${#addresses[@]})) || return 0
    activate_window "${addresses[$selected_index]}"
}

case "${ROFI_RETV:-standalone}" in
    0) list_windows ;;
    1) activate_window "${ROFI_INFO:-}" ;;
    2|3) exit 0 ;;
    standalone)
        show_window_menu
        ;;
esac

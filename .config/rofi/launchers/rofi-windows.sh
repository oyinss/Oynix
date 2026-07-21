#!/usr/bin/env bash

# Rofi script mode for listing and focusing native Hyprland windows.
set -u

readonly dir="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/launchers"
readonly theme="$dir/launcher.rasi"

list_windows() {
    hyprctl clients -j 2>/dev/null \
        | jq -r '.[] | select(.mapped == true) | [.address, .title, .class, .workspace.name] | @tsv' \
        | while IFS=$'\t' read -r address title class workspace; do
            [[ -n "$title" ]] || title="Untitled"
            [[ -n "$class" ]] || class="Unknown"
            printf '%s  [%s]  (%s)\0info\x1f%s\x1ficon\x1f%s\n' \
                "$title" "$class" "$workspace" "$address" "$class"
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
        icons+=("$class")
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

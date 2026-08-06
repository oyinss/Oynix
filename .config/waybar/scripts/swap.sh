#!/bin/bash

# The module layout stays in config.jsonc; only the visual theme is swapped.
style_file="${HOME}/.config/waybar/style.css"
style_background_file="${HOME}/.config/waybar/style-background.css"

# Swap names of style files
mv "${style_file}" "${style_file}.temp"
mv "${style_background_file}" "${style_file}"
mv "${style_file}.temp" "${style_background_file}"

echo "Waybar style swapped successfully!"

# Reload Waybar after swapping its configuration and stylesheet. SIGUSR2 is
# Waybar's native reload signal, so the process stays alive on Hyprland.
pkill -USR2 -x waybar

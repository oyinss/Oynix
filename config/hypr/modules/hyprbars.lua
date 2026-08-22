-- Shared macOS-style controls for every Hyprland window.
-- Requires the hyprbars plugin from hyprland-plugins.

-- The plugin namespace is absent until hyprpm has loaded hyprbars.
if hl.plugin and hl.plugin.hyprbars then

hl.config({
    plugin = {
        hyprbars = {
            enabled = true,
            bar_height = 24,
            bar_color = "rgba(16161dff)",
            col = { text = "rgba(c0caf5ff)" },
            bar_text_size = 10,
            bar_text_align = "left",
            bar_buttons_alignment = "left",
            bar_part_of_window = true,
            bar_precedence_over_border = true,
            bar_padding = 8,
            bar_button_padding = 5,
            on_double_click = "hyprctl dispatch fullscreen 1",
        },
    },
})

if hl.plugin.hyprbars.add_button then
    -- Buttons are declared right-to-left by hyprbars.
    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(61c554)",
        fg_color = "rgb(16161d)",
        size = 11,
        icon = "+",
        action = "hyprctl dispatch fullscreen 1",
    })

    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(f5bf4f)",
        fg_color = "rgb(16161d)",
        size = 11,
        icon = "-",
        action = "hyprctl dispatch togglefloating",
    })

    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(ed6a5e)",
        fg_color = "rgb(16161d)",
        size = 11,
        icon = "x",
        action = "hyprctl dispatch killactive",
    })
end

end

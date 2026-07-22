---------------------
---- KEYBINDINGS ----
---------------------

-- See https://wiki.hypr.land/Configuring/Basics/Binds/

local programs = require("modules.programs")
local main_mod = "SUPER"

hl.bind(main_mod .. " + Q", hl.dsp.window.close())
hl.bind(main_mod .. " + C", hl.dsp.exec_cmd(programs.terminal))
hl.bind(
	main_mod .. " + M",
	hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
)
hl.bind(main_mod .. " + E", hl.dsp.exec_cmd(programs.file_manager))
hl.bind(main_mod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(main_mod .. " + F", hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }))
hl.bind(main_mod .. " + A", hl.dsp.exec_cmd(programs.application_menu))
hl.bind(main_mod .. " + W", hl.dsp.exec_cmd(programs.window_menu))
hl.bind(main_mod .. " + P", hl.dsp.window.pseudo())
hl.bind(main_mod .. " + J", hl.dsp.layout("togglesplit"))

hl.bind(main_mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(main_mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(main_mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(main_mod .. " + down", hl.dsp.focus({ direction = "down" }))

--------------------------
---- SCROLLING LAYOUT ----
--------------------------

-- Navigate between columns while keeping the focused column in view.
hl.bind(main_mod .. " + H", hl.dsp.layout("focus l"), { description = "Focus scrolling column left" })
hl.bind(main_mod .. " + L", hl.dsp.layout("focus r"), { description = "Focus scrolling column right" })

-- Reorder the current column.
hl.bind(main_mod .. " + SHIFT + H", hl.dsp.layout("swapcol l"), { description = "Swap scrolling column left" })
hl.bind(main_mod .. " + SHIFT + L", hl.dsp.layout("swapcol r"), { description = "Swap scrolling column right" })

-- Move the scrolling viewport without changing focus.
hl.bind(main_mod .. " + comma", hl.dsp.layout("move -col"), { description = "Scroll viewport left" })
hl.bind(main_mod .. " + period", hl.dsp.layout("move +col"), { description = "Scroll viewport right" })

-- Cycle the current column through the configured width presets.
hl.bind(main_mod .. " + bracketleft", hl.dsp.layout("colresize -conf"), { description = "Previous column width" })
hl.bind(main_mod .. " + bracketright", hl.dsp.layout("colresize +conf"), { description = "Next column width" })

-- Fit columns into view and place the active window in its own column.
hl.bind(main_mod .. " + O", hl.dsp.layout("fit active"), { description = "Fit active scrolling column" })
hl.bind(main_mod .. " + SHIFT + O", hl.dsp.layout("fit all"), { description = "Fit all scrolling columns" })
hl.bind(main_mod .. " + G", hl.dsp.layout("promote"), { description = "Promote window to its own column" })
hl.bind(
	main_mod .. " + SHIFT + G",
	hl.dsp.layout("consume_or_expel prev"),
	{ description = "Consume or expel window from column" }
)

for i = 1, 10 do
	local key = i % 10
	hl.bind(main_mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(main_mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(main_mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-----------------------
---- SCREENSHOTS ----
-----------------------

hl.bind(
	"SHIFT + Print",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh full"),
	{ description = "Screenshot full screen" }
)

hl.bind(
	"Print",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh region"),
	{ description = "Screenshot region" }
)

hl.bind(
	"CTRL + Print",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh window"),
	{ description = "Screenshot active window" }
)

hl.bind(
	"SUPER + V",
	hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"),
	{ description = "Clipboard history" }
)

hl.bind(
	"SUPER + N",
	hl.dsp.exec_cmd("swaync-client -t -sw"),
	{ description = "Notification panel" }
)

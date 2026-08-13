-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
	hl.exec_cmd("/usr/lib/hyprpolkitagent")
	hl.exec_cmd("swaybg -i $HOME/Pictures/Wallpaper/wallpaper-008.jpg -m fill")
	hl.exec_cmd("waybar > /dev/null 2>&1")
	hl.exec_once("swaync -s $HOME/.config/swaync/style.css")
	-- clipboard watcher + manager: start directly since graphical-session.target
	-- refuses manual activation under plain Hyprland (no uwsm).
	hl.exec_cmd("systemctl --user start hypr-clip-watcher.service 2>/dev/null")
	hl.exec_cmd("systemctl --user start hypr-clipboard-manager.service 2>/dev/null")
	hl.exec_cmd("systemctl --user stop drkonqi-coredump-processor.service 2>/dev/null; systemctl --user stop drkonqi-coredump-launcher.service 2>/dev/null; killall drkonqi 2>/dev/null")
	hl.exec_cmd("fdm > /dev/null 2>&1")
	hl.exec_once("hypridle")
end)

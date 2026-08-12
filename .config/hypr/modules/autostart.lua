-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
	hl.exec_cmd("/usr/lib/hyprpolkitagent")
	hl.exec_cmd("swaybg -i $HOME/Pictures/Wallpaper/wallpaper-008.jpg -m fill")
	hl.exec_cmd("waybar > /dev/null 2>&1")
	hl.exec_once("swaync -s $HOME/.config/swaync/style.css")
	-- This login uses the plain Hyprland session (start-hyprland), not uwsm,
	-- so systemd's graphical-session.target is never activated on its own.
	-- Start it explicitly: it pulls in hypr-clip-watcher.service (and other
	-- graphical-session services), so clipboard history is stored at login.
	hl.exec_cmd("systemctl --user start graphical-session.target 2>/dev/null")
	hl.exec_cmd("systemctl --user stop drkonqi-coredump-processor.service 2>/dev/null; systemctl --user stop drkonqi-coredump-launcher.service 2>/dev/null; killall drkonqi 2>/dev/null")
	hl.exec_cmd("fdm > /dev/null 2>&1")
end)

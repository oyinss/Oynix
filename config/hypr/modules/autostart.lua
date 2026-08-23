-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
	-- Run the packaged user service so privileged GUI apps launched from Rofi
	-- (for example Timeshift) always have a Polkit authentication agent.
	hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
	hl.exec_cmd("swaybg -i $HOME/Pictures/Wallpaper/wallpaper-008.jpg -m fill")
	-- Quickshell (ii) supplies the bar; see hyprland/execs.lua for the actual launch.
	-- swaync is a systemd user unit (swaync.service) with Restart=on-failure,
	-- so it starts at login and auto-recovers without relying on exec-once.
	hl.exec_cmd("systemctl --user start swaync.service 2>/dev/null")
	hl.exec_cmd("systemctl --user stop drkonqi-coredump-processor.service 2>/dev/null; systemctl --user stop drkonqi-coredump-launcher.service 2>/dev/null; killall drkonqi 2>/dev/null")
	hl.exec_cmd("fdm > /dev/null 2>&1")
	hl.exec_once("hypridle")
end)

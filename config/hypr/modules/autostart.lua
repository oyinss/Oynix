-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
	-- Run the packaged user service so privileged GUI apps always have a
	-- Polkit authentication agent (for example Timeshift).
	hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
	hl.exec_cmd("swaybg -i $HOME/Pictures/Wallpaper/wallpaper-008.jpg -m fill")
	-- Quickshell (ii) supplies the bar and notifications; see hyprland/execs.lua for the actual launch.
	hl.exec_cmd("systemctl --user stop drkonqi-coredump-processor.service 2>/dev/null; systemctl --user stop drkonqi-coredump-launcher.service 2>/dev/null; killall drkonqi 2>/dev/null")
	hl.exec_cmd("fdm > /dev/null 2>&1")
	hl.exec_once("hypridle")
end)

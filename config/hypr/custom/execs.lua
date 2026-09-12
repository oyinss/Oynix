-- User startup commands. Loaded after hyprland/execs.lua.

hl.on("hyprland.start", function ()
    -- GTK 4.22 (GNOME 50) turned off primary-selection paste by default, which
    -- silently breaks middle-click paste in GTK apps such as Ghostty.
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-enable-primary-paste true")
end)

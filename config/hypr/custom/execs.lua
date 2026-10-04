-- User startup commands. Loaded after hyprland/execs.lua.

hl.on("hyprland.start", function ()
    -- GTK 4.22 (GNOME 50) turned off primary-selection paste by default, which
    -- silently breaks middle-click paste in GTK apps such as Ghostty.
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-enable-primary-paste true")

    -- KDE Connect daemon (config/systemd/user/kdeconnectd.service). It is
    -- enabled for default.target so it comes up at login, but the Wayland
    -- environment only reaches the user manager once hyprland/execs.lua pushes
    -- it there, so restart it afterwards to give kdeconnectd WAYLAND_DISPLAY —
    -- without that its clipboard plugin cannot talk to the compositor.
    hl.exec_cmd("sleep 2 && systemctl --user restart kdeconnectd.service")
end)

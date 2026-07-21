-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

--------------------------
---- TOOLKIT BACKENDS ----
--------------------------

-- Prefer native Wayland backends while retaining an X11 fallback where the
-- toolkit supports one. Remove SDL_VIDEODRIVER for older SDL games that need X11.
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

--------------------
---- GTK THEMES ----
--------------------

hl.env("GTK_THEME", "Breeze-Dark")
hl.env("GTK_ICON_THEME", "breeze-dark")

----------------------------
---- XDG SPECIFICATIONS ----
----------------------------

-- Explicit desktop identity helps portals and desktop-aware applications
-- select their Hyprland/Wayland implementations reliably.
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

----------------------
---- QT VARIABLES ----
----------------------

hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-------------------------
---- HYBRID GRAPHICS ----
-------------------------

-- Prefer the Intel iGPU for the compositor and battery life, while keeping the
-- NVIDIA RTX 2060 available for external outputs and explicit `prime-run` offload.
-- Stable PCI paths avoid relying on card numbers that can change between boots.
-- Let Hyprland auto-detect the DRM devices. The stable PCI by-path names
-- contain colons, which AQ_DRM_DEVICES interprets as device separators.
-- hl.env(
-- 	"AQ_DRM_DEVICES",
-- 	"/dev/dri/by-path/pci-0000:00:02.0-card:/dev/dri/by-path/pci-0000:01:00.0-card"
-- )

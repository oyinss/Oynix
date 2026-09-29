------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

local external_output = "HDMI-A-1"
local internal_output = "eDP-1"

local function enable_internal_display()
	hl.monitor({
		output = internal_output,
		mode = "preferred",
		position = "0x0",
		scale = 1,
		-- Must be explicit: omitted fields are merged into the existing rule,
		-- so a previously applied `disabled = true` would otherwise persist.
		disabled = false,
	})
end

local function disable_internal_display()
	hl.monitor({ output = internal_output, disabled = true })
end

-- Use the external monitor alone whenever it is connected.
-- `preferred` = the display's own native timing (the LG TV's 3840x2160@60),
-- so the panel isn't fed an upscaled 1080p signal. A hardcoded lower mode
-- makes text/UI soft on any 4K display plugged into this port.
hl.monitor({
	output = external_output,
	mode = "preferred",
	-- Let Hyprland place HDMI safely while both outputs briefly coexist
	-- during hot-plug. It will settle at 0x0 in external-only mode.
	position = "auto",
	scale = 1,
})

-- This LG TV overscans HDMI and NVIDIA DRM exposes no underscan control.
-- Keep the bar and tiled windows inside the visible area; fullscreen content
-- still needs Just Scan enabled on the TV.
hl.monitor({
	output = "desc:LG Electronics LG TV 0x01010101",
	scale = 2,
	reserved_area = { top = 48, bottom = 48, left = 48, right = 48 },
})

-- Apply the correct state when Hyprland starts or this config is reloaded.
-- Note: do NOT reload on hot-plug (see handlers below) — reloading can race
-- with monitor re-enumeration and transiently leave the laptop panel enabled.
if hl.get_monitor(external_output) ~= nil then
	disable_internal_display()
else
	enable_internal_display()
end

-- Enter external-only mode the moment HDMI is connected.
hl.on("monitor.added", function(monitor)
	if monitor ~= nil and monitor.name == external_output then
		disable_internal_display()
	end
end)

-- Restore normal laptop mode the moment HDMI is disconnected.
hl.on("monitor.removed", function(monitor)
	if monitor ~= nil and monitor.name == external_output then
		enable_internal_display()
	end
end)

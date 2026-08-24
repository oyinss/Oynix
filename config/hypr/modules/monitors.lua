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
hl.monitor({
	output = external_output,
	mode = "1920x1080@60",
	-- Let Hyprland place HDMI safely while both outputs briefly coexist
	-- during hot-plug. It will settle at 0x0 in external-only mode.
	position = "auto",
	scale = 1,
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

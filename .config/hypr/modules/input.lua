---------------
---- INPUT ----
---------------

-- See https://wiki.hypr.land/Configuring/Variables/#input

	hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",
		follow_mouse = 1,
		sensitivity = 0,
		touchpad = {
			natural_scroll = true,
			disable_while_typing = true,
		},
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

-- Built-in Synaptics touchpad disabled entirely (palm interference while typing).
hl.device({
	name = "cust0001:00-06cb:cdaa-touchpad",
	enabled = false,
})

-- Example per-device configuration.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/
hl.device({
	name = "epic-mouse-v1",
	sensitivity = -0.5,
})

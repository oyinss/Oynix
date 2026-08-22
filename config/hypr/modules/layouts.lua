-----------------
---- LAYOUTS ----
-----------------

-- See https://wiki.hypr.land/Configuring/Layouts/

hl.config({
	general = {
		layout = "scrolling",
	},
	dwindle = {
		preserve_split = true,
	},
	master = {
		new_status = "master",
	},
	scrolling = {
		fullscreen_on_one_column = true,
	},
})

-- Optional smart-gap examples:
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })

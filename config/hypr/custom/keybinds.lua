hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )
hl.bind("SUPER + Print", hl.dsp.global("quickshell:regionScreenshotSave"), { description = "Utilities: Region screenshot >> save & copy" })

--##! Search interrupt
-- The shell toggles the overview when SUPER is released unless something clears
-- its "super release might trigger" flag first. Hyprland 0.57 dropped the old
-- catchall bind (binditn = Super, catchall, global,
-- quickshell:searchToggleReleaseInterrupt) and hl.bind cannot express catchall
-- outside a submap, so every SUPER combo (SUPER+1, SUPER+Q, ...) opened the
-- search as well. This restores it as one transparent bind per key. Keys listed
-- here are matched regardless of modifiers, and they do not consume the press,
-- so the real bind and the focused app still get the key. A lone SUPER tap has
-- no key of its own, so it still opens the search.
-- Upstream reference: end-4/dots-hyprland issue 3728.
local searchInterruptKeys = {
    -- letters
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    -- number row (SUPER+1/2/3 workspace switching) and keypad digits. The
    -- keypad entries are defensive: no SUPER+numpad bind exists today, and
    -- leaving them out would quietly bring the bug back for that layout.
    "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
    "KP_1", "KP_2", "KP_3", "KP_4", "KP_5", "KP_6", "KP_7", "KP_8", "KP_9", "KP_0",
    -- function keys
    "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
    -- navigation and editing
    "Return", "Tab", "Space", "Escape", "BackSpace", "Delete", "Insert",
    "Home", "End", "Page_Up", "Page_Down", "Left", "Right", "Up", "Down",
    -- punctuation. "Print" shares its key with the Screen snip bind above and in
    -- hyprland/keybinds.lua; transparent binds do not shadow, and both still fire.
    "Minus", "Equal", "BracketLeft", "BracketRight", "Semicolon", "Apostrophe",
    "Comma", "Period", "Slash", "Backslash", "Grave", "Print", "Menu",
}

for _, key in ipairs(searchInterruptKeys) do
    hl.bind(key, hl.dsp.global("quickshell:searchToggleReleaseInterrupt"),
        { ignore_mods = true, transparent = true, non_consuming = true })
end

-- Mouse combos (window drag/resize, workspace scroll, special workspace) also
-- leave the flag set. These only fire while SUPER is held, so they are not
-- marked ignore_mods. Verified with SUPER+click while holding SUPER: with this
-- loop removed the overview opens on release, with it present it stays closed.
-- Hyprland reports `mouse = false` for them; the global dispatcher fires anyway.
-- Scroll (mouse_up/mouse_down) cannot be simulated with ydotool here, so it
-- keeps the same flags upstream uses for those exact keys.
for _, button in ipairs({ "mouse:272", "mouse:273", "mouse:274", "mouse:275", "mouse:276", "mouse:277", "mouse_up", "mouse_down" }) do
    hl.bind("SUPER + " .. button, hl.dsp.global("quickshell:searchToggleReleaseInterrupt"),
        { non_consuming = true })
end

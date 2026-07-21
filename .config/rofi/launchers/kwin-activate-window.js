// rofi-windows.sh replaces the UUID placeholder in a temporary copy.
const targetId = "__WINDOW_ID__";
const windows = workspace.stackingOrder;

for (let i = 0; i < windows.length; ++i) {
    if (String(windows[i].internalId) === targetId) {
        windows[i].minimized = false;
        workspace.activeWindow = windows[i];
        break;
    }
}

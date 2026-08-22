// Loaded on demand by rofi-windows.sh inside KWin.
const windows = workspace.stackingOrder;

for (let i = 0; i < windows.length; ++i) {
    const window = windows[i];
    if (window.normalWindow && !window.skipSwitcher) {
        print("ROFI_WINDOW\t" + window.internalId + "\t" + window.caption + "\t" + window.resourceClass);
    }
}

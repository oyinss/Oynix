pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Aggregated AI provider usage for the bar.
 * Data comes from the local `ai-usage` script (see ~/Oynix/local/bin/ai-usage),
 * which reads existing provider credentials and prints a JSON snapshot.
 */
Singleton {
    id: root

    property bool available: false
    property bool loading: false
    property var providers: []
    property int activeIndex: 0
    property double updatedAt: 0
    property string lastError: ""
    property bool stale: false

    readonly property var active: (root.providers.length > 0 && root.activeIndex >= 0
        && root.activeIndex < root.providers.length) ? root.providers[root.activeIndex] : null
    readonly property real activePercent: (root.active && root.active.primary !== null
        && root.active.primary !== undefined) ? root.active.primary : -1
    readonly property bool warning: root.active ? root.active.warning === true : false
    readonly property string displayText: root.activePercent >= 0 ? `${Math.round(root.activePercent)}%` : "--"
    readonly property string activeLabel: root.active ? root.active.label : "AI usage"

    function refresh() {
        if (usageProcess.running)
            return
        root.loading = true
        usageProcess.running = true
    }

    function setActiveProvider(index) {
        if (index >= 0 && index < root.providers.length)
            root.activeIndex = index;
    }


    function cycleProvider() {
        if (root.providers.length < 2)
            return
        root.activeIndex = (root.activeIndex + 1) % root.providers.length
    }

    function applyPayload(raw) {
        try {
            if (!raw || raw.trim().length === 0)
                throw new Error("ai-usage returned no data")

            const snapshot = JSON.parse(raw)
            const list = Array.isArray(snapshot.providers) ? snapshot.providers : []
            if (list.length === 0)
                throw new Error("ai-usage snapshot has no providers")

            root.providers = list
            root.updatedAt = snapshot.updated ?? 0
            root.available = true
            root.stale = false
            root.lastError = ""
            if (root.activeIndex >= list.length)
                root.activeIndex = 0
        } catch (error) {
            root.lastError = error.message
            root.stale = root.providers.length > 0
            console.warn(`[AiUsage] ${error.message}`)
        }
    }

    Timer {
        interval: 120 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: usageProcess
        // Absolute, $HOME-based path: the shell's PATH does not include ~/.local/bin,
        // so invoking `ai-usage` by bare name silently failed and left the popup
        // stuck on "Refreshing…".
        command: [Quickshell.env("HOME") + "/.local/bin/ai-usage"]

        stdout: StdioCollector {
            onStreamFinished: root.applyPayload(text)
        }

        onExited: {
            root.loading = false
        }
    }
}

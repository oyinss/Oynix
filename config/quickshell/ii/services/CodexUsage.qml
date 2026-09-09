pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property bool loading: false
    property int weeklyUsedPercent: -1
    property int fiveHourUsedPercent: -1
    property int sparkWeeklyUsedPercent: -1
    property string weeklyResetDescription: ""
    property string lastError: ""

    readonly property int displayPercent: weeklyUsedPercent >= 0
        ? weeklyUsedPercent
        : sparkWeeklyUsedPercent
    readonly property bool warning: displayPercent >= 80
    readonly property string displayText: displayPercent >= 0
        ? `${displayPercent}%`
        : "--"
    readonly property string tooltipText: {
        if (!root.available)
            return "Codex usage unavailable"

        const weekly = root.weeklyUsedPercent >= 0 ? `${root.weeklyUsedPercent}%` : "--"
        const fiveHour = root.fiveHourUsedPercent >= 0 ? `${root.fiveHourUsedPercent}%` : "--"
        const sparkWeekly = root.sparkWeeklyUsedPercent >= 0 ? `${root.sparkWeeklyUsedPercent}%` : "--"
        const reset = root.weeklyResetDescription.length > 0
            ? `\nWeekly reset: ${root.weeklyResetDescription}`
            : ""
        return `Codex usage\nWeekly: ${weekly}\n5-hour: ${fiveHour}\nSpark weekly: ${sparkWeekly}${reset}`
    }

    function refresh() {
        if (usageProcess.running)
            return
        root.loading = true
        usageProcess.running = true
    }

    function applyPayload(raw) {
        if (raw.trim().length === 0)
            throw new Error("codexbar returned no data")

        const records = JSON.parse(raw)
        const record = records.find(item => item.provider === "codex") ?? records[0]
        const usage = record?.usage
        if (!usage)
            throw new Error("Codex usage data was not found")

        const extraWindows = usage.extraRateWindows ?? []
        const fiveHour = extraWindows.find(item => item.id === "codex-spark")?.window
        const sparkWeekly = extraWindows.find(item => item.id === "codex-spark-weekly")?.window

        root.weeklyUsedPercent = usage.secondary?.usedPercent ?? -1
        root.fiveHourUsedPercent = fiveHour?.usedPercent ?? -1
        root.sparkWeeklyUsedPercent = sparkWeekly?.usedPercent ?? -1
        root.weeklyResetDescription = usage.secondary?.resetDescription ?? ""
        root.lastError = ""
        root.available = true
    }

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: usageProcess
        command: [
            "codexbar",
            "usage",
            "--provider", "codex",
            "--format", "json",
            "--no-color"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyPayload(text)
                } catch (error) {
                    root.available = false
                    root.lastError = error.message
                    console.warn(`[CodexUsage] ${error.message}`)
                }
            }
        }

        onExited: {
            root.loading = false
        }
    }
}

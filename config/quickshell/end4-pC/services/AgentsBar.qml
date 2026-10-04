pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * AgentsBar's provider usage service.
 *
 * The data source is the repository-owned ~/.local/bin/ai-usage helper. It calls
 * provider APIs directly and never depends on the codexbar package.
 */
Singleton {
    id: root

    property bool available: false
    property bool loading: false
    property int weeklyUsedPercent: -1
    property int fiveHourUsedPercent: -1
    property string weeklyResetDescription: ""
    property string lastError: ""
    property string selectedProvider: Config.options.custom.agentsBarProvider
    property var providerPrimaries: ({})
    property var providerSources: ({})
    property list<var> providerRows: []

    readonly property int displayPercent: Number(root.providerPrimaries[root.selectedProvider] ?? -1)
    readonly property bool warning: displayPercent >= 80
    readonly property string displayText: displayPercent >= 0 ? `${displayPercent}%` : "--"

    function providerLabel(id) {
        switch (id) {
        case "codex": return "Codex"
        case "opencode-go": return "OpenCode Go"
        case "deepseek": return "DeepSeek"
        default: return id
        }
    }

    function resetLabel(window) {
        if (window.resets_at) {
            return new Date(Number(window.resets_at) * 1000).toLocaleString([], {
                month: "short",
                day: "numeric",
                hour: "numeric",
                minute: "2-digit"
            })
        }
        if (window.resets_in)
            return `resets in ${Math.ceil(Number(window.resets_in) / 3600)}h`
        return "Reset time unavailable"
    }

    function applyProvider(provider, rows) {
        root.providerRows = root.providerRows
            .filter(row => row.providerId !== provider.id)
            .concat(rows)
    }

    function parseSnapshot(raw) {
        if (!raw || raw.trim().length === 0)
            throw new Error("agents-usage returned no data")

        const snapshot = JSON.parse(raw)
        const providers = Array.isArray(snapshot.providers) ? snapshot.providers : []
        if (providers.length === 0)
            throw new Error("agents-usage returned no providers")

        providers.forEach(provider => {
            const label = root.providerLabel(provider.id)
            const nextPrimaries = Object.assign({}, root.providerPrimaries)
            nextPrimaries[provider.id] = provider.primary === null || provider.primary === undefined
                ? -1
                : Number(provider.primary)
            root.providerPrimaries = nextPrimaries
            const nextSources = Object.assign({}, root.providerSources)
            if (provider.source)
                nextSources[provider.id] = provider.source
            root.providerSources = nextSources
            const rows = (provider.windows ?? []).map(window => ({
                providerId: provider.id,
                providerLabel: label,
                label: window.label ?? "Usage window",
                percent: Number(window.used_percent),
                value: "",
                reset: root.resetLabel(window)
            })).concat((provider.extras ?? []).map(extra => ({
                providerId: provider.id,
                providerLabel: label,
                label: extra.label ?? "Account balance",
                percent: -1,
                value: extra.value ?? "",
                reset: ""
            })))

            root.applyProvider(provider, rows.length > 0 ? rows : [{
                providerId: provider.id,
                providerLabel: label,
                label: "Unavailable",
                percent: -1,
                reset: provider.error || "No usage data returned"
            }])

            if (provider.id === "codex") {
                const weekly = provider.windows.find(window => window.label === "Weekly")
                    ?? provider.windows.find(window => window.id === "secondary-primary")
                const session = provider.windows.find(window => window.label.includes("Session"))
                root.weeklyUsedPercent = weekly?.used_percent ?? -1
                root.fiveHourUsedPercent = session?.used_percent ?? -1
                root.weeklyResetDescription = weekly ? root.resetLabel(weekly) : ""
            }
        })

        // DeepSeek has no supported usage endpoint in the local Linux provider
        // sources. Keep the tab visible, but never invent a quota value.
        if (!providers.some(provider => provider.id === "deepseek")) {
            root.applyProvider({ id: "deepseek" }, [{
                providerId: "deepseek",
                providerLabel: "DeepSeek",
                label: "Unavailable",
                percent: -1,
                reset: "No supported Linux usage source"
            }])
        }

        root.available = root.providerRows.some(row => row.percent >= 0)
        root.lastError = ""
    }

    function refresh() {
        if (usageProcess.running)
            return
        root.loading = true
        usageProcess.running = true
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
        command: [Quickshell.env("HOME") + "/.local/bin/ai-usage"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.parseSnapshot(text)
                } catch (error) {
                    root.lastError = error.message
                    console.warn(`[AgentsBar] ${error.message}`)
                }
            }
        }

        onExited: root.loading = false
    }
}

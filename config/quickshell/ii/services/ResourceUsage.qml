pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
    id: root
	property real memoryTotal: 1
	property real memoryFree: 0
	property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
	property real swapFree: 0
	property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats
    property real networkDownSpeed: 0 // B/s
    property real networkUpSpeed: 0 // B/s
    property var previousNetStats
    property string networkInterface: "" // default-route interface

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec >= 1000000000)
            return (bytesPerSec / 1000000000).toFixed(1) + " GB/s";
        if (bytesPerSec >= 1000000)
            return (bytesPerSec / 1000000).toFixed(1) + " MB/s";
        if (bytesPerSec >= 1000)
            return Math.round(bytesPerSec / 1000) + " KB/s";
        return Math.round(bytesPerSec) + " B/s";
    }

    function defaultRouteInterface(routeText) {
        let bestIface = ""
        let bestMetric = Number.MAX_SAFE_INTEGER
        for (const line of routeText.split("\n").slice(1)) {
            const fields = line.trim().split(/\s+/)
            if (fields.length < 8 || fields[1] !== "00000000") continue
            const metric = Number(fields[6])
            if (!Number.isFinite(metric) || metric >= bestMetric) continue
            bestMetric = metric
            bestIface = fields[0]
        }
        return bestIface
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
    }

	Timer {
		interval: 1
        running: true 
        repeat: true
		onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()
            fileNetdev.reload()
            fileRoute.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = fileStat.text()
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
            }

            // Parse network speeds from /proc/net/dev for the default-route interface
            const textRoute = fileRoute.text()
            networkInterface = defaultRouteInterface(textRoute)

            const textNet = fileNetdev.text()
            const nowMs = Date.now()
            let rxTotal = 0
            let txTotal = 0
            if (networkInterface !== "") {
                for (const line of textNet.split("\n").slice(2)) {
                    const [iface, data] = line.split(":")
                    if (!data) continue
                    if (iface.trim() !== networkInterface) continue
                    const fields = data.trim().split(/\s+/)
                    rxTotal += Number(fields[0] ?? 0)
                    txTotal += Number(fields[8] ?? 0)
                }
            }
            if (previousNetStats && networkInterface === previousNetStats.iface) {
                const elapsed = Math.max(1, nowMs - previousNetStats.timestamp) / 1000
                networkDownSpeed = Math.max(0, (rxTotal - previousNetStats.rx) / elapsed)
                networkUpSpeed = Math.max(0, (txTotal - previousNetStats.tx) / elapsed)
            } else {
                // First tick or interface changed: no comparable counters yet
                networkDownSpeed = 0
                networkUpSpeed = 0
            }
            previousNetStats = { timestamp: nowMs, iface: networkInterface, rx: rxTotal, tx: txTotal }

            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
	}

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
	FileView { id: fileStat; path: "/proc/stat" }
	FileView { id: fileNetdev; path: "/proc/net/dev" }
	FileView { id: fileRoute; path: "/proc/net/route" }

    Process {
        id: findCpuMaxFreqProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }
}

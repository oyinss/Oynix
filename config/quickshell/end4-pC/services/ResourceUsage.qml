pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, CPU and Disk usage.
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
    property real memoryAvailable: 0
    property real memoryCached: 0
    property real memoryBuffers: 0
    property real cpuUsage: 0
    property var previousCpuStats
    property string loadAverage: ""
    property int cpuCoreCount: 0
    property int swappiness: 0
    property var disks: []
    property bool gpuAvailable: false
    property string gpuName: ""
    property real gpuUsage: 0
    property real gpuTemp: 0
    property real gpuMemoryUsed: 0
    property real gpuMemoryTotal: 0

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    property real cpuTemp: 0

    property real diskTotal: 1
    property real diskUsed: 0
    property real diskFree: 0
    property real diskUsedPercentage: diskTotal > 0 ? diskUsed / diskTotal : 0
    property list<real> diskUsageHistory: []
    property string maxAvailableDiskString: kbToGbString(diskTotal)

    property string thermalPath: ""

    Process {
        id: findThermalPathProc
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do [ -d \"$h\" ] || continue; for l in \"$h\"/temp*_label; do [ -f \"$l\" ] || continue; if grep -qE 'Package id 0|Tctl|Tdie' \"$l\" 2>/dev/null; then inp=\"${l%_label}_input\"; [ -f \"$inp\" ] && echo \"$inp\" && exit 0; fi; done; done; for z in /sys/class/thermal/thermal_zone*; do [ -d \"$z\" ] || continue; type=$(cat \"$z/type\" 2>/dev/null); case \"$type\" in x86_pkg_temp|cpu*|TCPU) [ -f \"$z/temp\" ] && echo \"$z/temp\" && exit 0;; esac; done; for t in /sys/class/hwmon/hwmon*/temp1_input /sys/class/thermal/thermal_zone0/temp; do [ -f \"$t\" ] && echo \"$t\" && exit 0; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const foundPath = text.trim();
                if (foundPath.length > 0) {
                    root.thermalPath = foundPath;
                    fileTemp.reload();
                }
            }
        }
    }

    FileView {
        id: fileTemp
        path: root.thermalPath
        printErrors: false
        onLoaded: {
            const raw = parseFloat(fileTemp.text().trim());
            if (!isNaN(raw) && raw > 0) {
                root.cpuTemp = raw > 200 ? Math.round(raw / 100) / 10 : raw;
            }
        }
    }

    Process {
        id: tempProcFallback
        command: ["bash", "-c", "sensors 2>/dev/null | grep -E 'Package id 0|Tctl|Tdie' | grep -oP '\\+\\K[0-9.]+(?=°C)' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = parseFloat(text.trim());
                if (!isNaN(parsed) && parsed > 0) {
                    root.cpuTemp = parsed;
                }
            }
        }
    }

    Process {
        id: diskProc
        command: ["df", "-kP"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = [];
                const lines = text.trim().split("\n");
                for (let i = 1; i < lines.length; i++) {
                    const parts = lines[i].trim().split(/\s+/);
                    if (parts.length < 6)
                        continue;
                    rows.push({
                        fs: parts[0],
                        total: Number(parts[1]),
                        used: Number(parts[2]),
                        free: Number(parts[3]),
                        mount: parts.slice(5).join(" ")
                    });
                }
                root.disks = rows;
                const rootRow = rows.find((row) => row.mount === "/");
                if (rootRow) {
                    root.diskTotal = rootRow.total;
                    root.diskUsed  = rootRow.used;
                    root.diskFree  = rootRow.free;
                }
            }
        }
    }

    Process {
        id: coreCountProc
        command: ["nproc"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.cpuCoreCount = Number(text.trim()) || 0;
            }
        }
    }

    Process {
        id: gpuProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["bash", "-c", 'if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,name --format=csv,noheader,nounits 2>/dev/null | head -1; else for c in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r "$c" ] && { echo "$(cat "$c")",0,0,0,GPU; break; }; done; fi']
        stdout: StdioCollector {
            onStreamFinished: {
                const line = (text.trim().split("\n")[0] ?? "").trim();
                if (line.length === 0) {
                    root.gpuAvailable = false;
                    return;
                }
                const parts = line.split(",").map((part) => part.trim());
                if (parts.length < 4) {
                    root.gpuAvailable = false;
                    return;
                }
                root.gpuUsage = (Number(parts[0]) || 0) / 100;
                root.gpuTemp = Number(parts[1]) || 0;
                root.gpuMemoryUsed = (Number(parts[2]) || 0) * 1024;
                root.gpuMemoryTotal = (Number(parts[3]) || 0) * 1024;
                root.gpuName = parts.slice(4).join(", ");
                root.gpuAvailable = true;
            }
        }
    }

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB"
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) memoryUsageHistory.shift()
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) swapUsageHistory.shift()
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) cpuUsageHistory.shift()
    }
    function updateDiskUsageHistory() {
        diskUsageHistory = [...diskUsageHistory, diskUsedPercentage]
        if (diskUsageHistory.length > historyLength) diskUsageHistory.shift()
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
        updateDiskUsageHistory()
    }

    Timer {
        interval: 1
        running: true
        repeat: true
        onTriggered: {
            fileMeminfo.reload()
            fileStat.reload()
            fileLoadavg.reload()
            fileSwappiness.reload()

            if (root.thermalPath.length > 0) {
                fileTemp.reload()
                const raw = parseFloat(fileTemp.text().trim())
                if (!isNaN(raw) && raw > 0) {
                    root.cpuTemp = raw > 200 ? Math.round(raw / 100) / 10 : raw
                }
            } else if (!findThermalPathProc.running) {
                tempProcFallback.running = false
                tempProcFallback.running = true
            }

            diskProc.running = false
            diskProc.running = true

            gpuProc.running = false
            gpuProc.running = true

            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree  = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            memoryAvailable = memoryFree
            memoryCached = Number(textMeminfo.match(/^Cached: *(\d+)/m)?.[1] ?? 0)
            memoryBuffers = Number(textMeminfo.match(/^Buffers: *(\d+)/m)?.[1] ?? 0)
            swapTotal   = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree    = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            loadAverage = fileLoadavg.text().trim().split(/\s+/).slice(0, 3).join(" ")
            swappiness = Number(fileSwappiness.text().trim()) || 0

            const textStat = fileStat.text()
            const cpuLine  = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle  = stats[3]
                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff  = idle  - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }
                previousCpuStats = { total, idle }
            }

            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
    }

    FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat;    path: "/proc/stat" }
    FileView { id: fileLoadavg;    path: "/proc/loadavg" }
    FileView { id: fileSwappiness; path: "/proc/sys/vm/swappiness" }

    Process {
        id: findCpuMaxFreqProc
        environment: ({ LANG: "C", LC_ALL: "C" })
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

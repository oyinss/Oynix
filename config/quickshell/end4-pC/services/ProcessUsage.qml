pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Polled process list backing the resources popup's process view. Polling runs
 * only while `active` (i.e. while a resources popup is open).
 */
Singleton {
    id: root

    property bool active: false
    property var processes: []

    readonly property int pollInterval: 2000
    readonly property int maxProcesses: 60

    function refresh() {
        if (!root.active || psProc.running)
            return
        psProc.running = true
    }

    function killProcess(pid, sig) {
        killProc.targetPid = pid
        killProc.killSignal = sig ?? 15
        killProc.running = false
        killProc.running = true
    }

    function topByCpu(count) {
        return root.processes
            .slice()
            .sort((a, b) => b.cpu - a.cpu)
            .slice(0, count ?? root.maxProcesses)
    }

    function topByMemory(count) {
        return root.processes
            .slice()
            .sort((a, b) => b.rss - a.rss)
            .slice(0, count ?? root.maxProcesses)
    }

    Timer {
        interval: root.pollInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: psProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["ps", "-eo", "pid=,comm=,pcpu=,pmem=,rss=,user=", "--sort=-pcpu"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const raw of text.split("\n")) {
                    const line = raw.trim()
                    if (line.length === 0)
                        continue
                    const m = line.match(/^(\d+)\s+(\S+)\s+([\d.]+)\s+([\d.]+)\s+(\d+)\s+(\S+)$/)
                    if (!m)
                        continue
                    out.push({
                        "pid": Number(m[1]),
                        "comm": m[2],
                        "cpu": Number(m[3]),
                        "mem": Number(m[4]),
                        "rss": Number(m[5]),
                        "user": m[6]
                    })
                }
                root.processes = out
            }
        }
    }

    Process {
        id: killProc
        property int targetPid: -1
        property int killSignal: 15
        command: ["kill", `-${killProc.killSignal}`, String(killProc.targetPid)]
        onExited: root.refresh()
    }
}

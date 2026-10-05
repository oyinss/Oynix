import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root

    property bool opened: false
    property Item anchorItem
    property string selected: ""
    property string processSort: "memory"
    signal requestClose()

    readonly property bool barVertical: Config.options.bar.vertical
    readonly property string barEdge: {
        if (!root.barVertical)
            return Config.options.bar.bottom ? "bottom" : "top"
        return Config.options.bar.bottom ? "right" : "left"
    }
    readonly property real barThickness: root.barVertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
    readonly property bool isDisk: root.selected === "disk"

    readonly property var hero: root.heroData()
    readonly property var stats: root.detailStats()
    readonly property var procRows: root.processRows()
    readonly property string procSubtitle: root.processSort === "cpu" ? "Top CPU consumers" : "Top memory consumers"

    function fmtKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB"
    }

    function iconHue(name) {
        let h = 0
        for (let i = 0; i < name.length; i++)
            h = (h * 31 + name.charCodeAt(i)) % 360
        return h
    }

    function formatProcessMem(kb) {
        if (kb >= 1048576)
            return { n: (kb / 1048576).toFixed(1), unit: "GB" }
        return { n: Math.round(kb / 1024).toString(), unit: "MB" }
    }

    function detailTitle() {
        switch (root.selected) {
        case "ram":
            return "RAM"
        case "swap":
            return "Swap"
        case "cpu":
            return "CPU"
        case "temperature":
            return "Temperature"
        case "gpu":
            return "GPU"
        case "disk":
            return "Disk"
        }
        return ""
    }

    function detailSubtitle() {
        switch (root.selected) {
        case "ram":
            return "Memory usage and running processes"
        case "swap":
            return "Swap usage and top consumers"
        case "cpu":
            return "Processor usage and running processes"
        case "temperature":
            return "CPU package temperature"
        case "gpu":
            return ResourceUsage.gpuName || "Graphics usage and memory"
        case "disk":
            return "Filesystem usage by mount"
        }
        return ""
    }

    function heroData() {
        const pct = fraction => Math.round(fraction * 100) + "%"
        switch (root.selected) {
        case "ram": {
            const used = ResourceUsage.memoryUsed
            const total = ResourceUsage.memoryTotal
            const fraction = total > 0 ? used / total : 0
            return {
                value: fraction,
                center: pct(fraction),
                centerLabel: "Used",
                big: root.fmtKB(used),
                suffix: "/ " + root.fmtKB(total),
                sub: "In use",
                endLeft: root.fmtKB(used) + " used",
                endRight: root.fmtKB(ResourceUsage.memoryAvailable) + " available"
            }
        }
        case "swap": {
            const fraction = ResourceUsage.swapUsedPercentage
            return {
                value: fraction,
                center: pct(fraction),
                centerLabel: "Used",
                big: root.fmtKB(ResourceUsage.swapUsed),
                suffix: "/ " + root.fmtKB(ResourceUsage.swapTotal),
                sub: "In use",
                endLeft: root.fmtKB(ResourceUsage.swapUsed) + " used",
                endRight: root.fmtKB(ResourceUsage.swapFree) + " free"
            }
        }
        case "cpu": {
            const fraction = ResourceUsage.cpuUsage
            return {
                value: fraction,
                center: pct(fraction),
                centerLabel: "Used",
                big: Math.round(ResourceUsage.cpuTemp) + "°C",
                suffix: "",
                sub: "Package temperature",
                endLeft: "Load " + (ResourceUsage.loadAverage || "--"),
                endRight: ResourceUsage.cpuCoreCount + " cores"
            }
        }
        case "temperature": {
            const temp = ResourceUsage.cpuTemp
            return {
                value: Math.min(temp / 100, 1),
                center: Math.round(temp) + "°",
                centerLabel: "CPU",
                big: Math.round(temp) + "°C",
                suffix: "",
                sub: "Package temperature",
                endLeft: "Load " + (ResourceUsage.loadAverage || "--"),
                endRight: ResourceUsage.cpuCoreCount + " cores"
            }
        }
        case "gpu": {
            const fraction = ResourceUsage.gpuUsage
            return {
                value: fraction,
                center: pct(fraction),
                centerLabel: "Used",
                big: Math.round(ResourceUsage.gpuTemp) + "°C",
                suffix: "",
                sub: ResourceUsage.gpuName || "GPU",
                endLeft: root.fmtKB(ResourceUsage.gpuMemoryUsed) + " VRAM",
                endRight: root.fmtKB(ResourceUsage.gpuMemoryTotal) + " total"
            }
        }
        case "disk": {
            const fraction = ResourceUsage.diskUsedPercentage
            return {
                value: fraction,
                center: pct(fraction),
                centerLabel: "Used",
                big: root.fmtKB(ResourceUsage.diskUsed),
                suffix: "/ " + root.fmtKB(ResourceUsage.diskTotal),
                sub: "In use",
                endLeft: root.fmtKB(ResourceUsage.diskUsed) + " used",
                endRight: root.fmtKB(ResourceUsage.diskFree) + " free"
            }
        }
        }
        return { value: 0, center: "0%", centerLabel: "Used", big: "--", suffix: "", sub: "", endLeft: "", endRight: "" }
    }

    function detailStats() {
        switch (root.selected) {
        case "ram":
            return [
                { icon: "storage", label: "Total", value: root.fmtKB(ResourceUsage.memoryTotal) },
                { icon: "pie_chart", label: "Used", value: root.fmtKB(ResourceUsage.memoryUsed) },
                { icon: "speed", label: "Available", value: root.fmtKB(ResourceUsage.memoryAvailable) },
                { icon: "database", label: "Cached", value: root.fmtKB(ResourceUsage.memoryCached) },
                { icon: "description", label: "Buffers", value: root.fmtKB(ResourceUsage.memoryBuffers) },
                { icon: "swap_horiz", label: "Swap used", value: root.fmtKB(ResourceUsage.swapUsed) }
            ]
        case "swap":
            return [
                { icon: "storage", label: "Total", value: root.fmtKB(ResourceUsage.swapTotal) },
                { icon: "pie_chart", label: "Used", value: root.fmtKB(ResourceUsage.swapUsed) },
                { icon: "speed", label: "Free", value: root.fmtKB(ResourceUsage.swapFree) },
                { icon: "tune", label: "Swappiness", value: String(ResourceUsage.swappiness) }
            ]
        case "cpu":
            return [
                { icon: "speed", label: "Usage", value: Math.round(ResourceUsage.cpuUsage * 100) + "%" },
                { icon: "device_thermostat", label: "Temperature", value: Math.round(ResourceUsage.cpuTemp) + " °C" },
                { icon: "monitor_heart", label: "Load average", value: ResourceUsage.loadAverage || "--" },
                { icon: "memory", label: "Cores", value: String(ResourceUsage.cpuCoreCount) }
            ]
        case "temperature":
            return [
                { icon: "device_thermostat", label: "CPU", value: Math.round(ResourceUsage.cpuTemp) + " °C" },
                { icon: "memory", label: "Cores", value: String(ResourceUsage.cpuCoreCount) },
                { icon: "monitor_heart", label: "Load average", value: ResourceUsage.loadAverage || "--" }
            ]
        case "gpu":
            return [
                { icon: "speed", label: "Usage", value: Math.round(ResourceUsage.gpuUsage * 100) + "%" },
                { icon: "device_thermostat", label: "Temperature", value: Math.round(ResourceUsage.gpuTemp) + " °C" },
                { icon: "memory", label: "VRAM used", value: root.fmtKB(ResourceUsage.gpuMemoryUsed) },
                { icon: "storage", label: "VRAM total", value: root.fmtKB(ResourceUsage.gpuMemoryTotal) }
            ]
        case "disk":
            return (ResourceUsage.disks ?? [])
                .filter(disk => disk.fs.startsWith("/dev/") || disk.mount === "/")
                .map(disk => ({
                    icon: "folder",
                    label: disk.mount,
                    value: root.fmtKB(disk.used) + " / " + root.fmtKB(disk.total)
                }))
        }
        return []
    }

    function processRows() {
        if (root.isDisk)
            return []
        const list = root.processSort === "cpu" ? ProcessUsage.topByCpu() : ProcessUsage.topByMemory()
        return list.map(process => {
            const mem = root.formatProcessMem(process.rss)
            return {
                pid: process.pid,
                comm: process.comm,
                cpu: process.cpu,
                mem: process.mem,
                letter: (process.comm || "?").charAt(0).toUpperCase(),
                hue: root.iconHue(process.comm || "?") / 360,
                memValue: mem.n,
                memUnit: mem.unit
            }
        })
    }

    active: root.opened

    component StatCard: Rectangle {
        id: statCard
        required property string iconText
        required property string label
        required property string value
        Layout.fillWidth: true
        implicitHeight: 66
        radius: 14
        color: Appearance.colors.colLayer2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 9
                    color: Appearance.colors.colSurfaceContainerHighest

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: statCard.iconText
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: statCard.label
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideRight
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: statCard.value
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }

    component MiniBar: Rectangle {
        id: miniBar
        property real value: 0
        Layout.preferredWidth: 36
        Layout.preferredHeight: 4
        radius: 2
        color: Appearance.colors.colSurfaceContainerHighest

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, miniBar.value))
            height: parent.height
            radius: parent.radius
            color: Appearance.colors.colPrimary
        }
    }

    component ProcessRow: Rectangle {
        id: procRow
        required property var modelData
        width: ListView.view ? ListView.view.width : implicitWidth
        implicitHeight: 42
        radius: 10
        color: rowHover.containsMouse ? Appearance.colors.colLayer3Hover : "transparent"

        MouseArea {
            id: rowHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 9
                color: Qt.hsla(procRow.modelData.hue, 0.45, 0.45, 0.55)

                StyledText {
                    anchors.centerIn: parent
                    text: procRow.modelData.letter
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnSurface
                }

                AppIcon {
                    anchors.fill: parent
                    anchors.margins: 4
                    source: procRow.modelData.comm
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 90
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: procRow.modelData.comm
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                StyledText {
                    text: "#" + procRow.modelData.pid
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }
            }

            RowLayout {
                spacing: 4

                StyledText {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    text: procRow.modelData.cpu.toFixed(1) + "%"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                }

                MiniBar {
                    value: procRow.modelData.cpu / 100
                }
            }

            RowLayout {
                spacing: 4

                StyledText {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    text: procRow.modelData.mem.toFixed(1) + "%"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                }

                MiniBar {
                    value: procRow.modelData.mem / 100
                }
            }

            RowLayout {
                Layout.preferredWidth: 66
                spacing: 3

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: procRow.modelData.memValue
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }

                StyledText {
                    text: procRow.modelData.memUnit
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    Layout.alignment: Qt.AlignBottom
                }
            }

            RippleButton {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colErrorContainer
                downAction: () => ProcessUsage.killProcess(procRow.modelData.pid, 15)
                altAction: () => ProcessUsage.killProcess(procRow.modelData.pid, 9)

                contentItem: MaterialSymbol {
                    text: "close"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colError
                }
            }
        }
    }

    component: PanelWindow {
        id: popupWindow

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        anchors.left: root.barEdge !== "right"
        anchors.right: root.barEdge === "right"
        anchors.top: root.barEdge !== "bottom"
        anchors.bottom: root.barEdge === "bottom"

        implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

        readonly property real centerOffsetX: {
            const base = root.QsWindow?.mapFromItem(root.anchorItem, (root.anchorItem.width - popupBackground.implicitWidth) / 2, 0).x ?? 0
            const margin = Appearance.sizes.elevationMargin
            const maxLeft = popupWindow.screen.width - popupBackground.implicitWidth - margin - 10
            return Math.max(margin, Math.min(base, maxLeft))
        }
        readonly property real centerOffsetY: {
            const base = root.QsWindow?.mapFromItem(root.anchorItem, 0, (root.anchorItem.height - popupBackground.implicitHeight) / 2).y ?? 0
            const margin = Appearance.sizes.elevationMargin
            const maxTop = popupWindow.screen.height - popupBackground.implicitHeight - margin - 15
            return Math.max(margin, Math.min(base, maxTop))
        }

        margins {
            left: {
                if (root.barEdge === "right")
                    return 0
                if (root.barEdge === "left")
                    return root.barThickness
                return popupWindow.centerOffsetX
            }
            top: {
                if (root.barEdge === "bottom")
                    return 0
                if (root.barEdge === "top")
                    return root.barThickness
                return popupWindow.centerOffsetY
            }
            right: root.barEdge === "right" ? root.barThickness : 0
            bottom: root.barEdge === "bottom" ? root.barThickness : 0
        }

        WlrLayershell.namespace: "quickshell:resources"
        WlrLayershell.layer: WlrLayer.Overlay

        mask: Region {
            item: popupBackground
        }

        Component.onCompleted: {
            ProcessUsage.active = true
            GlobalFocusGrab.addDismissable(popupWindow)
        }
        Component.onDestruction: {
            ProcessUsage.active = false
            GlobalFocusGrab.removeDismissable(popupWindow)
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                root.requestClose()
            }
        }

        StyledRectangularShadow {
            target: popupBackground
        }

        Rectangle {
            id: popupBackground
            anchors.fill: parent
            anchors.margins: Appearance.sizes.elevationMargin
            implicitWidth: root.selected === "" ? 480 : 520
            implicitHeight: popupContent.implicitHeight + 20
            color: Appearance.colors.colLayer1Base
            radius: Appearance.rounding.large
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            Behavior on implicitWidth {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            ColumnLayout {
                id: popupContent
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                RowLayout {
                    visible: root.selected === ""
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 5

                    ColumnLayout {
                        spacing: 5

                        ResourceCard {
                            label: "RAM"
                            iconText: "memory"
                            iconShape: MaterialShape.Shape.Clover4Leaf
                            value: ResourceUsage.memoryUsed / ResourceUsage.memoryTotal
                            sublabel: root.fmtKB(ResourceUsage.memoryUsed) + " / " + root.fmtKB(ResourceUsage.memoryTotal)
                            interactive: true
                            onClicked: root.selected = "ram"
                        }

                        ResourceCard {
                            label: "CPU"
                            iconText: "planner_review"
                            iconShape: MaterialShape.Shape.Gem
                            value: ResourceUsage.cpuUsage
                            sublabel: `${Math.round(ResourceUsage.cpuTemp)}°C`
                            interactive: true
                            onClicked: root.selected = "cpu"
                        }
                    }

                    ColumnLayout {
                        spacing: 5

                        ResourceCard {
                            label: "Swap"
                            iconText: "swap_horiz"
                            iconShape: MaterialShape.Shape.Bun
                            value: ResourceUsage.swapUsedPercentage
                            sublabel: root.fmtKB(ResourceUsage.swapUsed) + " / " + root.fmtKB(ResourceUsage.swapTotal)
                            interactive: true
                            onClicked: root.selected = "swap"
                        }

                        ResourceCard {
                            label: "GPU"
                            iconText: "developer_board"
                            iconShape: MaterialShape.Shape.Diamond
                            value: ResourceUsage.gpuUsage
                            sublabel: ResourceUsage.gpuAvailable ? root.fmtKB(ResourceUsage.gpuMemoryUsed) + " / " + root.fmtKB(ResourceUsage.gpuMemoryTotal) : "N/A"
                            interactive: true
                            onClicked: root.selected = "gpu"
                        }
                    }

                    ColumnLayout {
                        spacing: 5

                        ResourceCard {
                            label: "Temperature"
                            iconText: "thermostat"
                            iconShape: MaterialShape.Shape.Sunny
                            value: ResourceUsage.cpuTemp / 100
                            sublabel: `${Math.round(ResourceUsage.cpuTemp)}°C`
                            interactive: true
                            onClicked: root.selected = "temperature"
                        }

                        ResourceCard {
                            label: "Disk"
                            iconText: "hard_drive"
                            iconShape: MaterialShape.Shape.Circle
                            value: ResourceUsage.diskUsedPercentage
                            sublabel: root.fmtKB(ResourceUsage.diskUsed) + " / " + root.fmtKB(ResourceUsage.diskTotal)
                            interactive: true
                            onClicked: root.selected = "disk"
                        }
                    }
                }

                ColumnLayout {
                    visible: root.selected !== ""
                    Layout.fillWidth: true
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        RippleButton {
                            implicitWidth: 42
                            implicitHeight: 42
                            buttonRadius: 14
                            colBackground: Appearance.colors.colLayer2
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            downAction: () => root.selected = ""

                            contentItem: MaterialSymbol {
                                text: "arrow_back"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnSurface
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                text: root.detailTitle()
                                font.pixelSize: Appearance.font.pixelSize.huge
                                font.weight: Font.Bold
                            }

                            StyledText {
                                text: root.detailSubtitle()
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: heroRow.implicitHeight + 28
                        radius: 18
                        color: Appearance.colors.colLayer2

                        RowLayout {
                            id: heroRow
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 18

                            CircularProgress {
                                Layout.alignment: Qt.AlignVCenter
                                implicitSize: 104
                                lineWidth: 11
                                value: root.hero.value
                                colPrimary: Appearance.colors.colPrimary
                                colSecondary: Appearance.colors.colSecondaryContainer

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 0

                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: root.hero.center
                                        font.pixelSize: Appearance.font.pixelSize.huge
                                        font.weight: Font.Bold
                                    }

                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: root.hero.centerLabel
                                        color: Appearance.colors.colSubtext
                                        font.pixelSize: Appearance.font.pixelSize.small
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 6

                                RowLayout {
                                    spacing: 8

                                    StyledText {
                                        text: root.hero.big
                                        font.pixelSize: Appearance.font.pixelSize.huge
                                        font.weight: Font.Bold
                                    }

                                    StyledText {
                                        Layout.alignment: Qt.AlignBottom
                                        text: root.hero.suffix
                                        color: Appearance.colors.colSubtext
                                        font.pixelSize: Appearance.font.pixelSize.large
                                    }
                                }

                                StyledText {
                                    text: root.hero.sub
                                    color: Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.small
                                }

                                StyledProgressBar {
                                    Layout.fillWidth: true
                                    valueBarHeight: 8
                                    value: root.hero.value
                                    highlightColor: Appearance.colors.colPrimary
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: root.hero.endLeft
                                        color: Appearance.colors.colSubtext
                                        font.pixelSize: Appearance.font.pixelSize.small
                                    }

                                    StyledText {
                                        text: root.hero.endRight
                                        color: Appearance.colors.colSubtext
                                        font.pixelSize: Appearance.font.pixelSize.small
                                    }
                                }
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: root.stats

                            delegate: StatCard {
                                required property var modelData
                                iconText: modelData.icon
                                label: modelData.label
                                value: modelData.value
                            }
                        }
                    }

                    RowLayout {
                        visible: !root.isDisk
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 8

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignVCenter
                            text: "list"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: "Processes"
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                            }

                            StyledText {
                                text: root.procSubtitle
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smallest
                            }
                        }

                        StyledText {
                            text: "Sort by:"
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        StyledComboBox {
                            Layout.fillWidth: false
                            Layout.preferredWidth: 118
                            implicitHeight: 34
                            model: ["Memory", "CPU"]
                            currentIndex: root.processSort === "cpu" ? 1 : 0
                            onActivated: root.processSort = currentIndex === 1 ? "cpu" : "memory"
                        }
                    }

                    ListView {
                        id: processList
                        visible: !root.isDisk
                        Layout.fillWidth: true
                        Layout.preferredHeight: 360
                        clip: true
                        spacing: 2
                        model: root.procRows
                        delegate: ProcessRow {}
                    }
                }
            }
        }
    }
}

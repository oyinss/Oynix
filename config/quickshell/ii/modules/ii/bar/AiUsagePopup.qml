import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

/**
 * Provider usage panel, revealed by hovering AiUsageIndicator.
 *
 * Unlike the other bar popups this one keeps itself open while the pointer is
 * inside the panel (with a grace period on the way in and out), so the provider
 * tabs stay clickable instead of closing as soon as the pointer leaves the bar
 * item.
 *
 * The pointer has to travel roughly 30 px down from the bar item into the card,
 * and no popup region can cover the bar's own area without stealing bar input,
 * so that trip is protected twice: the input region reaches back up to the panel
 * window's top edge (the "bridge" region on `mask`), and the close grace is long
 * enough for a slow, deliberate move.
 */
LazyLoader {
    id: root

    property Item hoverTarget
    property bool popupHovered: false
    property bool opened: false
    // Panel size used for centring, captured once when the panel window is created.
    // Reading the live implicitWidth here instead re-centres (and therefore moves) the
    // panel whenever its content changes size — a provider switch would slide the panel
    // out from under the cursor, and the hover guard would then close it.
    property real anchorWidth: 0
    property real anchorHeight: 0
    // Wall-clock deadline for the close grace. A deadline rather than an "armed"
    // bool is deliberate: the guard timer in the panel window re-derives it from
    // live hover state on every tick, so a missed hover-out event can only ever
    // close the panel late — it can no longer strand it open over the bar.
    property real graceUntil: 0
    // How long the panel survives with nothing hovered. Deliberately generous:
    // the pointer must cross the bar's own bottom edge on its way down from the
    // bar item (~20 px that no popup region can cover without stealing bar
    // input), and a slow, deliberate move outlasts the old 300 ms window.
    readonly property int closeGrace: 800
    readonly property bool hoveringBar: !!(root.hoverTarget && root.hoverTarget.containsMouse)

    active: root.opened

    // Opening stays imperative: binding `active` to hover state feeds the panel's
    // own hover back into its visibility and trips QML's loop detector. Closing is
    // the guard timer's job, so nothing here references the timer's id (this handler
    // also runs during construction, before child objects exist).
    onHoveringBarChanged: {
        if (root.hoveringBar) {
            root.graceUntil = Date.now() + root.closeGrace;
            root.opened = true;
        }
    }

    onActiveChanged: {
        if (root.active) {
            root.popupHovered = false;
            root.graceUntil = Date.now() + root.closeGrace;
            // Only re-fetch when the snapshot is getting old, so opening the panel
            // shows the current numbers instead of "Refreshing…" every time.
            if (AiUsage.updatedAt <= 0 || (Date.now() / 1000 - AiUsage.updatedAt) > 60)
                AiUsage.refresh();
        } else {
            root.opened = false;
            root.graceUntil = 0;
        }
    }

    function formatDuration(seconds) {
        const total = Math.max(0, Math.round(seconds));
        const days = Math.floor(total / 86400);
        const hours = Math.floor((total % 86400) / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        if (days > 0)
            return `${days}d ${hours}h`;
        if (hours > 0)
            return `${hours}h ${minutes}m`;
        return `${minutes}m`;
    }

    // Local-log windows (Codex CLI) can be a few hours old; say so rather than
    // presenting a stale percentage as live.
    function ageText(seconds) {
        if (!seconds || seconds < 3600)
            return "";
        const hours = seconds / 3600;
        return hours < 24 ? Translation.tr("%1h old").arg(Math.round(hours))
                          : Translation.tr("%1d old").arg(Math.round(hours / 24));
    }

    function updatedText() {
        if (AiUsage.loading)
            return Translation.tr("Refreshing…");
        if (AiUsage.updatedAt <= 0)
            return Translation.tr("No data yet");
        const age = Math.max(0, Math.floor(Date.now() / 1000 - AiUsage.updatedAt));
        if (age < 60)
            return Translation.tr("Updated just now");
        if (age < 3600)
            return Translation.tr("Updated %1m ago").arg(Math.floor(age / 60));
        const stamp = new Date(AiUsage.updatedAt * 1000);
        const label = Qt.formatTime(stamp, "hh:mm");
        return AiUsage.stale ? Translation.tr("Updated %1 · stale").arg(label)
                             : Translation.tr("Updated %1").arg(label);
    }

    component: PanelWindow {
        id: popupWindow
        color: "transparent"

        // Freeze the centring size once the content has been laid out, so later
        // content changes cannot slide the panel (see `anchorWidth` above).
        Component.onCompleted: {
            // Let the layouts finish once before freezing the popup geometry.
            Qt.callLater(() => {
                root.anchorWidth = popupWindow.implicitWidth;
                root.anchorHeight = popupWindow.implicitHeight;
            });
        }

        // The single arbiter of "still open?". It re-reads live hover state on every
        // tick and can only ever close the panel, so a hover-out event that never
        // arrives (the pointer leaving through the unmasked elevation ring, where the
        // window's input region delivers nothing) can no longer strand the panel open
        // above the bar. Opening stays in the bar item's hover handler.
        Timer {
            interval: 150
            repeat: true
            running: true
            onTriggered: {
                if (root.hoveringBar || (hoverArea && hoverArea.containsMouse))
                    root.graceUntil = Date.now() + root.closeGrace;
                else if (Date.now() >= root.graceUntil)
                    root.opened = false;
            }
        }

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

        implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

        // Clicks still land on the card only — the elevation ring around it stays
        // click-through — plus the bridge strip between the bar and the card. The
        // card begins `elevationMargin` below the window's top edge, so without
        // this the pointer leaving the bar item downwards is over no input region
        // at all for a moment, and only the close grace bridges that gap.
        mask: Region {
            item: popupBackground

            Region {
                x: popupBackground.x
                y: 0
                width: popupBackground.width
                height: popupBackground.y
            }
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        // Margins are in screen coordinates, so the bar item has to be mapped through
        // the bar's window. That mapping throws — "Cannot call mapFromItem before item
        // is a member of a window" — while the item is not yet in a window, and a
        // throwing binding leaves the panel at a stale position until something else
        // re-evaluates it (which is how the panel ended up parked somewhere unexpected,
        // and why a content change could move it). Guard on the item's own window and
        // keep the reference, so the binding re-evaluates the moment it joins one.
        margins {
            left: {
                if (!Config.options.bar.vertical) {
                    const target = root.hoverTarget;
                    const targetWindow = target ? target.Window.window : null;
                    if (!root.QsWindow || !targetWindow)
                        return Appearance.sizes.barHeight;
                    // Centre under the bar item, then keep the panel on screen: a wide
                    // panel under a right-side item would otherwise run off the edge.
                    const margin = Appearance.sizes.elevationMargin;
                    const panelWidth = root.anchorWidth > 0 ? root.anchorWidth : popupWindow.implicitWidth;
                    const centered = root.QsWindow.mapFromItem(target, (target.width - panelWidth) / 2, 0).x;
                    const screenWidth = popupWindow.screen ? popupWindow.screen.width : root.QsWindow.width;
                    const maxLeft = screenWidth - panelWidth - margin;
                    return Math.max(margin, Math.min(centered, maxLeft));
                }
                return Appearance.sizes.verticalBarWidth;
            }
            top: {
                if (!Config.options.bar.vertical)
                    return Appearance.sizes.barHeight;
                const target = root.hoverTarget;
                const targetWindow = target ? target.Window.window : null;
                if (!root.QsWindow || !targetWindow)
                    return Appearance.sizes.barHeight;
                const margin = Appearance.sizes.elevationMargin;
                const panelHeight = root.anchorHeight > 0 ? root.anchorHeight : popupWindow.implicitHeight;
                const centered = root.QsWindow.mapFromItem(target, 0, (target.height - panelHeight) / 2).y;
                const screenHeight = popupWindow.screen ? popupWindow.screen.height : root.QsWindow.height;
                const maxTop = screenHeight - panelHeight - margin;
                return Math.max(margin, Math.min(centered, maxTop));
            }
            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }

        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        StyledRectangularShadow {
            target: popupBackground
        }

        Rectangle {
            id: popupBackground
            readonly property real margin: 16
            anchors.fill: parent
            anchors.margins: Appearance.sizes.elevationMargin
            implicitWidth: contentLayout.width + margin * 2
            implicitHeight: contentLayout.implicitHeight + margin * 2
            color: Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            // Hover probe for the guard timer. A hover-enabled MouseArea rather than a
            // HoverHandler: containsMouse is the mechanism the bar items already use
            // reliably, and acceptedButtons: Qt.NoButton keeps it click-transparent so
            // the provider tabs and the Refresh link underneath still get their clicks.
            MouseArea {
                id: hoverArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                // Reach up over the bridge strip, so a pointer on its way down
                // from the bar (which is where it must pass anyway) already counts
                // as hovering the panel.
                anchors.topMargin: -Appearance.sizes.elevationMargin
                anchors.bottom: parent.bottom
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onContainsMouseChanged: root.popupHovered = containsMouse
            }

            ColumnLayout {
                id: contentLayout
                anchors.centerIn: parent
                width: 410
                spacing: 14

                // Provider tabs --------------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: AiUsage.providers

                        Rectangle {
                            id: tab
                            required property var modelData
                            required property int index
                            readonly property bool selected: index === AiUsage.activeIndex
                            readonly property real tabPercent: (modelData.primary === null || modelData.primary === undefined) ? -1 : modelData.primary

                            Layout.fillWidth: true
                            Layout.preferredHeight: 68
                            radius: Appearance.rounding.normal
                            color: tab.selected ? Appearance.colors.colSecondaryContainer
                                                : (tabMouse.containsMouse ? Appearance.colors.colLayer2 : "transparent")
                            border.width: 0

                            ColumnLayout {
                                id: tabColumn
                                anchors.centerIn: parent
                                spacing: 3

                                MaterialSymbol {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: tab.modelData.icon ?? "smart_toy"
                                    iconSize: Appearance.font.pixelSize.large
                                    color: tab.selected ? Appearance.colors.colOnSecondaryContainer
                                                        : Appearance.colors.colOnSurfaceVariant
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: tab.modelData.label
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: tab.selected ? Font.DemiBold : Font.Normal
                                    color: tab.selected ? Appearance.colors.colOnSecondaryContainer
                                                        : Appearance.colors.colOnSurfaceVariant
                                }

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: Math.min(72, Math.max(48, tab.width - 30))
                                    Layout.preferredHeight: 4
                                    radius: 9999
                                    visible: tab.tabPercent >= 0
                                    color: ColorUtils.transparentize(Appearance.colors.colOnSurfaceVariant, 0.75)

                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(100, tab.tabPercent)) / 100
                                        height: parent.height
                                        radius: 9999
                                        color: tab.modelData.warning ? Appearance.m3colors.m3error
                                                                     : (tab.selected ? Appearance.colors.colOnSecondaryContainer
                                                                                     : Appearance.colors.colPrimary)
                                    }
                                }
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // Switching provider rebuilds this row, so the tab under
                                    // the cursor is replaced mid-click; re-arm the grace window
                                    // so the guard cannot read the re-layout as a hover-out and
                                    // close the panel the user is still pointing at.
                                    root.graceUntil = Date.now() + 500;
                                    AiUsage.setActiveProvider(tab.index);
                                }
                            }
                        }
                    }
                }

                // Active provider heading ---------------------------------------
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: AiUsage.activeLabel
                            color: Appearance.colors.colOnSurface
                            font.weight: Font.DemiBold
                            font.pixelSize: Appearance.font.pixelSize.huge
                        }

                        StyledText {
                            visible: text !== ""
                            text: AiUsage.activePlan
                            color: Appearance.colors.colOnSurfaceVariant
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: root.updatedText()
                            color: Appearance.colors.colOnSurfaceVariant
                            opacity: 0.72
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        MaterialSymbol {
                            text: "refresh"
                            iconSize: Appearance.font.pixelSize.large
                            color: refreshHeaderMouse.containsMouse ? Appearance.colors.colPrimary
                                                                   : Appearance.colors.colOnSurfaceVariant

                            MouseArea {
                                id: refreshHeaderMouse
                                anchors.fill: parent
                                anchors.margins: -8
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.graceUntil = Date.now() + 500;
                                    AiUsage.refresh();
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Appearance.colors.colLayer0Border
                }

                // Active provider detail -----------------------------------------
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    visible: AiUsage.active !== null && AiUsage.activeWindows.length > 0

                    Repeater {
                        model: AiUsage.activeWindows

                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 7

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.label
                                color: Appearance.colors.colOnSurface
                                font.weight: Font.DemiBold
                                font.pixelSize: Appearance.font.pixelSize.large
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 8
                                radius: 9999
                                color: ColorUtils.transparentize(Appearance.colors.colOnSurfaceVariant, 0.78)

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(100, modelData.used_percent)) / 100
                                    height: parent.height
                                    radius: 9999
                                    color: modelData.used_percent >= 80 ? Appearance.m3colors.m3error
                                                                        : Appearance.colors.colPrimary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("%1% used").arg(Math.round(modelData.used_percent))
                                    color: modelData.used_percent >= 80 ? Appearance.m3colors.m3error
                                                                        : Appearance.colors.colOnSurface
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                }

                                StyledText {
                                    visible: modelData.resets_in > 0
                                    text: Translation.tr("Resets in %1").arg(root.formatDuration(modelData.resets_in))
                                    color: Appearance.colors.colOnSurfaceVariant
                                    opacity: 0.75
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: root.ageText(modelData.age_seconds)
                                color: Appearance.colors.colOnSurfaceVariant
                                opacity: 0.55
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                // Credits / extra usage, when the provider reports them --------
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: (AiUsage.active?.extras?.length ?? 0) > 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Appearance.colors.colLayer0Border
                    }

                    StyledText {
                        text: Translation.tr("Extra usage")
                        color: Appearance.colors.colOnSurface
                        font.weight: Font.DemiBold
                        font.pixelSize: Appearance.font.pixelSize.large
                    }

                    Repeater {
                        model: AiUsage.active?.extras ?? []

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 5

                            StyledText {
                                text: modelData.label
                                color: Appearance.colors.colOnSurfaceVariant
                                font.weight: Font.DemiBold
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: String(modelData.value ?? "")
                                color: Appearance.colors.colOnSurfaceVariant
                                opacity: 0.85
                            }
                        }
                    }
                }

                // Lanes this account does not publish, stated explicitly --------
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: (AiUsage.active?.notes?.length ?? 0) > 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Appearance.colors.colLayer0Border
                    }

                    Repeater {
                        model: AiUsage.active?.notes ?? []

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true

                            MaterialSymbol {
                                text: "info"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnSurfaceVariant
                                opacity: 0.6
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: String(modelData)
                                color: Appearance.colors.colOnSurfaceVariant
                                opacity: 0.65
                                font.pixelSize: Appearance.font.pixelSize.small
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }

                // Errors ---------------------------------------------------------
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: AiUsage.lastError !== "" ? AiUsage.lastError : (AiUsage.active?.error ?? "")
                    color: Appearance.m3colors.m3error
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.Wrap
                }

                // Footer ---------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Appearance.colors.colLayer0Border
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        Layout.fillWidth: true
                        text: AiUsage.loading ? Translation.tr("Refreshing usage…")
                                              : Translation.tr("Updates every 2 minutes")
                        color: Appearance.colors.colOnSurfaceVariant
                        opacity: 0.55
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }

                    StyledText {
                        text: Translation.tr("Refresh")
                        color: refreshMouse.containsMouse ? Appearance.colors.colPrimaryHover
                                                          : Appearance.colors.colPrimary
                        font.pixelSize: Appearance.font.pixelSize.smaller

                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.graceUntil = Date.now() + 500;
                                AiUsage.refresh();
                            }
                        }
                    }
                }
            }
        }
    }
}

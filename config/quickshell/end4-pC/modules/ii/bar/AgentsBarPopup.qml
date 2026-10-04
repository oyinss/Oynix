import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.widgets
import qs.services

LazyLoader {
    id: root

    property bool opened: false
    property Item anchorItem
    property string selectedProvider: AgentsBar.selectedProvider
    readonly property var providers: [
        { id: "codex", label: "Codex", asset: "codex.svg" },
        { id: "opencode-go", label: "OpenCode Go", asset: "opencodego.svg" },
        { id: "deepseek", label: "DeepSeek", asset: "deepseek.svg" }
    ]
    readonly property var selectedRows: AgentsBar.providerRows.filter(row => row.providerId === root.selectedProvider)
    signal requestClose()

    function openOpenCodeAccountManager() {
        Quickshell.execDetached([
            "bash",
            "-lc",
            `${Config.options.apps.terminal} -e ${Quickshell.env("HOME")}/.opencode/bin/opencode providers login`
        ])
    }

    active: opened

    component: PanelWindow {
        id: popupWindow

        visible: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        implicitWidth: 438 + Appearance.sizes.elevationMargin * 2
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

        anchors.top: true
        anchors.right: true
        margins.top: Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut
        margins.right: Appearance.sizes.hyprlandGapsOut + 4

        WlrLayershell.namespace: "quickshell:agentsBar"
        WlrLayershell.layer: WlrLayer.Overlay

        mask: Region { item: popupBackground }

        Component.onCompleted: GlobalFocusGrab.addDismissable(popupWindow)
        Component.onDestruction: GlobalFocusGrab.removeDismissable(popupWindow)

        Connections {
            target: GlobalFocusGrab
            function onDismissed() { root.requestClose() }
        }

        StyledRectangularShadow { target: popupBackground }

        Rectangle {
            id: popupBackground
            anchors.fill: parent
            anchors.margins: Appearance.sizes.elevationMargin
            implicitWidth: 438
            implicitHeight: popupContent.implicitHeight + 34
            color: Appearance.colors.colLayer1Base
            radius: Appearance.rounding.large
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            ColumnLayout {
                id: popupContent
                anchors.fill: parent
                anchors.margins: 22
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: root.providers

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 76
                            radius: Appearance.rounding.normal
                            color: root.selectedProvider === modelData.id
                                ? Appearance.colors.colPrimary
                                : "transparent"

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.options.custom.agentsBarProvider = modelData.id
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 3

                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: 24
                                    implicitHeight: 24

                                    IconImage {
                                        id: providerLogo
                                        anchors.fill: parent
                                        source: Qt.resolvedUrl(`${Quickshell.shellPath("assets/icons/agentsbar")}/${modelData.asset}`)
                                        implicitSize: 24
                                        smooth: true
                                    }

                                    ColorOverlay {
                                        anchors.fill: providerLogo
                                        source: providerLogo
                                        color: root.selectedProvider === modelData.id
                                            ? Appearance.colors.colOnPrimary
                                            : Appearance.colors.colSubtext
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.label
                                    elide: Text.ElideRight
                                    color: root.selectedProvider === modelData.id
                                        ? Appearance.colors.colOnPrimary
                                        : Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.small
                                }

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: 56
                                    implicitHeight: 5
                                    radius: 3
                                    color: Appearance.colors.colSurfaceContainerHighest

                                    Rectangle {
                                        width: root.selectedProvider === modelData.id ? parent.width * 0.42 : parent.width * 0.12
                                        height: parent.height
                                        radius: parent.radius
                                        color: root.selectedProvider === modelData.id
                                            ? Appearance.colors.colOnPrimary
                                            : Appearance.colors.colPrimary
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Appearance.colors.colLayer0Border
                    opacity: 0.8
                    Layout.topMargin: 10
                    Layout.bottomMargin: 22
                }

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: root.providers.find(provider => provider.id === root.selectedProvider)?.label ?? "Provider"
                            font.pixelSize: Appearance.font.pixelSize.huge
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            text: AgentsBar.loading ? "Refreshing…" : "Updated just now"
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }

                    StyledText {
                        text: root.selectedProvider === "codex" ? "CodexBar" : "Usage"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.normal
                    }
                }

                StyledText {
                    visible: (AgentsBar.providerSources[root.selectedProvider] ?? "").length > 0
                    Layout.fillWidth: true
                    text: `Source: ${AgentsBar.providerSources[root.selectedProvider] ?? "unknown"}`
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    elide: Text.ElideMiddle
                    Layout.topMargin: 6
                }

                RippleButton {
                    visible: root.selectedProvider === "opencode-go"
                    Layout.fillWidth: true
                    implicitHeight: 38
                    buttonRadius: Appearance.rounding.normal
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colPrimaryContainerActive
                    downAction: () => root.openOpenCodeAccountManager()

                    contentItem: RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        MaterialSymbol {
                            text: "manage_accounts"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colPrimary
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: "Manage OpenCode account"
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }

                        MaterialSymbol {
                            text: "open_in_new"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Appearance.colors.colLayer0Border
                    Layout.topMargin: 14
                    Layout.bottomMargin: 22
                }

                Repeater {
                    model: root.selectedRows

                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 7
                        Layout.bottomMargin: 18

                        StyledText {
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 10
                            radius: 5
                            color: Appearance.colors.colSurfaceContainerHighest

                            Rectangle {
                                width: modelData.percent >= 0
                                    ? parent.width * Math.max(0, Math.min(100, modelData.percent)) / 100
                                    : 0
                                height: parent.height
                                radius: parent.radius
                                color: modelData.percent >= 80
                                    ? Appearance.m3colors.m3error
                                    : Appearance.colors.colPrimary
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                Layout.fillWidth: true
                                text: (modelData.value ?? "").length > 0
                                    ? modelData.value
                                    : (modelData.percent >= 0 ? `${modelData.percent}% used` : "Usage unavailable")
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }

                            StyledText {
                                text: modelData.reset
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }
                        }
                    }
                }

                StyledText {
                    visible: root.selectedRows.length === 0
                    Layout.fillWidth: true
                    text: "No usage data returned"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.normal
                    Layout.bottomMargin: 20
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Appearance.colors.colLayer0Border
                    Layout.topMargin: 2
                    Layout.bottomMargin: 18
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    buttonRadius: Appearance.rounding.normal
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colPrimaryContainerActive
                    downAction: () => AgentsBar.refresh()

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2
                        spacing: 10

                        MaterialSymbol {
                            text: "refresh"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colPrimary
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: AgentsBar.loading ? "Refreshing…" : "Refresh usage"
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "Usage supplied by the repo-owned provider helper · click outside to close"
                    color: Appearance.colors.colSubtext
                    opacity: 0.75
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    Layout.topMargin: 18
                }
            }
        }
    }
}

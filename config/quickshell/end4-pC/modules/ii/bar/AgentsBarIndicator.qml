import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets

MouseArea {
    id: root

    property bool opened: false

    readonly property color usageColor: AgentsBar.warning
        ? Appearance.m3colors.m3error
        : Appearance.colors.colOnLayer1

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton

    onClicked: {
        root.opened = !root.opened
        if (root.opened)
            AgentsBar.refresh()
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 3

        Item {
            implicitWidth: 18
            implicitHeight: 18
            opacity: AgentsBar.available ? 1 : 0.6

            IconImage {
                id: providerIcon
                anchors.fill: parent
                source: Qt.resolvedUrl(`${Quickshell.shellPath("assets/icons/agentsbar")}/${AgentsBar.selectedAsset}`)
                implicitSize: 18
                smooth: true
            }

            ColorOverlay {
                anchors.fill: providerIcon
                source: providerIcon
                color: root.usageColor
            }
        }

        StyledText {
            color: root.usageColor
            font.pixelSize: Appearance.font.pixelSize.small
            text: AgentsBar.displayText
            opacity: AgentsBar.available ? 1 : 0.6
        }
    }

    AgentsBarPopup {
        opened: root.opened
        anchorItem: root
        onRequestClose: root.opened = false
    }
}

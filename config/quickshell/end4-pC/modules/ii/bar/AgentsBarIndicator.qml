import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

MouseArea {
    id: root

    property bool opened: false

    readonly property color usageColor: AgentsBar.warning
        ? Appearance.m3colors.m3error
        : Appearance.colors.colOnLayer1
    readonly property color iconBackground: AgentsBar.warning
        ? Appearance.m3colors.m3error
        : Appearance.colors.colPrimary

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

        Rectangle {
            implicitWidth: 24
            implicitHeight: 24
            radius: Appearance.rounding.full
            color: root.iconBackground
            opacity: AgentsBar.available ? 1 : 0.6

            MaterialSymbol {
                anchors.centerIn: parent
                text: "data_usage"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnPrimary
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

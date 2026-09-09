import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

MouseArea {
    id: root

    property bool vertical: false
    readonly property color usageColor: CodexUsage.warning
        ? Appearance.m3colors.m3error
        : Appearance.colors.colOnLayer1

    visible: CodexUsage.available
    hoverEnabled: true
    implicitWidth: vertical ? verticalContent.implicitWidth : horizontalContent.implicitWidth
    implicitHeight: vertical ? verticalContent.implicitHeight : horizontalContent.implicitHeight

    onClicked: Quickshell.execDetached(["codex-desktop"])

    Column {
        id: verticalContent
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 0

        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "smart_toy"
            iconSize: Appearance.font.pixelSize.normal
            color: root.usageColor
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.usageColor
            font.pixelSize: Appearance.font.pixelSize.small
            text: CodexUsage.displayText
        }
    }

    RowLayout {
        id: horizontalContent
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 3

        MaterialSymbol {
            text: "smart_toy"
            iconSize: Appearance.font.pixelSize.normal
            color: root.usageColor
        }

        StyledText {
            color: root.usageColor
            font.pixelSize: Appearance.font.pixelSize.small
            text: CodexUsage.displayText
        }
    }

    StyledToolTip {
        alternativeVisibleCondition: root.containsMouse
        text: CodexUsage.tooltipText
    }
}

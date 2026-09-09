import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

BarButton {
    id: root

    visible: CodexUsage.available
    implicitWidth: contentRow.implicitWidth + 16

    onClicked: Quickshell.execDetached(["codex-desktop"])

    contentItem: RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4

        FluentIcon {
            icon: "bot"
            implicitSize: 16
            color: CodexUsage.warning ? Looks.colors.warning : Looks.colors.fg
        }

        WText {
            color: CodexUsage.warning ? Looks.colors.warning : Looks.colors.fg
            text: CodexUsage.displayText
        }
    }

    BarToolTip {
        extraVisibleCondition: root.shouldShowTooltip
        text: CodexUsage.tooltipText
    }
}

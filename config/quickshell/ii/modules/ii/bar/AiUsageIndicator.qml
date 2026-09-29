import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Bar item for aggregated AI provider usage (see AiUsage service).
 * Shows the active provider's icon and its main quota percentage.
 * Hover reveals AiUsagePopup; left-click refreshes, right-click cycles provider.
 */
MouseArea {
    id: root

    // Colour the primary percentage shown here, not a different hidden window.
    readonly property color usageColor: AiUsage.activePrimaryWarning ? Appearance.m3colors.m3error
                                                                     : Appearance.colors.colOnLayer1
    readonly property bool hasData: AiUsage.active !== null && AiUsage.activePercent >= 0

    implicitWidth: horizontalContent.implicitWidth
    implicitHeight: horizontalContent.implicitHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton)
            AiUsage.cycleProvider();
        else
            AiUsage.refresh();
    }

    RowLayout {
        id: horizontalContent
        anchors.centerIn: parent
        spacing: 3

        MaterialSymbol {
            text: AiUsage.active?.icon ?? "smart_toy"
            iconSize: Appearance.font.pixelSize.normal
            color: root.usageColor
            opacity: root.hasData ? 1 : 0.6
        }

        StyledText {
            color: root.usageColor
            font.pixelSize: Appearance.font.pixelSize.small
            text: AiUsage.displayText
            opacity: root.hasData ? 1 : 0.6
        }
    }

    AiUsagePopup {
        hoverTarget: root
    }
}

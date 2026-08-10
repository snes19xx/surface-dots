import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme

Rectangle {
    id: root
    property QtObject theme: null
    readonly property bool themed: theme !== null
    readonly property bool isDark: !themed
                                  || (theme.isDarkMode === undefined ? true : theme.isDarkMode)

    // Background
    color: themed && theme.bgCard !== undefined ? theme.bgCard : Theme.bgCard
    radius: Theme.radiusOuter

    // Hover 
    HoverHandler { id: hoverHandler }

    // Lift
    scale: hoverHandler.hovered ? 1.005 : 1.0
    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

    // Border
    border.width: (isDark ? 1 : (hoverHandler.hovered ? 1 : 0))
    border.color: {
        if (isDark) {
            return hoverHandler.hovered ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.05)
        }
        if (!hoverHandler.hovered)
            return "transparent"
        if (themed && theme.outlineHover !== undefined)
            return theme.outlineHover
        if (themed && theme.outline !== undefined)
            return theme.outline
        // fallback
        return Qt.rgba(0,0,0,0.12)
    }
    Behavior on border.color { ColorAnimation { duration: 200 } }

    // Content
    default property alias content: container.data
    property int pad: Theme.padCard

    implicitHeight: container.implicitHeight + (pad * 2)
    implicitWidth: container.implicitWidth + (pad * 2)

    // Shadow
    Rectangle {
        z: -1
        anchors.fill: parent
        anchors.topMargin: 10
        color: "black"
        // Slightly softer in light mode 
        opacity: isDark ? 0.22 : 0.14
        radius: parent.radius
    }

    ColumnLayout {
        id: container
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.pad
        spacing: 0
    }
}

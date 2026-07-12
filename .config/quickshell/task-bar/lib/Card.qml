import QtQuick
import QtQuick.Layouts


Rectangle {
    id: root
    property QtObject theme

    readonly property bool isDark: theme.isDarkMode

    color: theme.bgCard
    radius: theme.radiusOuter

    HoverHandler { id: hoverHandler }

    scale: hoverHandler.hovered ? 1.017 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
    }

    border.width: isDark ? 1 : (hoverHandler.hovered ? 1 : 0)

    border.color: {
        if (isDark)
            return hoverHandler.hovered
                   ? Qt.rgba(1,1,1,0.15)
                   : Qt.rgba(1,1,1,0.05)

        if (!hoverHandler.hovered)
            return "transparent"

        return theme.outline
    }

    Behavior on border.color {
        ColorAnimation { duration: 200 }
    }

    default property alias content: container.data

 
   property int pad: theme.padCard

    implicitHeight: container.implicitHeight + (pad * 2)
    implicitWidth: container.implicitWidth + (pad * 2)
    

    Rectangle {
        z: -1
        anchors.fill: parent
        anchors.topMargin: 0
        color: "black"
        opacity: isDark ? 0.22 : 0.14
        radius: parent.radius
    }

    ColumnLayout {
        id: container
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 0
    }
}

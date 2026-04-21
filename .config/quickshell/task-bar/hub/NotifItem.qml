import QtQuick
import QtQuick.Layouts
import "../lib" as Lib

Rectangle {
    id: root
    property int nId: 0
    property string app: "SYSTEM"
    property string summary: "Notification"
    property string body: ""
    property QtObject theme: null
    readonly property bool hasTheme: theme !== null
    readonly property bool isDarkMode: (!hasTheme || (theme.isDarkMode === undefined)) ? true : theme.isDarkMode

    readonly property color cBg:      isDarkMode ? "#2d353b" : (hasTheme ? theme.bgItem     : Qt.rgba(0,0,0,0.05))
    readonly property color cBgHover: (!hasTheme || isDarkMode) ? "#374145" : Qt.rgba(0,0,0,0.08)
    readonly property color cSheen:   (!hasTheme || isDarkMode) ? Qt.rgba(1, 1, 1, 0.06) : theme.subtleFillHover
    readonly property color cRipple:  (!hasTheme || isDarkMode) ? Qt.rgba(1,1,1,0.12)    : theme.hoverSpotlight
    readonly property color cIconBg:  (!hasTheme || isDarkMode) ? Qt.rgba(1,1,1,0.05)    : theme.subtleFill
    readonly property color cAccent:  isDarkMode ? "#a7c080" : (hasTheme ? theme.accent        : "#3c4841")
    readonly property color cFgMuted: isDarkMode ? "#9da9a0" : (hasTheme ? theme.textSecondary : "#232a23")
    readonly property color cFgMain:  isDarkMode ? "#d3c6aa" : (hasTheme ? theme.textPrimary   : "#3c4841")

    signal clicked()

    radius: 16
    color: hovered ? cBgHover : cBg
    antialiasing: true
    border.width: 0

    property bool hovered: false

    // subtle lift on hover
    scale: pressed ? 0.985 : (hovered ? 1.01 : 1.0)
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 140 } }

    // tiny highlight
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: cSheen
        opacity: hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    // ripple
    Lib.Ripple {
        id: ripple
        rippleColor: cRipple
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Rectangle {
            width: 30
            height: 30
            radius: 999
            color: cIconBg
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: "󰋽"
                font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                font.weight: 900
                color: cAccent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: String(root.app).toUpperCase().replace(/\n/g, ' ')
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 9
                font.weight: 900
                color: cFgMuted
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.summary.replace(/\n/g, ' ')
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 12
                font.weight: 800
                color: cFgMain
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.body.replace(/\n/g, ' ')
                visible: root.body !== ""
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 11
                font.weight: 500
                color: cFgMuted
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    property bool pressed: false

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: root.hovered = true
        onExited: root.hovered = false

        onPressed: { root.pressed = true; ripple.burst(mouse.x, mouse.y) }
        onReleased: root.pressed = false

        onClicked: root.clicked()
    }
}
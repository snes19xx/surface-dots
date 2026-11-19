import QtQuick
import QtQuick.Layouts
import "../lib" as Lib

Rectangle {
    id: root
    property int nId: 0
    property string app: "SYSTEM"
    property string summary: "Notification"
    property string body: ""
    property string iconSource: ""
    property double time: 0
    property int count: 1
    property QtObject theme: null
    readonly property bool hasTheme: theme !== null
    readonly property bool isDarkMode: (!hasTheme || (theme.isDarkMode === undefined)) ? true : theme.isDarkMode

    // Fallbacks only without a theme
    readonly property color cBg:      hasTheme ? theme.bgItem        : (isDarkMode ? "#2d353b" : Qt.rgba(0,0,0,0.05))
    readonly property color cBgHover: hasTheme ? theme.bgItemHover   : (isDarkMode ? "#374145" : Qt.rgba(0,0,0,0.08))
    readonly property color cSheen:   hasTheme ? theme.subtleFillHover : Qt.rgba(1, 1, 1, 0.06)
    readonly property color cRipple:  hasTheme ? theme.hoverSpotlight  : Qt.rgba(1,1,1,0.12)
    readonly property color cIconBg:  hasTheme ? theme.subtleFill      : Qt.rgba(1,1,1,0.05)
    readonly property color cAccent:  hasTheme ? theme.accent        : (isDarkMode ? "#a7c080" : "#3c4841")
    readonly property color cFgMuted: hasTheme ? theme.textSecondary : (isDarkMode ? "#9da9a0" : "#232a23")
    readonly property color cFgMain:  hasTheme ? theme.textPrimary   : (isDarkMode ? "#d3c6aa" : "#3c4841")

    signal clicked()

    radius: 16
    color: hovered ? cBgHover : cBg
    antialiasing: true
    border.width: 0

    property bool hovered: false

    // subtle lift on hover
    scale: pressed ? 0.985 : (hovered ? 1.01 : 1.0)
    Behavior on scale { Lib.SpringSnappy {} }
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
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter
            radius: 999
            color: appIconImg.visible ? "transparent" : cIconBg

            Image {
                id: appIconImg
                anchors.centerIn: parent
                width: 34
                height: 34
                visible: status === Image.Ready
                source: root.iconSource
                sourceSize: Qt.size(68, 68)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
            }

            Text {
                anchors.centerIn: parent
                visible: !appIconImg.visible
                text: "󰋽"
                font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
                font.pixelSize: 19
                font.weight: 900
                color: cAccent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: String(root.app).toUpperCase().replace(/\n/g, ' ')
                    textFormat: Text.PlainText
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 9
                    font.weight: 900
                    color: cFgMuted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                }

                Rectangle {
                    visible: root.count > 1
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: countText.implicitWidth + 12
                    implicitHeight: countText.implicitHeight + 2
                    radius: height / 2
                    color: Qt.alpha(cAccent, 0.2)

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: String(root.count)
                        textFormat: Text.PlainText
                        font.family: root.theme ? root.theme.textFont : "Manrope"
                        font.pixelSize: 10
                        font.weight: 800
                        color: cAccent
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: root.time > 0
                    text: Lib.Notifs.ageText(root.time)
                    textFormat: Text.PlainText
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 10
                    font.weight: 600
                    color: cFgMuted
                }
            }

            Text {
                text: root.summary.replace(/\n/g, ' ')
                textFormat: Text.PlainText
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 12
                font.weight: 800
                color: cFgMain
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.body.replace(/\n/g, ' ')
                textFormat: Text.PlainText
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
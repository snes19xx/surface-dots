import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: skin
    required property var ctrl

    property bool isDarkMode: ctrl.isDarkMode

    property url imgDark: Qt.resolvedUrl("livingthings/dark.png")
    property url imgLight: Qt.resolvedUrl("livingthings/light.png")

    QtObject {
        id: theme
        property color card: skin.isDarkMode ? "#172022" : "#EBE9DE"
        property color tile: skin.isDarkMode ? "#232A2E" : "#E2DFD3"
        property color tileHover: skin.isDarkMode ? "#2D353B" : "#D1CEC0"
        property color text: skin.isDarkMode ? "#D3C6AA" : "#5C6A72"
        // configurable via settings (falls back to the built-in default)
        property color accent: skin.ctrl.livingAccent !== "" ? skin.ctrl.livingAccent
                                                            : (skin.isDarkMode ? '#859866' : "#6c8453")
        property color danger: skin.isDarkMode ? "#E67E80" : "#F85552"
        property color activeText: skin.isDarkMode ? "#1e2326" : "#F2F0E5"
        property url activeImg: skin.isDarkMode ? skin.imgDark : skin.imgLight
    }

    // Mask Shape
    Rectangle {
        id: bgMask
        anchors.fill: parent
        radius: 20
        visible: false
    }

    // Bottom Layer (Background + Image)
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask { maskSource: bgMask }

        Rectangle {
            anchors.fill: parent
            color: theme.card
        }

        Image {
            width: parent.width
            height: 150
            anchors.top: parent.top
            source: theme.activeImg
            fillMode: Image.PreserveAspectCrop
            smooth: true
        }
    }

    // Middle Layer: Content
    Item {
        anchors.fill: parent
        z: 1

        // Prevent click-through
        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            onPressed: (mouse) => mouse.accepted = true
            onClicked: (mouse) => mouse.accepted = true
        }

        ColumnLayout {
            anchors.top: parent.top
            anchors.topMargin: 158 // 150 (Image) + 8 (padding)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Text {
                text: "@" + skin.ctrl.userName
                font.family: "Inter"
                font.pixelSize: 15
                font.bold: true
                color: theme.accent
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: skin.ctrl.uptime
                font.family: "Inter"
                font.pixelSize: 12
                color: theme.text
                opacity: 0.7
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Mode 1: Icons
        Item {
            anchors.fill: parent
            opacity: skin.ctrl.pendingCmd === "" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            RowLayout {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Repeater {
                    model: skin.ctrl.buttonsModel
                    Rectangle {
                        Layout.preferredWidth: 65
                        Layout.preferredHeight: 70
                        radius: 12

                        property bool isActive: index === skin.ctrl.currentIndex
                        property bool isHovered: hoverHandler.hovered

                        color: {
                            if (isActive) return theme.accent
                            if (isHovered) return theme.tileHover
                            return theme.tile
                        }

                        scale: (isActive || isHovered) ? 1.05 : 1.0
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: modelData.icon
                                font.family: "JetBrainsMono NF"
                                font.pixelSize: 22
                                color: (parent.parent.isActive || parent.parent.isHovered) ? theme.activeText : theme.text
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: modelData.label
                                font.family: "Inter"
                                font.weight: 600
                                font.pixelSize: 10
                                color: (parent.parent.isActive || parent.parent.isHovered) ? theme.activeText : theme.text
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                        HoverHandler { id: hoverHandler; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                skin.ctrl.currentIndex = index
                                skin.ctrl.initiateAction(modelData.cmd, modelData.label)
                            }
                        }
                    }
                }
            }
        }

        // Mode 2: Confirmation
        Item {
            anchors.fill: parent
            opacity: skin.ctrl.pendingCmd !== "" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            ColumnLayout {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 25
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 15

                Text {
                    text: skin.ctrl.getConfirmText()
                    font.family: "Inter"
                    font.pixelSize: 18
                    font.weight: 700
                    color: theme.text
                    Layout.alignment: Qt.AlignHCenter
                }

                RowLayout {
                    spacing: 15
                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 40
                        radius: 10
                        property bool isHovered: cancelHover.hovered
                        color: (skin.ctrl.confirmIndex === 0 || isHovered) ? theme.tileHover : theme.tile
                        border.width: 1
                        border.color: (skin.ctrl.confirmIndex === 0 || isHovered) ? theme.text : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "No"
                            font.family: "Inter"
                            font.weight: 600
                            color: theme.text
                        }
                        HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: skin.ctrl.cancel() }
                    }
                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 40
                        radius: 10
                        property bool isHovered: confirmHover.hovered
                        color: (skin.ctrl.confirmIndex === 1 || isHovered)
                            ? (skin.ctrl.isDestructive() ? theme.danger : theme.accent)
                            : theme.tile
                        Text {
                            anchors.centerIn: parent
                            text: "Yes"
                            font.family: "Inter"
                            font.weight: 700
                            color: (skin.ctrl.confirmIndex === 1 || isHovered) ? theme.activeText : theme.text
                        }
                        HoverHandler { id: confirmHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: skin.ctrl.run(skin.ctrl.pendingCmd) }
                    }
                }
            }
        }
    }

    // Top Layer: Just Border
    Rectangle {
        anchors.fill: parent
        z: 2
        radius: bgMask.radius
        color: "transparent"
        border.width: 1
        border.color: skin.isDarkMode ? '#d1a8c080' : '#435133'
        antialiasing: true
        enabled: false
    }
}

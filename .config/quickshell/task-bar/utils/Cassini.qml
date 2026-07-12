import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

// "Cassini" skin for my ALT+F4 powermenu.
// by snes19xx, https://github.com/snes19xx/surface-dots 
Item {
    id: skin
    required property var ctrl

    property bool dark: ctrl.isDarkMode

    // Pick a random plate (cassini/1.png .. cassini/13.png) per launch.
    readonly property int imgCount: 13
    property int imgIndex: 1
    Component.onCompleted: imgIndex = Math.floor(Math.random() * imgCount) + 1

    // Black & white palette (+ red / green accents).
    QtObject {
        id: theme
        property color bg:      skin.dark ? "#0c0c0d" : "#fbfbf9"
        property color fg:      skin.dark ? "#161616" : "#f2f2f0"
        property color dim:     skin.dark ? "#8b8b88" : "#6c6c6a"
        property color line:    skin.dark ? "#262628" : "#e3e3df"
        // configurable via settings (falls back to the built-in default)
        property color selBg:   skin.ctrl.cassiniSelBg !== "" ? skin.ctrl.cassiniSelBg
                                                              : (skin.dark ? '#d57fb069' : "#759b61")
        property color selFg:   skin.dark ? "#0c0c0d" : "#fbfbf9"
        property color danger:  skin.dark ? "#e06c75" : "#c0392b"
        property color confirm: skin.dark ? "#7fb069" : "#2e7d32"
        property color onAccent: "#ffffff"
    }

    readonly property int imgWidth: 315
    readonly property int pad: 27

    Rectangle {
        id: shadowSource
        anchors.fill: card
        radius: 9
        color: theme.bg
        visible: false
    }

    // Drop shadow 
    DropShadow {
        anchors.fill: card
        horizontalOffset: 0
        verticalOffset: 8
        radius: 16
        samples: 25
        color: skin.dark ? "#aa000000" : "#55000000"
        source: shadowSource
    }

    // Rounded mask:
    Rectangle {
        id: cardMask
        anchors.fill: parent
        radius: 9
        visible: false
    }

    // Card body
    Item {
        id: card
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask { maskSource: cardMask }

        Rectangle {
            anchors.fill: parent
            color: theme.bg
        }

        // Swallow clicks so the backdrop doesn't dismiss 
        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            onPressed: (m) => m.accepted = true
            onClicked: (m) => m.accepted = true
        }

        // Right: random Cassini photograph
        Image {
            id: photo
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            width: skin.imgWidth
            source: Qt.resolvedUrl("cassini/" + skin.imgIndex + ".png")
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            asynchronous: true
        }

        // divider between content and photo
        Rectangle {
            anchors { top: parent.top; bottom: parent.bottom; right: photo.left }
            width: 1
            color: theme.line
        }

        // Left: content column
        Item {
            id: content
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: photo.left }

            // Header
            ColumnLayout {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: skin.pad }
                spacing: 2

                Text {
                    text: "@" + skin.ctrl.userName
                    font.family: "Newsreader"
                    font.pixelSize: 31
                    renderType: Text.NativeRendering
                    color: skin.dark ? "#f2f2f0" : "#161616"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: "<i>up </i>" + skin.ctrl.uptime.replace(/(\d+)/, "<span style='font-style: normal;'>$1</span><i>") + "</i>"
                    textFormat: Text.StyledText
                    font.family: "CMU Typewriter Text"
                    font.pixelSize: 19
                    renderType: Text.NativeRendering
                    color: theme.dim
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Mode 1: action list
            ColumnLayout {
                anchors {
                    left: parent.left
                    right: parent.right
     
                    top: header.bottom
                    topMargin: 20 // Adjust this pixel value to control the space directly
                    leftMargin: skin.pad - 8
                    rightMargin: skin.pad
                }
                spacing: 2

                opacity: skin.ctrl.pendingCmd === "" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Repeater {
                    model: skin.ctrl.buttonsModel
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 31
                        radius: 6

                        property bool isActive: index === skin.ctrl.currentIndex
                        property bool isHovered: rowHover.hovered
                        property bool isDanger: modelData.cmd === "reboot" || modelData.cmd === "shutdown"
                        readonly property color baseColor: isDanger ? theme.danger : theme.selBg

                        // Selected 
                        color: isActive ? baseColor
                            : (isHovered ? Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.15) : "transparent")
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 9 }
                            text: modelData.label
                            font.family: "Newsreader"
                            font.pixelSize: 22
                            renderType: Text.NativeRendering
                            // Invert text only when selected
                            color: parent.isActive
                                ? (parent.isDanger ? theme.onAccent : theme.selFg)
                                : (parent.isDanger ? theme.danger : (skin.dark ? "#f2f2f0" : "#161616"))
                        }

                        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                skin.ctrl.currentIndex = index
                                skin.ctrl.initiateAction(modelData.cmd, modelData.label)
                            }
                        }
                    }
                }
            }

            // Mode 2: confirmation
            Item {
                anchors.fill: parent
                opacity: skin.ctrl.pendingCmd !== "" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 10
                    width: content.width - skin.pad * 2
                    spacing: 18

                    Text {
                        text: skin.ctrl.getConfirmText()
                        font.family: "Newsreader"
                        font.pixelSize: 23
                        renderType: Text.NativeRendering
                        color: skin.dark ? "#f2f2f0" : "#161616"
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12

                        // No (red)
                        Rectangle {
                            Layout.preferredWidth: 84
                            Layout.preferredHeight: 36
                            radius: 7
                            property bool lit: skin.ctrl.confirmIndex === 0 || noHover.hovered
                            color: lit ? theme.danger : "transparent"
                            border.width: 1
                            border.color: lit ? theme.danger : theme.line
                            Text {
                                anchors.centerIn: parent
                                text: "No"
                                font.family: "CMU Typewriter Text"
                                font.styleName: "Italic"
                                font.pixelSize: 19
                                renderType: Text.NativeRendering
                                color: parent.lit ? theme.onAccent : (skin.dark ? "#f2f2f0" : "#161616")
                            }
                            HoverHandler { id: noHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: skin.ctrl.cancel() }
                        }

                        // Yes (green)
                        Rectangle {
                            Layout.preferredWidth: 84
                            Layout.preferredHeight: 36
                            radius: 7
                            property bool lit: skin.ctrl.confirmIndex === 1 || yesHover.hovered
                            color: lit ? theme.confirm : "transparent"
                            border.width: 1
                            border.color: lit ? theme.confirm : theme.line
                            Text {
                                anchors.centerIn: parent
                                text: "Yes"
                                font.family: "CMU Typewriter Text"
                                font.styleName: "Italic"
                                font.pixelSize: 19
                                renderType: Text.NativeRendering
                                color: parent.lit ? theme.onAccent : (skin.dark ? "#f2f2f0" : "#161616")
                            }
                            HoverHandler { id: yesHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: skin.ctrl.run(skin.ctrl.pendingCmd) }
                        }
                    }
                }
            }
        }
    }

    // Border
    Rectangle {
        anchors.fill: parent
        radius: cardMask.radius
        color: "transparent"
        border.width: skin.dark ? 0.5 : 1
        border.color: skin.dark ? '#2ce4e3e3' : '#44000000'
        antialiasing: true
    }
}
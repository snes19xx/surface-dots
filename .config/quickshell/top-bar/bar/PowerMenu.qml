import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// This is a separate power menu for ALT+F4

PanelWindow {
    id: win
    WlrLayershell.namespace: "power-menu"

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    focusable: true
    Component.onCompleted: win.requestActivate()

    WlrLayershell.exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrLayerKeyboardFocus.Exclusive

    // Theme + Images
    property bool isDarkMode: true
    property url imgDark: Qt.resolvedUrl("dark.png")
    property url imgLight: Qt.resolvedUrl("light.png")

    Process {
        id: themeCheck
        command: ["cat", "/home/snes/.cache/quickshell/theme_mode"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                const mode = text.trim()
                win.isDarkMode = (mode !== "light")
                themeCheck.running = false
            }
        }
    }

    QtObject {
        id: theme
        property color card: win.isDarkMode ? "#172022" : "#EBE9DE"
        property color tile: win.isDarkMode ? "#232A2E" : "#E2DFD3"
        property color tileHover: win.isDarkMode ? "#2D353B" : "#D1CEC0"
        property color text: win.isDarkMode ? "#D3C6AA" : "#5C6A72"
        property color accent: win.isDarkMode ? '#859866' : "#6c8453"
        property color danger: win.isDarkMode ? "#E67E80" : "#F85552"
        property color activeText: win.isDarkMode ? "#1e2326" : "#F2F0E5"
        property url activeImg: win.isDarkMode ? win.imgDark : win.imgLight
    }

    // Uptime/user
    Process {
        id: sysInfo
        command: ["bash", "-c", "whoami; uptime -p | sed 's/up //'"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                const d = data.trim()
                if (d === "") return
                if (/^\d/.test(d)) uptime.text = d
                else userName.text = "@" + d
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: win.isDarkMode ? "#66000000" : "#44ffffff"

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.pendingCmd !== "") {
                    root.pendingCmd = ""
                    root.confirmIndex = 1
                    root.forceActiveFocus()
                } else {
                    Qt.quit()
                }
            }
        }
    }

    FocusScope {
        id: root
        width: 400
        height: 300
        
        // To prevent fractional blur
        x: Math.round((parent.width - width) / 2)
        y: Math.round(((parent.height - height) / 2) + ((1 - Math.min(1, intro)) * 60))
        
        focus: true

        // Entry animation progress
        property real intro: 0
        property real introBlur: 18

        SequentialAnimation {
            running: true

            ParallelAnimation {
                // Main intro: fade/slide/scale driver
                PropertyAnimation {
                    target: root
                    property: "intro"
                    from: 0
                    to: 1
                    duration: 260
                    easing.type: Easing.OutExpo
                }

                // Blur clears as it comes in
                PropertyAnimation {
                    target: root
                    property: "introBlur"
                    from: 18
                    to: 0
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            PropertyAnimation {
                target: root
                property: "intro"
                from: 1
                to: 1.06
                duration: 90
                easing.type: Easing.OutQuad
            }
            PropertyAnimation {
                target: root
                property: "intro"
                from: 1.06
                to: 1
                duration: 140
                easing.type: Easing.OutCubic
            }

            ScriptAction { script: root.forceActiveFocus() }
        }

        // Apply opacity/scale based on intro
        opacity: Math.min(1, intro)
        scale: 0.88 + (0.12 * Math.min(1, intro))

        Keys.enabled: true
        Keys.priority: Keys.BeforeItem
        activeFocusOnTab: true

        Component.onCompleted: {
            root.forceActiveFocus()
            Qt.callLater(() => root.forceActiveFocus())
        }

        property int currentIndex: 0
        property int confirmIndex: 1 
        property string pendingCmd: ""
        property string pendingLabel: ""

        property var buttonsModel: [
            { label: "Lock",     icon: "", cmd: "lock" },
            { label: "Suspend",  icon: "", cmd: "suspend" },
            { label: "Logout",   icon: "", cmd: "logout" },
            { label: "Reboot",   icon: "", cmd: "reboot" },
            { label: "Shutdown", icon: "", cmd: "shutdown" }
        ]

        Keys.onPressed: (e) => {
            const isActivate = (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)

            if (e.key === Qt.Key_Escape) {
                if (root.pendingCmd !== "") {
                    root.pendingCmd = ""
                    root.confirmIndex = 1
                    root.forceActiveFocus()
                } else {
                    Qt.quit()
                }
                e.accepted = true
                return
            }

            // Confirm mode
            if (root.pendingCmd !== "") {
                if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Tab) {
                    root.confirmIndex = (root.confirmIndex === 0) ? 1 : 0
                    e.accepted = true
                    return
                }

                if (isActivate) {
                    if (root.confirmIndex === 1) run(root.pendingCmd)
                    else {
                        root.pendingCmd = ""
                        root.confirmIndex = 1
                        root.forceActiveFocus()
                    }
                    e.accepted = true
                    return
                }

                e.accepted = true
                return
            }

            // Selection mode (Left/Right/Tab + Up/Down)
            if (e.key === Qt.Key_Left || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier))) {
                move(-1); e.accepted = true; return
            }
            if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) {
                move(1); e.accepted = true; return
            }
            if (e.key === Qt.Key_Up) {
                move(-1); e.accepted = true; return
            }
            if (e.key === Qt.Key_Down) {
                move(1); e.accepted = true; return
            }

            if (isActivate) {
                initiateAction(buttonsModel[currentIndex].cmd, buttonsModel[currentIndex].label)
                e.accepted = true
                return
            }
        }

        function move(delta) {
            const count = buttonsModel.length
            let next = currentIndex + delta
            if (next < 0) next = count - 1
            if (next >= count) next = 0
            currentIndex = next
        }

        function initiateAction(cmd, label) {
            pendingCmd = cmd
            pendingLabel = label
            confirmIndex = 1
            root.forceActiveFocus()
        }

        function getConfirmText() {
            if (pendingCmd === "shutdown") return "Power Off?"
            if (pendingCmd === "reboot") return "Reboot System?"
            if (pendingCmd === "logout") return "Log Out?"
            if (pendingCmd === "lock") return "Lock Screen?"
            if (pendingCmd === "suspend") return "Suspend?"
            return "Are you sure?"
        }

        function isDestructive() {
            return (pendingCmd === "shutdown" || pendingCmd === "reboot")
        }

        function run(cmd) {
            if (cmd === "lock") Quickshell.execDetached(["hyprlock"])
            if (cmd === "suspend") Quickshell.execDetached(["systemctl", "suspend"])
            if (cmd === "logout") Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
            if (cmd === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
            if (cmd === "shutdown") Quickshell.execDetached(["systemctl", "poweroff"])
            Qt.quit()
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
                    text: "@" + userName.text.replace("@", "")
                    font.family: "Inter"
                    font.pixelSize: 15
                    font.bold: true
                    color: theme.accent
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    id: uptime
                    text: "..."
                    font.family: "Inter"
                    font.pixelSize: 12
                    color: theme.text
                    opacity: 0.7
                    Layout.alignment: Qt.AlignHCenter
                }

                Text { id: userName; visible: false; text: "User" }
            }

            // Mode 1: Icons
            Item {
                anchors.fill: parent
                opacity: root.pendingCmd === "" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                RowLayout {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Repeater {
                        model: root.buttonsModel
                        Rectangle {
                            Layout.preferredWidth: 65
                            Layout.preferredHeight: 70
                            radius: 12

                            property bool isActive: index === root.currentIndex
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
                                    root.currentIndex = index
                                    root.initiateAction(modelData.cmd, modelData.label)
                                }
                            }
                        }
                    }
                }
            }

            // Mode 2: Confirmation
            Item {
                anchors.fill: parent
                opacity: root.pendingCmd !== "" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                ColumnLayout {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 25
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 15

                    Text {
                        text: root.getConfirmText()
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
                            color: (root.confirmIndex === 0 || isHovered) ? theme.tileHover : theme.tile
                            border.width: 1
                            border.color: (root.confirmIndex === 0 || isHovered) ? theme.text : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "No"
                                font.family: "Inter"
                                font.weight: 600
                                color: theme.text
                            }
                            HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    root.pendingCmd = ""
                                    root.confirmIndex = 1
                                    root.forceActiveFocus()
                                }
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 40
                            radius: 10
                            property bool isHovered: confirmHover.hovered
                            color: (root.confirmIndex === 1 || isHovered)
                                ? (root.isDestructive() ? theme.danger : theme.accent)
                                : theme.tile
                            Text {
                                anchors.centerIn: parent
                                text: "Yes"
                                font.family: "Inter"
                                font.weight: 700
                                color: (root.confirmIndex === 1 || isHovered) ? theme.activeText : theme.text
                            }
                            HoverHandler { id: confirmHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.run(root.pendingCmd) }
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
            border.color: win.isDarkMode ? '#d1a8c080' : '#435133'
            antialiasing: true
            enabled: false
        }
    }
}
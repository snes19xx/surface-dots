import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../theme.js" as Theme
import "../lib" as Lib

FocusScope {
    id: root
    property QtObject theme: null
    signal closeRequested()
    signal actionRequested(string action, string label)

    implicitWidth: parent ? parent.width : 320
    implicitHeight: layout.implicitHeight + 12

    property int currentIndex: 0
    readonly property int columns: 3

    property string uptimeStr: "..."

    Process {
        id: procUptime
        command: ["bash", "-lc", "uptime -p | sed -e 's/^up //g'"]
        running: true
        stdout: StdioCollector { onTextChanged: root.uptimeStr = text.trim() }
    }

    // Theme colors
    readonly property bool isDark: (theme && theme.isDarkMode !== undefined) ? theme.isDarkMode : true
    readonly property color cText: theme ? theme.textPrimary : Theme.fgMain
    readonly property color cSubtle: theme ? theme.subtleFill : Qt.rgba(1,1,1,0.05)
    readonly property color cHoverFill: theme ? theme.subtleFillHover : Qt.rgba(1,1,1,0.12)
readonly property color cActive: isDark 
    ? (theme ? theme.accent : Theme.accent) 
    : '#2e3a13'
    readonly property color cDanger: (theme && theme.accentRed !== undefined) ? theme.accentRed : Theme.accentRed

    // Selection color profiles
    readonly property real selTint:  isDark ? 0.22 : 0.34   
    readonly property real hovTint:  isDark ? 0.14 : 0.22   
    readonly property real iconTint: isDark ? 0.50 : 0.72
    readonly property real textTint: isDark ? 0.18 : 0.32

    function mix(a, b, t) {
        return Qt.rgba(
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            a.a + (b.a - a.a) * t
        )
    }

    focus: true
    activeFocusOnTab: true

    Component.onCompleted: {
        currentIndex = 0 // always start at lock
        forceActiveFocus()
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape) { root.closeRequested(); e.accepted = true; return }
        if (e.key === Qt.Key_Left)   { move(-1); e.accepted = true; return }
        if (e.key === Qt.Key_Right)  { move(1);  e.accepted = true; return }
        if (e.key === Qt.Key_Up)     { move(-columns); e.accepted = true; return }
        if (e.key === Qt.Key_Down)   { move(columns);  e.accepted = true; return }
        if (e.key === Qt.Key_Tab)    { move((e.modifiers & Qt.ShiftModifier) ? -1 : 1); e.accepted = true; return }
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { triggerCurrent(); e.accepted = true; return }
    }

    function move(delta) {
        var next = currentIndex + delta
        if (next < 0) next = 0
        if (next >= repeater.count) next = repeater.count - 1
        currentIndex = next
    }

    function triggerCurrent() {
        if (currentIndex < 0 || currentIndex >= repeater.count) return
        var it = repeater.model[currentIndex]
        root.actionRequested(it.cmd, it.label)
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 2
        spacing: 10

        // Uptime row
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Text {
                text: "Uptime 󰔛"
                font.family: Theme.iconFont
                font.pixelSize: 10
                color: Qt.rgba(root.cText.r, root.cText.g, root.cText.b, 0.70)
            }
            Text {
                text: root.uptimeStr
                font.family: Theme.textFont
                font.pixelSize: 10
                font.weight: 600
                color: Qt.rgba(root.cText.r, root.cText.g, root.cText.b, 0.70)
            }
        }

        GridLayout {
            columns: 3
            columnSpacing: 8
            rowSpacing: 8
            Layout.fillWidth: true

            Repeater {
                id: repeater
                model: [
                    { label: "Lock",      icon: "", cmd: "lock" },
                    { label: "Suspend",   icon: "", cmd: "suspend" },
                    { label: "Logout",    icon: "", cmd: "logout" },
                    { label: "Hibernate", icon: "󰤄", cmd: "hibernate" },
                    { label: "Reboot",    icon: "", cmd: "reboot" },
                    { label: "Shutdown",  icon: "", cmd: "shutdown" }
                ]

                delegate: Rectangle {
                    id: btn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: 12

                    readonly property bool selected: index === root.currentIndex
                    readonly property bool danger: (modelData.cmd === "shutdown" || modelData.cmd === "reboot")
                    readonly property color accentFor: danger ? root.cDanger : root.cActive

                    // Stable base
                    color: root.cSubtle

                    Rectangle {
                        anchors.fill: parent
                        radius: btn.radius
                        color: root.cHoverFill
                        opacity: hovered.hovered && !btn.selected ? (root.isDark ? 0.35 : 0.28) : 0.0
                        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }

                    // Active overlay (green for normal, red for reboot/shutdown)
                    Rectangle {
                        anchors.fill: parent
                        radius: btn.radius
                        color: btn.accentFor
                        opacity: btn.selected ? root.selTint
                                             : (hovered.hovered ? root.hovTint : 0.0)
                        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }

                    // Border 
                    border.width: btn.selected ? 1 : 0
                    border.color: Qt.rgba(btn.accentFor.r, btn.accentFor.g, btn.accentFor.b, root.isDark ? 0.75 : 0.60)

                    // Press feedback
                    scale: tap.pressed ? 0.975 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                    HoverHandler { id: hovered }

                    TapHandler {
                        id: tap
                        onTapped: {
                            root.currentIndex = index
                            root.actionRequested(modelData.cmd, modelData.label)
                        }
                        onPressedChanged: {
                            if (pressed) {
                                root.currentIndex = index
                                ripple.burst(point.position.x, point.position.y)
                            }
                        }
                    }

                    Lib.ClickRipple {
                        id: ripple
                        anchors.fill: parent
                        color: btn.accentFor
                        opacity: 0.16
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            text: modelData.icon
                            font.family: Theme.iconFont
                            font.pixelSize: 20
                            color: (btn.selected || hovered.hovered)
                                   ? root.mix(root.cText, btn.accentFor, root.iconTint)
                                   : root.cText
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: modelData.label
                            font.family: Theme.textFont
                            font.pixelSize: 10
                            font.weight: 650
                            color: btn.selected
                                   ? root.mix(root.cText, btn.accentFor, root.textTint)
                                   : (hovered.hovered
                                      ? Qt.rgba(root.cText.r, root.cText.g, root.cText.b, 0.92)
                                      : Qt.rgba(root.cText.r, root.cText.g, root.cText.b, 0.72))
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }

        // Collapse toggle
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            radius: 10
            color: "transparent"

            HoverHandler { id: collapseHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.closeRequested() }

            Text {
                anchors.centerIn: parent
                text: ""
                font.family: Theme.iconFont
                font.pixelSize: 14
                color: root.cText
                opacity: collapseHover.hovered ? 0.85 : 0.55
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
        }
    }
}

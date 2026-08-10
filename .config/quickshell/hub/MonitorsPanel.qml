import QtQuick
import QtQuick.Layouts
import Quickshell
import "../lib" as Lib

Item {
    id: panel

    required property var theme
    signal closeRequested()
    signal toastRequested(string msg)

    implicitHeight: content.implicitHeight

    readonly property var monitors: Lib.MonitorService.monitors
    property string selected: ""

    function monFor(name) {
        for (var i = 0; i < panel.monitors.length; i++)
            if (panel.monitors[i].name === name) return panel.monitors[i]
        return null
    }

    readonly property var current: monFor(panel.selected) || (panel.monitors.length ? panel.monitors[0] : null)

    // hyprctl reports availableModes as "1920x1080@120.00Hz" strings
    function modesOf(mon) {
        if (!mon || !mon.availableModes) return []
        var seen = {}
        var out  = []
        for (var i = 0; i < mon.availableModes.length; i++) {
            var res = String(mon.availableModes[i]).split("@")[0]
            if (seen[res]) continue
            seen[res] = true
            out.push(res)
        }
        return out
    }

    function ratesOf(mon, res) {
        if (!mon || !mon.availableModes) return []
        var out = []
        for (var i = 0; i < mon.availableModes.length; i++) {
            var m = String(mon.availableModes[i])
            if (m.split("@")[0] !== res) continue
            var hz = String(Math.round(parseFloat(m.split("@")[1].replace("Hz", ""))))
            if (out.indexOf(hz) === -1) out.push(hz)
        }
        return out
    }

    property string pickRes: ""
    property string pickHz:  ""
    property real   pickScale: 1.0

    // Set once the user touches a control, so a poll landing mid-edit does not
    // pull the fields back to what is currently on screen
    property bool edited: false
    property string _syncedName: ""

    function syncFromCurrent() {
        if (!panel.current) return
        panel.pickRes   = panel.current.width + "x" + panel.current.height
        panel.pickHz    = String(Math.round(panel.current.refreshRate))
        panel.pickScale = panel.current.scale
        panel.edited    = false
    }

    onCurrentChanged: {
        if (!panel.current) return
        if (panel.current.name !== panel._syncedName) {
            panel._syncedName = panel.current.name
            panel.syncFromCurrent()
        } else if (!panel.edited) {
            panel.syncFromCurrent()
        }
    }

    // The service only polls on hotplug, so refresh when the panel opens to catch any changes made while it was closed
    onVisibleChanged: if (panel.visible) Lib.MonitorService.refresh()

    function applyMode() {
        if (!panel.current) return
        Lib.MonitorService._mon({
            output:   panel.current.name,
            mode:     panel.pickRes + "@" + panel.pickHz,
            position: "auto",
            scale:    panel.pickScale
        })
        // hyprctl eval is detached and Hyprland applies the mode after it returns,
        // so read back on the settle delay
        panel.edited = false
        Lib.MonitorService.refreshSoon()
        panel.toastRequested(panel.pickRes + " at " + panel.pickHz + "Hz")
    }

    // Small caps label that opens each section
    component SectionLabel: Text {
        font.family:      panel.theme.textFont
        font.pixelSize:   10
        font.weight:      Font.DemiBold
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color:            panel.theme.textSecondary
        opacity:          0.75
    }

    component Chip: Rectangle {
        property alias label: chipText.text
        property bool active: false
        signal picked()

        height: 30
        width:  chipText.implicitWidth + 22
        radius: 9
        color: active
            ? Qt.rgba(panel.theme.accent.r, panel.theme.accent.g, panel.theme.accent.b, 0.35)
            : (chipHover.hovered ? panel.theme.bgItemHover : panel.theme.bgItem)
        Behavior on color { ColorAnimation { duration: 200 } }

        HoverHandler { id: chipHover }
        TapHandler { onTapped: parent.picked ? picked() : picked() }

        Text {
            id: chipText
            anchors.centerIn: parent
            font.family:    panel.theme.textFont
            font.pixelSize: 11
            font.weight:    Font.Medium
            color:          panel.theme.textPrimary
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 200
        maximumFlickVelocity: 2000

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (ev) => {
                var base = scrollAnim.running ? scrollAnim.to : flick.contentY
                var step = Math.abs(ev.angleDelta.y) * 1.1 + 20
                scrollAnim.to = Math.max(0, Math.min(
                    base + (ev.angleDelta.y > 0 ? -step : step),
                    Math.max(0, flick.contentHeight - flick.height)))
                scrollAnim.restart()
                ev.accepted = true
            }
        }
        NumberAnimation {
            id: scrollAnim
            target: flick; property: "contentY"
            duration: 500; easing.type: Easing.OutExpo
        }

    ColumnLayout {
        id: content
        width: flick.width - (flick.contentHeight > flick.height ? 9 : 0)
        spacing: 14

        // HEADER
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 2

            Text {
                text: "Displays"
                font.family:    panel.theme.textFont
                font.pixelSize: 26
                font.weight:    Font.DemiBold
                color:          panel.theme.textPrimary
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Back"
                font.family:    panel.theme.textFont
                font.pixelSize: 12
                font.weight:    Font.Medium
                color:          backHover.hovered ? panel.theme.accent : panel.theme.textSecondary
                Behavior on color { ColorAnimation { duration: 160 } }
                HoverHandler { id: backHover }
                TapHandler { onTapped: panel.closeRequested() }
            }
        }

        // SCREENS
        Repeater {
            model: panel.monitors

            Rectangle {
                required property var modelData
                readonly property bool isCurrent: modelData.name === (panel.current ? panel.current.name : "")

                Layout.fillWidth: true
                Layout.preferredHeight: 58
                radius: 12
                color: isCurrent ? panel.theme.subtleFill : "transparent"
                border.width: 1
                border.color: isCurrent ? panel.theme.accent : panel.theme.outline
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                HoverHandler { id: rowHover }
                TapHandler { onTapped: panel.selected = modelData.name }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            text: modelData.description || modelData.name
                            font.family:    panel.theme.textFont
                            font.pixelSize: 13
                            font.weight:    Font.DemiBold
                            color:          panel.theme.textPrimary
                            elide:          Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.name + "  ·  " + modelData.width + " × " + modelData.height
                                  + "  ·  " + Math.round(modelData.refreshRate) + " Hz  ·  " + modelData.scale + "×"
                            font.family:    panel.theme.textFont
                            font.pixelSize: 11
                            color:          panel.theme.textSecondary
                        }
                    }

                    SectionLabel {
                        visible: Lib.MonitorService.isKnown(modelData.description)
                        text: "configured"
                        color: panel.theme.accent
                        opacity: 0.9
                    }
                }
            }
        }

        // LAYOUT
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 7

            SectionLabel { text: "Layout" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                Repeater {
                    model: [
                        { key: "extend",    label: "Extend" },
                        { key: "duplicate", label: "Duplicate" },
                        { key: "laptop",    label: "Laptop" },
                        { key: "external",  label: "External" }
                    ]

                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 12
                        color: segHover.hovered ? panel.theme.bgItemHover : panel.theme.bgItem
                        Behavior on color { ColorAnimation { duration: 200 } }

                        scale: segHover.hovered ? 1.017 : 1.0
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                        HoverHandler { id: segHover }
                        TapHandler {
                            onTapped: {
                                if (!panel.current) return
                                Lib.MonitorService.apply(modelData.key, panel.current, false)
                                panel.toastRequested(modelData.label)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family:    panel.theme.textFont
                            font.pixelSize: 12
                            font.weight:    Font.Medium
                            color:          panel.theme.textPrimary
                        }
                    }
                }
            }
        }

        // RESOLUTION
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 7
            z: 20

            SectionLabel { text: "Resolution" }

            // The list floats over what follows
            Item {
                id: resField
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                z: 20

                property bool open: false

                Rectangle {
                    id: resBox
                    anchors.fill: parent
                    radius: 10
                    color: resHover.hovered || resField.open ? panel.theme.bgItemHover : panel.theme.bgItem
                    border.width: 1
                    border.color: resField.open ? panel.theme.accent : panel.theme.outline
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    HoverHandler { id: resHover }
                    TapHandler { onTapped: resField.open = !resField.open }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        text: panel.pickRes ? panel.pickRes.replace("x", " × ") : "—"
                        font.family:    panel.theme.textFont
                        font.pixelSize: 12
                        font.weight:    Font.Medium
                        color:          panel.theme.textPrimary
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        text: "▾"
                        font.family:    panel.theme.textFont
                        font.pixelSize: 11
                        color:          panel.theme.textSecondary
                        rotation:       resField.open ? 180 : 0
                        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                }

                Rectangle {
                    id: resList
                    y: resBox.height + 5
                    width: parent.width
                    height: Math.min(resListView.contentHeight + 8, 190)
                    radius: 10
                    color: panel.theme.bgCard
                    border.width: 1
                    border.color: panel.theme.outline
                    clip: true
                    visible: opacity > 0.01
                    opacity: resField.open ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    ListView {
                        id: resListView
                        anchors.fill: parent
                        anchors.margins: 4
                        clip: true
                        model: panel.modesOf(panel.current)
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            required property var modelData
                            width: resListView.width
                            height: 32
                            radius: 8
                            color: modelData === panel.pickRes
                                ? Qt.rgba(panel.theme.accent.r, panel.theme.accent.g, panel.theme.accent.b, 0.35)
                                : (itemHover.hovered ? panel.theme.bgItemHover : "transparent")
                            Behavior on color { ColorAnimation { duration: 150 } }

                            HoverHandler { id: itemHover }
                            TapHandler {
                                onTapped: {
                                    panel.pickRes = modelData
                                    var rates = panel.ratesOf(panel.current, modelData)
                                    if (rates.indexOf(panel.pickHz) === -1 && rates.length)
                                        panel.pickHz = rates[0]
                                    panel.edited = true
                                    resField.open = false
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                text: modelData.replace("x", " × ")
                                font.family:    panel.theme.textFont
                                font.pixelSize: 12
                                color:          panel.theme.textPrimary
                            }
                        }
                    }
                }
            }
        }

        // REFRESH
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 7

            SectionLabel { text: "Refresh rate" }

            Flow {
                Layout.fillWidth: true
                spacing: 7

                Repeater {
                    model: panel.ratesOf(panel.current, panel.pickRes)

                    Chip {
                        required property var modelData
                        label:  modelData + " Hz"
                        active: modelData === panel.pickHz
                        onPicked: { panel.pickHz = modelData; panel.edited = true }
                    }
                }
            }
        }

        // SCALE
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 7

            SectionLabel { text: "Scale" }

            Flow {
                Layout.fillWidth: true
                spacing: 7

                Repeater {
                    model: [1.0, 1.25, 1.33, 1.5, 2.0]

                    Chip {
                        required property var modelData
                        label:  modelData + "×"
                        active: Math.abs(modelData - panel.pickScale) < 0.001
                        onPicked: { panel.pickScale = modelData; panel.edited = true }
                    }
                }
            }
        }

        // FOOTER
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 10

            Text {
                visible: panel.current
                    && Lib.MonitorService.remembered[Lib.MonitorService.keyFor(panel.current)] !== undefined
                text: "Remembered as "
                    + (panel.current ? Lib.MonitorService.remembered[Lib.MonitorService.keyFor(panel.current)] : "")
                    + ". Forget"
                font.family:    panel.theme.textFont
                font.pixelSize: 11
                color:          forgetHover.hovered ? panel.theme.accentRed : panel.theme.textSecondary
                Behavior on color { ColorAnimation { duration: 160 } }

                HoverHandler { id: forgetHover }
                TapHandler {
                    onTapped: {
                        if (!panel.current) return
                        Lib.MonitorService.forget(Lib.MonitorService.keyFor(panel.current))
                        panel.toastRequested("Forgotten")
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 108
                Layout.preferredHeight: 38
                radius: 12
                color: applyHover.hovered
                    ? panel.theme.accent
                    : Qt.rgba(panel.theme.accent.r, panel.theme.accent.g, panel.theme.accent.b, 0.35)
                Behavior on color { ColorAnimation { duration: 200 } }

                scale: applyHover.hovered ? 1.017 : 1.0
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                HoverHandler { id: applyHover }
                TapHandler { onTapped: panel.applyMode() }

                Text {
                    anchors.centerIn: parent
                    text: "Apply mode"
                    font.family:    panel.theme.textFont
                    font.pixelSize: 12
                    font.weight:    Font.DemiBold
                    color:          panel.theme.textPrimary
                }
            }
        }
    }
    }

    // Scrollbar, shown only when the panel is taller than the hub allows
    Rectangle {
        width: 3
        radius: 1.5
        color: panel.theme.textSecondary
        opacity: flick.contentHeight > flick.height ? 0.35 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        anchors.right: parent.right
        height: flick.contentHeight > 0
            ? Math.max(24, flick.height / flick.contentHeight * parent.height)
            : 0
        y: flick.contentHeight > flick.height
            ? (flick.contentY / (flick.contentHeight - flick.height)) * (parent.height - height)
            : 0
    }
}

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

    readonly property var monitors: Lib.MonitorService.allMonitors
    property string selected: ""

    function monFor(name) {
        for (var i = 0; i < panel.monitors.length; i++)
            if (panel.monitors[i].name === name) return panel.monitors[i]
        return null
    }

    function slotLabels(n) {
        if (n === 2) return ["Left", "Right"]
        if (n === 3) return ["Left", "Center", "Right"]
        var out = []
        for (var i = 1; i <= n; i++) out.push(String(i))
        return out
    }

    function firstOn() {
        for (var i = 0; i < panel.monitors.length; i++)
            if (!panel.monitors[i].disabled) return panel.monitors[i]
        return panel.monitors.length ? panel.monitors[0] : null
    }

    readonly property var current: monFor(panel.selected) || firstOn()
    readonly property bool off: panel.current !== null && panel.current.disabled === true

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
    property int    pickTransform: 0

    // Set once the user touches a control, so a poll landing mid-edit does not
    // pull the fields back to what is currently on screen
    property bool edited: false
    property string _syncedName: ""

    function syncFromCurrent() {
        if (!panel.current) return
        panel.pickRes   = panel.current.width + "x" + panel.current.height
        panel.pickHz    = String(Math.round(panel.current.refreshRate))
        panel.pickScale = panel.current.scale
        panel.pickTransform = panel.current.transform & 3
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

    // sends 143.85, not rounded 144
    function exactMode(mon, res, hz) {
        for (var i = 0; i < mon.availableModes.length; i++) {
            var m = String(mon.availableModes[i]).replace("Hz", "")
            if (m.split("@")[0] === res && String(Math.round(parseFloat(m.split("@")[1]))) === hz)
                return m
        }
        return res + "@" + hz
    }

    function applyMode() {
        if (!panel.current) return
        var mode = panel.exactMode(panel.current, panel.pickRes, panel.pickHz)
        Lib.MonitorService._mon({
            output:    panel.current.name,
            mode:      mode,
            position:  panel.current.x + "x" + panel.current.y,
            scale:     panel.pickScale,
            transform: panel.pickTransform
        })
        // save before placeAll runs
        Lib.MonitorService.saveScreen(panel.current, mode, panel.pickScale, panel.pickTransform)
        Lib.MonitorService._placeAfter = true
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

    component SectionHeader: RowLayout {
        property alias text: headLabel.text
        Layout.fillWidth: true
        spacing: 10
        SectionLabel { id: headLabel; font.pixelSize: 11; opacity: 0.85 }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: panel.theme.outline
        }
    }

    component Chip: Rectangle {
        property alias label: chipText.text
        property bool active: false
        signal picked()

        height: 34
        width:  chipText.implicitWidth + 28
        radius: 8
        color: active
            ? Qt.rgba(panel.theme.accent.r, panel.theme.accent.g, panel.theme.accent.b, 0.16)
            : (chipHover.hovered ? panel.theme.bgItemHover : "transparent")
        border.width: 1
        border.color: active ? panel.theme.accent : panel.theme.outline
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 160 } }
        scale: chipTap.pressed ? 0.96 : 1.0
        Behavior on scale { Lib.SpringSnappy {} }

        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: chipTap; onTapped: picked() }

        Text {
            id: chipText
            anchors.centerIn: parent
            font.family:    panel.theme.textFont
            font.pixelSize: 14
            font.weight:    active ? Font.DemiBold : Font.Medium
            color:          active ? panel.theme.accent : panel.theme.textPrimary
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }

    component Scr: Rectangle {
        property color ink: "white"
        color: "transparent"
        border.width: 1.5
        border.color: ink
        radius: 2
    }

    component LayoutGlyph: Item {
        id: glyph
        property string kind: "extend"
        property color ink: panel.theme.textSecondary
        implicitWidth: 34
        implicitHeight: 22

        Scr { ink: glyph.ink; visible: kind === "extend"; x: 0;  y: 3; width: 15; height: 12 }
        Scr { ink: glyph.ink; visible: kind === "extend"; x: 18; y: 3; width: 15; height: 12 }
        Scr { ink: glyph.ink; visible: kind === "duplicate"; x: 8; y: 0; width: 20; height: 13; opacity: 0.5 }
        Scr { ink: glyph.ink; visible: kind === "duplicate"; x: 4; y: 5; width: 20; height: 13 }
        Scr { ink: glyph.ink; visible: kind === "laptop"; x: 6; y: 1; width: 22; height: 13 }
        Rectangle { visible: kind === "laptop"; x: 1; y: 17; width: 32; height: 2; radius: 1; color: glyph.ink }
        Scr { ink: glyph.ink; visible: kind === "external"; x: 5; y: 0; width: 24; height: 14 }
        Rectangle { visible: kind === "external"; x: 15; y: 14; width: 4; height: 4; color: glyph.ink }
        Rectangle { visible: kind === "external"; x: 10; y: 18; width: 14; height: 2; radius: 1; color: glyph.ink }
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
                    base + (ev.angleDelta.y > 0 ? -step : (ev.angleDelta.y < 0 ? step : 0)),
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
                font.family:    Lib.PopupStyle.serif
                font.pixelSize: 30
                font.weight:    Font.Medium
                color:          panel.theme.textPrimary
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Back"
                font.family:    panel.theme.textFont
                font.pixelSize: 14
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
                Layout.preferredHeight: 68
                radius: 8
                color: isCurrent
                    ? Qt.rgba(panel.theme.accent.r, panel.theme.accent.g, panel.theme.accent.b, 0.10)
                    : (rowHover.hovered ? panel.theme.bgItemHover : "transparent")
                border.width: 1
                border.color: isCurrent ? panel.theme.accent : panel.theme.outline
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: panel.selected = modelData.name }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 14

                    LayoutGlyph {
                        kind: "external"
                        ink: isCurrent ? panel.theme.accent : panel.theme.textSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: modelData.description || modelData.name
                            font.family:    panel.theme.textFont
                            font.pixelSize: 15
                            font.weight:    Font.DemiBold
                            color:          panel.theme.textPrimary
                            elide:          Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.name + "  ·  " + modelData.width + " × " + modelData.height
                                  + "  ·  " + Math.round(modelData.refreshRate) + " Hz  ·  " + modelData.scale + "×"
                            font.family:    panel.theme.textFont
                            font.pixelSize: 12
                            color:          panel.theme.textSecondary
                            elide:          Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    SectionLabel {
                        visible: modelData.disabled === true || Lib.MonitorService.isKnown(modelData.description)
                        text: modelData.disabled === true ? "off" : "configured"
                        font.pixelSize: 11
                        color: modelData.disabled === true ? panel.theme.textSecondary : panel.theme.accent
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

            SectionHeader { text: "Layout" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

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
                        Layout.preferredHeight: 78
                        radius: 8
                        color: segHover.hovered
                            ? Qt.rgba(panel.theme.accent.r, panel.theme.accent.g, panel.theme.accent.b, 0.12)
                            : "transparent"
                        border.width: 1
                        border.color: segHover.hovered ? panel.theme.accent : panel.theme.outline
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on border.color { ColorAnimation { duration: 160 } }

                        scale: segTap.pressed ? 0.96 : 1.0
                        Behavior on scale { Lib.SpringSnappy {} }

                        HoverHandler { id: segHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            id: segTap
                            onTapped: {
                                if (!panel.current) return
                                var ext = Lib.MonitorService.externals()
                                if (ext.length >= 2) {
                                    Lib.MonitorService.applyAll(modelData.key === "external" ? "externals" : modelData.key, false)
                                } else {
                                    // layouts target the external
                                    var target = panel.current.name === Lib.MonitorService.laptopOutput
                                        ? (ext.length ? ext[0] : null) : panel.current
                                    if (!target) return
                                    Lib.MonitorService.apply(modelData.key, target, false)
                                }
                                panel.toastRequested(modelData.label)
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            LayoutGlyph {
                                Layout.alignment: Qt.AlignHCenter
                                kind: modelData.key
                                ink: segHover.hovered ? panel.theme.accent : panel.theme.textSecondary
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.label
                                font.family:    panel.theme.textFont
                                font.pixelSize: 14
                                font.weight:    Font.Medium
                                color:          panel.theme.textPrimary
                            }
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
            visible: !panel.off

            SectionHeader { text: "Resolution" }

            // The list floats over what follows
            Item {
                id: resField
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                z: 20

                property bool open: false

                Rectangle {
                    id: resBox
                    anchors.fill: parent
                    radius: 8
                    color: resHover.hovered || resField.open ? panel.theme.bgItemHover : "transparent"
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
                        font.pixelSize: 14
                        font.weight:    Font.Medium
                        color:          panel.theme.textPrimary
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        text: "▾"
                        font.family:    panel.theme.textFont
                        font.pixelSize: 13
                        color:          panel.theme.textSecondary
                        rotation:       resField.open ? 180 : 0
                        Behavior on rotation { Lib.SpringSmooth {} }
                    }
                }

                Rectangle {
                    id: resList
                    y: resBox.height + 5
                    width: parent.width
                    height: Math.min(resListView.contentHeight + 8, 190)
                    radius: 8
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
                            height: 36
                            radius: 8
                            color: modelData === panel.pickRes
                                ? Qt.rgba(panel.theme.accent.r, panel.theme.accent.g, panel.theme.accent.b, 0.16)
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
                                font.pixelSize: 14
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
            visible: !panel.off

            SectionHeader { text: "Refresh rate" }

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
            visible: !panel.off

            SectionHeader { text: "Scale" }

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

        // ROTATION
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 7
            visible: panel.current && !panel.off && panel.current.name !== Lib.MonitorService.laptopOutput

            SectionHeader { text: "Rotation" }

            Flow {
                Layout.fillWidth: true
                spacing: 7

                Repeater {
                    model: [0, 1, 2, 3]

                    Chip {
                        required property var modelData
                        label:  (modelData * 90) + "°"
                        active: modelData === panel.pickTransform
                        onPicked: { panel.pickTransform = modelData; panel.edited = true }
                    }
                }
            }
        }

        // ORDER
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 7
            visible: panel.current
                && Lib.MonitorService.order.length >= 2
                && Lib.MonitorService.order.indexOf(panel.current.name) !== -1

            SectionHeader { text: "Position" }

            Flow {
                Layout.fillWidth: true
                spacing: 7

                Repeater {
                    model: panel.slotLabels(Lib.MonitorService.order.length)

                    Chip {
                        required property var modelData
                        required property int index
                        label:  modelData
                        active: panel.current
                            && Lib.MonitorService.order.indexOf(panel.current.name) === index
                        onPicked: Lib.MonitorService.moveTo(panel.current.name, index)
                    }
                }
            }
        }

        Text {
            visible: panel.off
            Layout.fillWidth: true
            text: "This screen is off. Pick Extend, or Laptop, above to turn it on."
            wrapMode: Text.WordWrap
            font.family:    panel.theme.textFont
            font.pixelSize: 13
            color:          panel.theme.textSecondary
        }

        // FOOTER
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 10
            visible: !panel.off

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
                Layout.preferredWidth: 132
                Layout.preferredHeight: 42
                radius: 8
                color: applyTap.pressed
                    ? Qt.rgba(panel.theme.accent.r, panel.theme.accent.g, panel.theme.accent.b, 0.8)
                    : (applyHover.hovered
                        ? Qt.lighter(panel.theme.accent, 1.1)
                        : panel.theme.accent)
                Behavior on color { ColorAnimation { duration: 160 } }

                scale: applyTap.pressed ? 0.97 : 1.0
                Behavior on scale { Lib.SpringSnappy {} }

                HoverHandler { id: applyHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: applyTap; onTapped: panel.applyMode() }

                Text {
                    anchors.centerIn: parent
                    text: "Apply mode"
                    font.family:    panel.theme.textFont
                    font.pixelSize: 14
                    font.weight:    Font.DemiBold
                    color:          panel.theme.textOnAccent
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

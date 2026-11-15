import QtQuick
import QtQuick.Layouts
import "../lib" as Lib

Item {
    id: root
    property QtObject theme: null
    signal closeRequested()

    //  Theme aliases
    readonly property color rBg:      theme ? theme.bgCard        : "#1e2326"
    readonly property color rItem:    theme ? theme.bgItem        : "#2d353b"
    readonly property color rAccent:  theme ? theme.accent        : "#759b61"
    readonly property color rText:    theme ? theme.textPrimary   : "#dde5df"
    readonly property color rMuted:   theme ? theme.textSecondary : "#9da9a0"
    readonly property color rOutline: theme ? theme.outline       : "#1a2020"
    readonly property bool  rDark:    theme ? theme.isDarkMode    : true
    readonly property string rFont:   theme ? theme.textFont      : "Manrope"

    readonly property bool usable: Lib.PaletteService.available
    readonly property var roleNames: [
        "surface", "surface_container", "surface_container_high", "surface_container_highest",
        "on_surface", "on_surface_variant", "primary", "on_primary",
        "secondary", "tertiary", "error", "outline_variant"
    ]
    readonly property var stripRoles: ["primary", "secondary", "tertiary", "surface", "surface_container_high", "on_surface"]
    readonly property int overrideCount: {
        var o = Lib.Configuration.paletteOverrides || ({})
        return Object.keys(o.dark || ({})).length + Object.keys(o.light || ({})).length
    }

    property bool   showToast: false
    property string toastText: ""
    function triggerToast(msg) {
        root.toastText = msg
        root.showToast = true
        toastTimer.restart()
    }
    Timer { id: toastTimer; interval: 1600; onTriggered: root.showToast = false }

    function roleLabel(r) {
        var s = String(r).replace(/_/g, " ")
        return s.charAt(0).toUpperCase() + s.slice(1)
    }
    function baseName(p) { return String(p).split("/").pop() }

    Component.onCompleted: Lib.PaletteService.ensureLoaded()

    implicitHeight: flickable.contentHeight + 4

    Flickable {
        id: flickable
        anchors.fill: parent
        contentHeight: contentCol.implicitHeight
        contentWidth: width
        clip: true
        flickDeceleration: 160; maximumFlickVelocity: 1800; boundsBehavior: Flickable.StopAtBounds
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (ev) => {
                var base = wAnim.running ? wAnim.to : flickable.contentY
                var step = Math.abs(ev.angleDelta.y) * 1.1 + 24
                var newY = Math.max(0, Math.min(base + (ev.angleDelta.y > 0 ? -step : step),
                    Math.max(0, flickable.contentHeight - flickable.height)))
                wAnim.to = newY; wAnim.restart(); ev.accepted = true
            }
        }
        NumberAnimation { id: wAnim; target: flickable; property: "contentY"; duration: 520; easing.type: Easing.OutExpo }

        ColumnLayout {
            id: contentCol
            width: flickable.width
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: Lib.PaletteService.ready && Lib.PaletteService.wallpaper !== ""
                        ? root.baseName(Lib.PaletteService.wallpaper)
                        : Lib.PaletteService.busy ? "reading wallpaper…" : "wallpaper palettes"
                    elide: Text.ElideMiddle
                    color: root.rText
                    font.family: root.rFont; font.pixelSize: 15; font.weight: 600
                }
                Text {
                    visible: Lib.PaletteService.busy
                    text: "generating…"
                    color: root.rMuted; font.family: root.rFont; font.pixelSize: 12
                }
                Rectangle {
                    Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 7
                    color: refreshHov.hovered
                        ? Qt.rgba(root.rAccent.r, root.rAccent.g, root.rAccent.b, 0.12)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    border.width: 1
                    border.color: refreshHov.hovered ? root.rOutline : "transparent"
                    opacity: root.usable ? 1 : 0.4
                    Text {
                        id: refreshIcon
                        anchors.centerIn: parent; text: ""
                        font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: refreshHov.hovered ? root.rAccent : root.rMuted
                        RotationAnimation {
                            id: spinAnim; target: refreshIcon; property: "rotation"
                            from: 0; to: 360; duration: 600; easing.type: Easing.OutCubic
                        }
                    }
                    HoverHandler { id: refreshHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        enabled: root.usable
                        onTapped: { spinAnim.restart(); Lib.PaletteService.refresh(); root.triggerToast("refreshing…") }
                    }
                }
                SBtn { label: "Back"; onTriggered: root.closeRequested() }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.rOutline; opacity: 0.5 }

            // shows up without matugen, and everything below it goes grey
            SCard {
                visible: !root.usable
                label: "matugen not found"
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: "Wallpaper palettes need matugen and jq. Install with:"
                    color: root.rMuted; font.family: root.rFont; font.pixelSize: 13
                }
                Text {
                    text: "sudo pacman -S matugen"
                    color: root.rAccent; font.family: "DM Mono"; font.pixelSize: 12
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 8
                enabled: root.usable
                opacity: root.usable ? 1 : 0.4

                // Toggle and seed
                SCard {
                    label: "Wallpaper colours"
                    SToggle {
                        label: "Use wallpaper colours"
                        checked: Lib.Configuration.useWallpaperColors
                        onToggled: (v) => { Lib.Configuration.useWallpaperColors = v; Lib.Configuration.save() }
                    }
                    SDivider {}
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text {
                            text: "Seed colour"
                            font.family: root.rFont; font.pixelSize: 14; color: root.rText
                            Layout.fillWidth: true
                        }
                        Row {
                            spacing: 4
                            Repeater {
                                model: Lib.PaletteService.seeds
                                delegate: Rectangle {
                                    required property int index
                                    required property string modelData
                                    readonly property bool sel: index === Lib.PaletteService.seedIndex
                                    width: 32; height: 32; radius: 16
                                    color: "transparent"
                                    border.width: 2
                                    border.color: sel ? root.rAccent : (seedHov.hovered ? root.rOutline : "transparent")
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 22; height: 22; radius: 11
                                        color: modelData
                                        border.width: 1; border.color: root.rOutline
                                    }
                                    HoverHandler { id: seedHov; cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        onTapped: {
                                            Lib.Configuration.paletteSeed = index
                                            Lib.Configuration.save()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Scheme
                SCard {
                    label: "Scheme"
                    Repeater {
                        model: Lib.PaletteService.schemeIds
                        delegate: Rectangle {
                            id: schemeRow
                            required property string modelData
                            readonly property bool sel: Lib.Configuration.paletteScheme === modelData
                            readonly property var cols: Lib.PaletteService.colors(modelData, root.rDark)
                            Layout.fillWidth: true; height: 38; radius: 8
                            color: rowHov.hovered ? (root.theme ? root.theme.bgItemHover : "#374145") : root.rItem
                            Behavior on color { ColorAnimation { duration: 120 } }
                            border.width: 1
                            border.color: sel ? root.rAccent : root.rOutline
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                spacing: 8
                                Text {
                                    text: sel ? "✓" : ""
                                    color: root.rAccent; font.pixelSize: 12; font.bold: true
                                    Layout.preferredWidth: 12
                                }
                                Text {
                                    text: Lib.PaletteService.schemeName(schemeRow.modelData)
                                    Layout.fillWidth: true
                                    color: root.rText; font.family: root.rFont; font.pixelSize: 14
                                    font.weight: schemeRow.sel ? 600 : 400
                                }
                                Row {
                                    spacing: 3
                                    Repeater {
                                        model: root.stripRoles
                                        delegate: Rectangle {
                                            required property string modelData
                                            width: 24; height: 24; radius: 6
                                            color: schemeRow.cols[modelData] !== undefined
                                                ? schemeRow.cols[modelData] : "transparent"
                                            border.width: 1; border.color: root.rOutline
                                        }
                                    }
                                }
                            }
                            HoverHandler { id: rowHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    Lib.Configuration.paletteScheme = schemeRow.modelData
                                    Lib.Configuration.save()
                                }
                            }
                        }
                    }
                }

                // Overrides for each role
                SCard {
                    label: Lib.PaletteService.schemeName(Lib.Configuration.paletteScheme)
                        + ", " + (root.rDark ? "dark" : "light")
                    Repeater {
                        model: root.roleNames
                        delegate: Lib.ColorPicker {
                            required property string modelData
                            theme: root.theme
                            Layout.fillWidth: true
                            label: root.roleLabel(modelData)
                            currentHex: Lib.PaletteService.role(modelData, root.rDark)
                            onPicked: (hex) => Lib.Configuration.setPaletteOverride(root.rDark, modelData, hex)
                        }
                    }
                    SDivider {}
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text {
                            Layout.fillWidth: true
                            text: root.overrideCount > 0
                                ? root.overrideCount + " override" + (root.overrideCount === 1 ? "" : "s") + ", kept across wallpapers"
                                : "Edits are saved per light and dark mode."
                            color: root.rMuted; font.family: root.rFont; font.pixelSize: 12; opacity: 0.7
                        }
                        SBtn {
                            label: "Reset overrides"
                            enabled: root.overrideCount > 0
                            opacity: enabled ? 1 : 0.4
                            onTriggered: { Lib.Configuration.clearPaletteOverrides(); root.triggerToast("overrides cleared") }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 4 }
        }
    }

    //  Toast
    Rectangle {
        z: 99
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 8
        height: 26; radius: 7
        width: toastLabel.implicitWidth + 22
        color: Qt.rgba(root.rBg.r, root.rBg.g, root.rBg.b, 0.94)
        border.width: 1; border.color: root.rAccent
        opacity: root.showToast ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Text {
            id: toastLabel
            anchors.centerIn: parent
            text: root.toastText
            color: root.rAccent
            font.family: "DM Mono"; font.pixelSize: 11
        }
    }

    //  Components, same look as the settings panel

    component SCard: Rectangle {
        id: sc
        default property alias items: scCol.data
        property string label: ""
        Layout.fillWidth: true
        color: root.rBg
        radius: root.theme ? root.theme.radiusOuter : 12
        border.width: 1
        border.color: scHov.hovered
            ? Qt.rgba(root.rAccent.r, root.rAccent.g, root.rAccent.b, 0.45)
            : root.rOutline
        implicitHeight: scCol.implicitHeight + 20
        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }
        HoverHandler { id: scHov }

        ColumnLayout {
            id: scCol
            anchors { fill: parent; margins: 10 }
            spacing: 8
            Text {
                visible: sc.label !== ""
                text: sc.label
                font.family: root.rFont; font.pixelSize: 16; font.weight: 600
                color: root.rAccent; opacity: 0.8
                Layout.bottomMargin: 2
            }
        }
    }

    component SDivider: Rectangle {
        Layout.fillWidth: true; height: 1
        color: root.rOutline; opacity: 0.5
    }

    component SToggle: Item {
        id: tog; property string label: ""; property bool checked: false
        signal toggled(bool v)
        Layout.fillWidth: true
        implicitHeight: togRow.implicitHeight + 10

        Rectangle {
            anchors { fill: parent; leftMargin: -4; rightMargin: -4 }
            radius: 8
            color: togHov.hovered
                ? Qt.rgba(root.rAccent.r, root.rAccent.g, root.rAccent.b, 0.08)
                : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        HoverHandler { id: togHov; cursorShape: Qt.PointingHandCursor }

        RowLayout {
            id: togRow
            anchors { fill: parent; topMargin: 5; bottomMargin: 5 }
            spacing: 8
            Text {
                text: tog.label; font.family: root.rFont; font.pixelSize: 15
                color: root.rText; Layout.fillWidth: true
            }
            Rectangle {
                width: 42; height: 24; radius: 12
                color: tog.checked ? root.rAccent : (root.theme ? root.theme.subtleFill : "#2d353b")
                Behavior on color { ColorAnimation { duration: 200 } }
                border.width: 1; border.color: root.rOutline
                Rectangle {
                    x: tog.checked ? parent.width - width - 3 : 3; y: 3; width: 18; height: 18; radius: 9; color: "white"
                    Behavior on x { Lib.SpringSmooth { epsilon: 0.25 } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tog.toggled(!tog.checked) }
            }
        }
    }

    component SBtn: Item {
        id: sb; property string label: ""; property bool accent: false
        signal triggered()
        implicitWidth: bTxt.implicitWidth + 22; implicitHeight: 30
        scale: bMa.containsPress ? 0.91 : (bMa.containsMouse ? 1.04 : 1.0)
        Behavior on scale { Lib.SpringSnappy {} }
        Rectangle {
            anchors.fill: parent; radius: 8
            color: sb.accent
                ? (bMa.containsPress ? Qt.darker(root.rAccent, 1.08)
                    : bMa.containsMouse ? Qt.lighter(root.rAccent, 1.14) : root.rAccent)
                : (bMa.containsPress ? root.rItem
                    : bMa.containsMouse ? (root.theme ? root.theme.subtleFillHover : "#374145")
                    : (root.theme ? root.theme.subtleFill : "#2d353b"))
            Behavior on color { ColorAnimation { duration: 100 } }
            border.width: 1
            border.color: sb.accent ? Qt.rgba(1, 1, 1, bMa.containsMouse ? 0.18 : 0.0) : root.rOutline
            Behavior on border.color { ColorAnimation { duration: 120 } }
            Text { id: bTxt; anchors.centerIn: parent; text: sb.label
                font.family: root.rFont; font.pixelSize: 14
                color: sb.accent ? (root.theme ? root.theme.textOnAccent : "#232a2e") : root.rText }
        }
        MouseArea { id: bMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: sb.triggered() }
    }
}

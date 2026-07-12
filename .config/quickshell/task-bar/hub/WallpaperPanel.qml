import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Item {
    id: root
    property QtObject theme: null
    // When false (during the open/close animation) the per-thumbnail blur/mask
    // layers are dropped so the heavy effects don't re-render every frame of the
    // fade. Restored to true once the panel is opened and settled.
    property bool live: true
    signal closeRequested()

    //  Theme aliases 
    readonly property color rBg:      theme ? theme.bgCard        : "#1e2326"
    readonly property color rItem:    theme ? theme.bgItem         : "#2d353b"
    readonly property color rAccent:  theme ? theme.accent         : "#759b61"
    readonly property color rText:    theme ? theme.textPrimary    : "#dde5df"
    readonly property color rMuted:   theme ? theme.textSecondary  : "#9da9a0"
    readonly property color rOutline: theme ? theme.outline        : "#1a2020"
    readonly property bool  rDark:    theme ? theme.isDarkMode     : true
    readonly property string rFont:   theme ? theme.textFont       : "Manrope"

    //  State 
    property string appliedFullPath:  ""
    property string appliedThumbPath: ""
    property string appliedFileName:  ""
    property var    palette:          []
    property bool   showToast:        false
    property string toastText:        ""

    function triggerToast(msg) {
        root.toastText = msg
        root.showToast = true
        toastTimer.restart()
    }

    // binary relative to this QML file (hub/../bin/papel)
    readonly property string papelBin: Qt.resolvedUrl("../bin/papel").toString().replace("file://", "")

    implicitHeight: contentCol.implicitHeight

    //  Backend socket 
    ListModel { id: wallpaperModel }

    Socket {
        id: backend
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/papel.sock"
        connected: false
        parser: SplitParser {
            onRead: (data) => {
                var str = data.toString().trim()
                if (str === "") return
                try { wallpaperModel.append(JSON.parse(str)) } catch(e) {}
            }
        }
    }

    // (Re)start the papel backend and reload the thumbnail list. Used on first
    // open and by the refresh button when the user has added new wallpapers.
    function refresh() {
        backend.connected = false
        wallpaperModel.clear()
        Quickshell.execDetached(["bash", "-c",
            "pkill -fx '" + root.papelBin + "' 2>/dev/null; sleep 0.1; " +
            "'" + root.papelBin + "' &"])
        connectTimer.restart()
    }

    Component.onCompleted: refresh()

    Timer { id: connectTimer; interval: 500; onTriggered: backend.connected = true }
    Timer { id: toastTimer;   interval: 1600; onTriggered: root.showToast = false }

    //  Layout 
    ColumnLayout {
        id: contentCol
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 8

        // Mini-header
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Text {
                text: wallpaperModel.count > 0
                    ? wallpaperModel.count + " wallpapers"
                    : backend.connected ? "loading…" : "starting backend…"
                color: root.rText
                font.family: root.rFont; font.pixelSize: 15; font.weight: 600
            }
            Item { Layout.fillWidth: true }
            // Refresh: restarts the backend and re-reads thumbnails so
            // newly-added wallpapers in the folder show up-- will probably automate it in the future
            Rectangle {
                width: 28; height: 28; radius: 7
                color: refreshHov.hovered
                    ? Qt.rgba(root.rAccent.r, root.rAccent.g, root.rAccent.b, 0.12)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                border.width: 1
                border.color: refreshHov.hovered ? root.rOutline : "transparent"
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
                    onTapped: {
                        spinAnim.restart()
                        root.refresh()
                        root.triggerToast("refreshing…")
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.rOutline; opacity: 0.5 }

        // Grid
        Item {
            id: gridWrapper
            Layout.fillWidth: true
            Layout.preferredHeight: 296

            property int cols: 3
            property int gap:  6
            property int cellW: width > 0 ? Math.floor((width - gap * (cols - 1)) / cols) : 150
            property int cellH: Math.floor(cellW * 9 / 16)

            clip: true

            Flickable {
                id: gridFlick
                anchors { fill: parent; rightMargin: 9 }
                contentWidth: width
                contentHeight: wallpaperModel.count > 0
                    ? Math.ceil(wallpaperModel.count / gridWrapper.cols) * (gridWrapper.cellH + gridWrapper.gap)
                    : gridWrapper.height
                flickDeceleration: 200; maximumFlickVelocity: 2000
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (ev) => {
                        var base = gAnim.running ? gAnim.to : gridFlick.contentY
                        var step = Math.abs(ev.angleDelta.y) * 1.1 + 20
                        var newY = Math.max(0, Math.min(
                            base + (ev.angleDelta.y > 0 ? -step : step),
                            Math.max(0, gridFlick.contentHeight - gridFlick.height)))
                        gAnim.to = newY; gAnim.restart(); ev.accepted = true
                    }
                }
                NumberAnimation { id: gAnim; target: gridFlick; property: "contentY"
                    duration: 500; easing.type: Easing.OutExpo }

                Item {
                    width: gridFlick.width
                    height: gridFlick.contentHeight

                    Repeater {
                        model: wallpaperModel
                        delegate: WpThumbnail {
                            x: (index % gridWrapper.cols) * (gridWrapper.cellW + gridWrapper.gap)
                            y: Math.floor(index / gridWrapper.cols) * (gridWrapper.cellH + gridWrapper.gap)
                            width: gridWrapper.cellW
                            height: gridWrapper.cellH
                            live: root.live
                            imagePath:  "file://" + model.thumb_path
                            fileName:   model.file_name
                            thumbIndex: model.index + 1
                            isSelected: model.full_path === root.appliedFullPath
                            onApplyRequested: {
                                root.appliedFullPath  = model.full_path
                                root.appliedThumbPath = model.thumb_path
                                root.appliedFileName  = model.file_name
                                backend.write("apply:" + model.full_path + "\n")
                                backend.flush()
                                root.triggerToast("wallpaper applied")
                                paletteCanvas.extractFrom(model.thumb_path)
                            }
                        }
                    }
                }
            }

            // Scrollbar
            Rectangle {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: 3; radius: 2
                color: Qt.rgba(root.rMuted.r, root.rMuted.g, root.rMuted.b, 0.15)
                opacity: gridFlick.contentHeight > gridFlick.height ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Rectangle {
                    width: parent.width; radius: 2; color: root.rAccent
                    height: gridFlick.contentHeight > 0
                        ? Math.max(20, gridFlick.height / gridFlick.contentHeight * parent.height)
                        : parent.height
                    y: gridFlick.contentHeight > gridFlick.height
                        ? (gridFlick.contentY / (gridFlick.contentHeight - gridFlick.height)) * (parent.height - height)
                        : 0
                    Behavior on y { NumberAnimation { duration: 80 } }
                }
            }

            // Loading placeholder
            Text {
                visible: wallpaperModel.count === 0
                anchors.centerIn: parent
                text: backend.connected ? "loading wallpapers…" : "starting backend…"
                color: root.rMuted; opacity: 0.6
                font.family: root.rFont; font.pixelSize: 13
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.rOutline; opacity: 0.3 }

        // Footer
        RowLayout {
            Layout.fillWidth: true; spacing: 10

            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: root.appliedFileName !== "" ? root.appliedFileName : "no wallpaper selected"
                    color: root.rText; font.family: root.rFont
                    font.pixelSize: 13; font.weight: 600; elide: Text.ElideRight
                }
                RowLayout {
                    spacing: 6
                    Text {
                        text: "~/Pictures/Wallpapers/"
                        color: root.rAccent; font.family: "DM Mono"; font.pixelSize: 11
                    }
                }
            }

            // Palette swatches -- click to copy hex
            Row {
                spacing: 5
                Repeater {
                    model: 6
                    delegate: Item {
                        id: swatchItem
                        width: 32; height: 32

                        property string hexColor: {
                            if (root.palette.length <= index) return ""
                            var c = root.palette[index]
                            var r = Math.round(c.r * 255)
                            var g = Math.round(c.g * 255)
                            var b = Math.round(c.b * 255)
                            var rh = r.toString(16); if (rh.length < 2) rh = "0" + rh
                            var gh = g.toString(16); if (gh.length < 2) gh = "0" + gh
                            var bh = b.toString(16); if (bh.length < 2) bh = "0" + bh
                            return "#" + rh + gh + bh
                        }

                        scale: swHov.hovered ? 1.14 : 1.0
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

                        Rectangle {
                            anchors.fill: parent; radius: 7
                            color: root.palette.length > index
                                ? root.palette[index]
                                : Qt.rgba(root.rItem.r, root.rItem.g, root.rItem.b, 0.6)
                            border.width: 1
                            border.color: swHov.hovered ? root.rAccent : Qt.rgba(1,1,1,0.10)
                            Behavior on color { ColorAnimation { duration: 400 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                        }

                        HoverHandler { id: swHov; cursorShape: Qt.PointingHandCursor }

                        // Hex tooltip
                        Rectangle {
                            visible: swHov.hovered && swatchItem.hexColor !== ""
                            anchors.bottom: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin: 5; z: 20
                            width: tipText.implicitWidth + 12; height: 22; radius: 5
                            color: root.rItem; border.width: 1; border.color: root.rOutline
                            Text {
                                id: tipText
                                anchors.centerIn: parent; text: swatchItem.hexColor
                                font.family: "DM Mono"; font.pixelSize: 10; color: root.rText
                            }
                        }

                        TapHandler {
                            onTapped: {
                                if (swatchItem.hexColor !== "") {
                                    Quickshell.execDetached(["bash", "-c",
                                        "printf '%s' '" + swatchItem.hexColor + "' | wl-copy"])
                                    root.triggerToast("copied " + swatchItem.hexColor)
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 2 }
    }

    //  Toast snackbar 
    Rectangle {
        id: toastRect
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

    //  Palette extractor 
    Canvas {
        id: paletteCanvas; width: 120; height: 75; visible: false
        property string pendingUrl: ""
        function extractFrom(thumbPath) {
            pendingUrl = "file://" + thumbPath
            if (isImageLoaded(pendingUrl)) requestPaint()
            else loadImage(pendingUrl)
        }
        onImageLoaded: requestPaint()
        onPaint: {
            if (pendingUrl === "") return
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.drawImage(pendingUrl, 0, 0, width, height)
            var cols = 3, rows = 2, pal = []
            for (var r = 0; r < rows; r++) {
                for (var c = 0; c < cols; c++) {
                    var px = Math.floor((c + 0.5) * width / cols)
                    var py = Math.floor((r + 0.5) * height / rows)
                    var d = ctx.getImageData(px, py, 1, 1).data
                    pal.push(Qt.rgba(d[0]/255, d[1]/255, d[2]/255, 1.0))
                }
            }
            root.palette = pal
        }
    }

    //  Inline thumbnail component 
    component WpThumbnail: Item {
        id: wpt
        property string imagePath:  ""
        property string fileName:   ""
        property bool   isSelected: false
        property int    thumbIndex: 0
        property bool   isHovered:  false
        property bool   live:       true
        signal applyRequested()

        // Drop shadow
        Rectangle {
            visible: wpt.live
            x: 5; y: wpt.isHovered ? 10 : 6
            width: parent.width - 10; height: parent.height - 10; radius: 8
            color: "black"; opacity: wpt.isHovered ? 0.30 : 0.07
            Behavior on y       { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 280 } }
            layer.enabled: wpt.live
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 20 }
        }

        Item {
            id: wptC
            x: 4; y: wpt.isHovered ? 2 : 5
            width: parent.width - 8; height: parent.height - 8
            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            Rectangle { anchors.fill: parent; radius: 7; color: root.rItem }

            Image {
                id: wptImg
                anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                source: wpt.imagePath; sourceSize.width: 320
                asynchronous: true; cache: true; smooth: true; mipmap: true
                opacity: status === Image.Ready ? 1.0 : 0.0
                scale: wpt.isHovered ? 1.04 : 1.0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on scale   { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                // Masked-rounded layer
                layer.enabled: wpt.live
                layer.effect: MultiEffect {
                    maskEnabled: true; maskSource: wptMask
                    brightness: wpt.isHovered ? 0.06 : 0.0
                    Behavior on brightness { NumberAnimation { duration: 260 } }
                }
            }
            Rectangle { id: wptMask; anchors.fill: parent; radius: 7; visible: false; layer.enabled: wpt.live }

            // Shimmer while loading
            Rectangle {
                anchors.fill: parent; radius: 7; color: root.rItem
                visible: wptImg.status !== Image.Ready; clip: true
                Rectangle {
                    width: parent.width * 1.6; height: parent.height; rotation: 15
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(root.rAccent.r, root.rAccent.g, root.rAccent.b, 0.06) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    SequentialAnimation on x {
                        loops: Animation.Infinite; running: wptImg.status !== Image.Ready
                        NumberAnimation { from: -wptC.width; to: wptC.width; duration: 1400 }
                    }
                }
            }

            // Index badge
            Rectangle {
                x: 5; y: 5; radius: 4
                width: idxT.width + 10; height: 18
                color: Qt.rgba(root.rBg.r, root.rBg.g, root.rBg.b, 0.72)
                border.width: 1; border.color: root.rOutline
                Text { id: idxT; anchors.centerIn: parent
                    text: String(wpt.thumbIndex).padStart(2, "0")
                    color: root.rText; font.pixelSize: 9 }
            }

            // Check badge (selected)
            Item {
                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 5
                width: 18; height: 18
                opacity: wpt.isSelected ? 1.0 : 0.0
                scale:   wpt.isSelected ? 1.0 : 0.5
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                Rectangle { anchors.fill: parent; radius: 9; color: root.rAccent }
                Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 9; font.bold: true }
            }

            // Caption overlay
            Item {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.height * 0.42; clip: true
                opacity: (wpt.isHovered || wpt.isSelected) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0.04, 0.05, 0.06, 0.80) }
                    }
                }
                Text {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    anchors.bottomMargin: 5; anchors.leftMargin: 7; anchors.rightMargin: 7
                    text: wpt.fileName; color: "#f3efe7"
                    font.pixelSize: 9; elide: Text.ElideRight
                }
            }

            // Selection / hover border
            Rectangle {
                anchors.fill: parent; radius: 7; color: "transparent"
                border.width: 2; border.color: root.rAccent
                opacity: wpt.isSelected ? 1.0 : wpt.isHovered ? 0.45 : 0.0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            // Click pulse ring
            Rectangle {
                id: pulseR; anchors.fill: parent; radius: 7; color: "transparent"
                border.width: 2
                border.color: Qt.rgba(root.rAccent.r, root.rAccent.g, root.rAccent.b, 0.8)
                opacity: 0
                function trigger() {
                    pulseA.stop(); pulseR.opacity = 0.85; pulseR.scale = 0.95; pulseA.start()
                }
                ParallelAnimation {
                    id: pulseA
                    NumberAnimation { target: pulseR; property: "opacity"; to: 0; duration: 480 }
                    NumberAnimation { target: pulseR; property: "scale"; to: 1.02; duration: 480 }
                }
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: wpt.isHovered = true
                onExited:  wpt.isHovered = false
                onClicked: { pulseR.trigger(); wpt.applyRequested() }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications

// Text is copied out so the exit animation survives the sender closing it.
Item {
    id: toast

    required property var theme
    required property int nid

    // null once closed
    property var notif: null

    property string appName: ""
    property string summary: ""
    property string body: ""
    property string appIcon: ""
    property string image: ""
    property int urgency: NotificationUrgency.Normal
    property int timeoutMs: 0
    property var actionList: []
    property bool hasDefaultAction: false

    signal closeRequested()
    signal expired()

    readonly property string fontText: theme.textFont
    readonly property string fontIcon: theme.iconFont
    // pixelSize is an int
    readonly property int appSize: Math.round(10.5)
    readonly property int appWeight: Font.DemiBold
    readonly property real appSpacing: 0.8
    readonly property int summarySize: 13
    readonly property int summaryWeight: Font.DemiBold
    readonly property int bodySize: Math.round(12.5)
    readonly property int bodyWeight: Font.Medium
    readonly property real bodyLine: 1.35
    readonly property int actionSize: 12
    readonly property int actionWeight: Font.DemiBold

    readonly property int pad: 14
    readonly property bool critical: urgency === NotificationUrgency.Critical
    readonly property bool hovered: hover.hovered
    readonly property bool dragging: ma.drag.active
    readonly property real tintAlpha: theme.isDarkMode ? 0.14 : 0.12

    property real appear: 0

    readonly property string iconSource: {
        var name = toast.appIcon
        if (name === "") return ""
        if (name.indexOf("image://") === 0) return name
        if (name.indexOf("file://") === 0) return name
        if (name.charAt(0) === "/") return "file://" + name
        return Quickshell.iconPath(name, true)
    }
    readonly property string imageSource: {
        var src = toast.image
        if (src === "") return ""
        return src.charAt(0) === "/" ? "file://" + src : src
    }
    // img tags load remote images
    readonly property string safeBody: toast.body.replace(/<img\b[^>]*>/gi, "")
    readonly property var shownActions: toast.actionList.filter(a => a.identifier !== "default" && a.text !== "")

    implicitHeight: card.height
    height: implicitHeight

    function adopt(n) {
        notif = n
        _sync()
    }

    function _sync() {
        if (!notif) return
        appName = notif.appName
        summary = notif.summary
        body = notif.body
        appIcon = notif.appIcon
        image = notif.image
        urgency = notif.urgency
        var list = []
        var def = false
        for (var i = 0; i < notif.actions.length; i++) {
            var a = notif.actions[i]
            list.push({ identifier: a.identifier, text: a.text })
            if (a.identifier === "default") def = true
        }
        actionList = list
        hasDefaultAction = def
        timeoutMs = Notifs.popupTimeout(notif)
        // updates restart the countdown
        elapsedMs = 0
    }

    function invoke(identifier) {
        if (!notif) return
        for (var i = 0; i < notif.actions.length; i++) {
            if (notif.actions[i].identifier === identifier) {
                notif.actions[i].invoke()
                break
            }
        }
        closeRequested()
    }

    // web and mail links only
    function openLink(url) {
        if (/^(https?|mailto):/i.test(url)) Qt.openUrlExternally(url)
    }

    function playExit() { exitAnim.start() }

    Component.onCompleted: {
        adopt(Notifs.find(nid))
        enterAnim.start()
    }

    Connections {
        target: toast.notif
        ignoreUnknownSignals: true
        function onSummaryChanged() { toast._sync() }
        function onBodyChanged() { toast._sync() }
        function onAppNameChanged() { toast._sync() }
        function onAppIconChanged() { toast._sync() }
        function onImageChanged() { toast._sync() }
        function onActionsChanged() { toast._sync() }
        function onClosed() { toast.notif = null }
    }

    NumberAnimation {
        id: enterAnim
        target: toast
        property: "appear"
        to: 1
        duration: 300
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: exitAnim
        PropertyAction { target: toast; property: "ListView.delayRemove"; value: true }
        NumberAnimation { target: toast; property: "appear"; to: 0; duration: 220; easing.type: Easing.InCubic }
        PropertyAction { target: toast; property: "clip"; value: true }
        NumberAnimation { target: toast; property: "height"; to: 0; duration: 240; easing.type: Easing.OutQuint }
        PropertyAction { target: toast; property: "ListView.delayRemove"; value: false }
    }

    // paused on hover and drag
    property real elapsedMs: 0
    property bool timedOut: false
    readonly property real remain: timeoutMs > 0 ? Math.max(0, 1 - elapsedMs / timeoutMs) : 1
    FrameAnimation {
        id: timeoutAnim
        running: toast.timeoutMs > 0 && !toast.timedOut && toast.appear >= 1
            && !toast.hovered && !toast.dragging
        onTriggered: {
            toast.elapsedMs += frameTime * 1000
            if (toast.elapsedMs >= toast.timeoutMs) {
                toast.timedOut = true
                toast.expired()
            }
        }
    }

    Item {
        id: lift
        width: toast.width
        height: card.height
        opacity: toast.appear
        transform: Translate { x: (1 - toast.appear) * 56 }

        // swipe right to dismiss
        Item {
            id: slide
            width: parent.width
            height: parent.height

            Behavior on x {
                enabled: !ma.drag.active
                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
            }

            // inset to hide under card
            Rectangle {
                id: shadowSrc
                anchors.fill: card
                anchors.margins: 1
                radius: card.radius
                color: "black"
                visible: false
            }
            MultiEffect {
                anchors.fill: shadowSrc
                source: shadowSrc
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: toast.theme.isDarkMode ? 0.5 : 0.26
                shadowBlur: 1.0
                shadowVerticalOffset: 6
                z: -1
            }

            Rectangle {
                id: card
                width: parent.width
                height: row.implicitHeight + toast.pad * 2 + (toast.timeoutMs > 0 ? 6 : 0)
                radius: toast.theme.radiusOuter
                color: ma.pressed && !ma.drag.active
                    ? Qt.tint(toast.theme.bgCard, Qt.alpha(toast.theme.accent, toast.tintAlpha + 0.04))
                    : toast.hovered
                        ? Qt.tint(toast.theme.bgCard, Qt.alpha(toast.theme.accent, toast.tintAlpha))
                        : toast.theme.bgCard
                border.width: 1
                border.color: toast.critical ? Qt.alpha(toast.theme.accentRed, 0.6) : toast.theme.outline
                scale: ma.pressed && !ma.drag.active ? 0.985 : 1.0
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }

                // middle click always closes
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    drag.target: slide
                    drag.axis: Drag.XAxis
                    drag.minimumX: 0
                    drag.maximumX: toast.width
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) toast.closeRequested()
                        else if (toast.hasDefaultAction) toast.invoke("default")
                        else toast.closeRequested()
                    }
                    onReleased: {
                        if (slide.x > toast.width * 0.4) toast.closeRequested()
                        else slide.x = 0
                    }
                }

                RowLayout {
                    id: row
                    x: toast.pad
                    y: toast.pad
                    width: card.width - toast.pad * 2
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        Layout.alignment: Qt.AlignTop
                        radius: 999
                        color: toast.critical ? Qt.alpha(toast.theme.accentRed, 0.16) : toast.theme.subtleFill

                        Image {
                            id: appImg
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            source: toast.iconSource !== "" ? toast.iconSource : Qt.resolvedUrl("notify.svg")
                            sourceSize: Qt.size(44, 44)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            // black fallback svg, tinted below
                            visible: toast.iconSource !== ""
                        }
                        MultiEffect {
                            anchors.fill: appImg
                            source: appImg
                            visible: toast.iconSource === ""
                            // tint can't multiply black
                            brightness: 1.0
                            colorization: 1.0
                            colorizationColor: toast.critical ? toast.theme.accentRed : toast.theme.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: (toast.appName !== "" ? toast.appName : "System").toUpperCase()
                                textFormat: Text.PlainText
                                font.family: toast.fontText
                                font.pixelSize: toast.appSize
                                font.weight: toast.appWeight
                                font.letterSpacing: toast.appSpacing
                                color: toast.critical ? toast.theme.accentRed : toast.theme.textSecondary
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Rectangle {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                Layout.topMargin: -3
                                radius: 999
                                color: closeMa.containsMouse ? Qt.alpha(toast.theme.accent, toast.tintAlpha) : "transparent"
                                opacity: toast.hovered ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                                Behavior on color { ColorAnimation { duration: 140 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    font.family: toast.fontIcon
                                    font.pixelSize: 10
                                    color: toast.theme.textSecondary
                                }
                                MouseArea {
                                    id: closeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: toast.closeRequested()
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: toast.summary !== ""
                            text: toast.summary
                            textFormat: Text.PlainText
                            font.family: toast.fontText
                            font.pixelSize: toast.summarySize
                            font.weight: toast.summaryWeight
                            color: toast.theme.textPrimary
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: toast.body !== ""
                            text: toast.safeBody
                            textFormat: Text.StyledText
                            font.family: toast.fontText
                            font.pixelSize: toast.bodySize
                            font.weight: toast.bodyWeight
                            lineHeight: toast.bodyLine
                            lineHeightMode: Text.ProportionalHeight
                            color: toast.theme.textSecondary
                            linkColor: toast.theme.accent
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            onLinkActivated: link => toast.openLink(link)
                        }

                        Flow {
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            visible: toast.shownActions.length > 0
                            spacing: 6

                            Repeater {
                                model: toast.shownActions

                                Rectangle {
                                    id: btn
                                    required property var modelData
                                    width: label.implicitWidth + 28
                                    height: 28
                                    radius: 8
                                    color: btnMa.pressed
                                        ? Qt.tint(toast.theme.subtleFill, Qt.alpha(toast.theme.accent, toast.tintAlpha + 0.04))
                                        : btnMa.containsMouse
                                            ? Qt.tint(toast.theme.subtleFill, Qt.alpha(toast.theme.accent, toast.tintAlpha))
                                            : toast.theme.subtleFill
                                    border.width: 1
                                    border.color: toast.theme.outline
                                    Behavior on color { ColorAnimation { duration: 140 } }

                                    Text {
                                        id: label
                                        anchors.centerIn: parent
                                        text: btn.modelData.text
                                        textFormat: Text.PlainText
                                        font.family: toast.fontText
                                        font.pixelSize: toast.actionSize
                                        font.weight: toast.actionWeight
                                        color: toast.theme.textPrimary
                                    }
                                    MouseArea {
                                        id: btnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: toast.invoke(btn.modelData.identifier)
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        Layout.alignment: Qt.AlignTop
                        visible: toast.imageSource !== ""

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: toast.theme.subtleFill
                        }
                        Image {
                            id: thumbImg
                            anchors.fill: parent
                            source: toast.imageSource
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(112, 112)
                            asynchronous: true
                            smooth: true
                            visible: false
                        }
                        Item {
                            id: thumbMask
                            anchors.fill: parent
                            layer.enabled: true
                            visible: false
                            Rectangle { anchors.fill: parent; radius: 12; color: "black" }
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: thumbImg
                            maskEnabled: true
                            maskSource: thumbMask
                            visible: thumbImg.status === Image.Ready
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: "transparent"
                            border.width: 1
                            border.color: toast.theme.outline
                        }
                    }
                }

                Rectangle {
                    visible: toast.timeoutMs > 0
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: toast.pad
                    anchors.rightMargin: toast.pad
                    anchors.bottomMargin: 8
                    height: 2
                    radius: 1
                    color: toast.theme.subtleFill

                    Rectangle {
                        width: parent.width * toast.remain
                        height: parent.height
                        radius: 1
                        color: toast.theme.accent
                        opacity: 0.75
                    }
                }
            }
        }
    }
}

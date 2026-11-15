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
    readonly property int labelSize: Math.round(10.5)
    readonly property int labelWeight: Font.DemiBold
    readonly property real labelSpacing: 0.9
    readonly property int summarySize: 14
    readonly property int summaryWeight: Font.DemiBold
    readonly property real summarySpacing: -0.1
    readonly property int bodySize: Math.round(12.5)
    readonly property int bodyWeight: Font.Medium
    readonly property real bodyLine: 1.4
    readonly property int actionSize: 12
    readonly property int actionWeight: Font.DemiBold

    readonly property int pad: 16
    readonly property bool critical: urgency === NotificationUrgency.Critical
    readonly property bool low: urgency === NotificationUrgency.Low
    readonly property bool hovered: hover.hovered
    readonly property bool dragging: ma.drag.active
    readonly property color accentColor: critical ? theme.accentRed : theme.accent

    property real appear: 0

    readonly property double born: Date.now()
    property string ageText: "now"
    function _age() {
        var m = Math.floor((Date.now() - born) / 60000)
        ageText = m < 1 ? "now" : m < 60 ? m + "m" : Math.floor(m / 60) + "h"
    }
    Timer { interval: 20000; repeat: true; running: true; onTriggered: toast._age() }

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
        if (src.charAt(0) === "/") return "file://" + src
        // local only, no network fetches
        if (src.indexOf("image://") === 0) return src.indexOf("://", 8) < 0 ? src : ""
        if (src.indexOf("file://") === 0) return src
        return ""
    }
    readonly property string safeBody: Notifs.safeBody(toast.body)
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
        function onUrgencyChanged() { toast._sync() }
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
    FrameAnimation {
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
        opacity: toast.appear * (toast.low ? 0.82 : 1.0)
        transform: Translate { x: (1 - toast.appear) * 56 }

        // swipe right to dismiss
        Item {
            id: slide
            width: parent.width
            height: parent.height
            scale: ma.pressed && !ma.drag.active ? 0.985 : toast.hovered ? 1.01 : 1.0

            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
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
            // ambient shadow
            MultiEffect {
                anchors.fill: shadowSrc
                source: shadowSrc
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: (toast.theme.isDarkMode ? 0.42 : 0.2) * (toast.hovered ? 1.25 : 1.0)
                shadowBlur: 1.0
                shadowVerticalOffset: toast.hovered ? 16 : 12
                z: -2
                Behavior on shadowVerticalOffset { NumberAnimation { duration: 180 } }
            }
            // contact shadow
            MultiEffect {
                anchors.fill: shadowSrc
                source: shadowSrc
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: toast.theme.isDarkMode ? 0.5 : 0.22
                shadowBlur: 0.25
                shadowVerticalOffset: 2
                z: -1
            }

            Rectangle {
                id: card
                width: parent.width
                height: row.implicitHeight + toast.pad * 2
                radius: toast.theme.radiusOuter + 4

                // lifted a step in dark
                readonly property color base: toast.theme.isDarkMode
                    ? Qt.tint(toast.theme.bgCard, toast.theme.subtleFill) : toast.theme.bgCard
                readonly property color toned: toast.critical
                    ? Qt.tint(base, Qt.alpha(toast.theme.accentRed, 0.12)) : base
                color: ma.pressed && !ma.drag.active
                    ? Qt.tint(toned, Qt.alpha(toast.theme.accent, 0.11))
                    : toast.hovered ? Qt.tint(toned, Qt.alpha(toast.theme.accent, 0.07)) : toned
                Behavior on color { ColorAnimation { duration: 160 } }

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
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignTop
                        radius: 999
                        color: Qt.alpha(toast.accentColor, 0.16)

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
                            colorizationColor: toast.accentColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: (toast.appName !== "" ? toast.appName : "System").toUpperCase()
                                textFormat: Text.PlainText
                                font.family: toast.fontText
                                font.pixelSize: toast.labelSize
                                font.weight: toast.labelWeight
                                font.letterSpacing: toast.labelSpacing
                                color: toast.accentColor
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            // hover swaps age for close
                            Item {
                                Layout.preferredWidth: Math.max(ageLabel.implicitWidth, closeGlyph.implicitWidth)
                                Layout.preferredHeight: ageLabel.implicitHeight

                                Text {
                                    id: ageLabel
                                    anchors.right: parent.right
                                    text: toast.ageText
                                    textFormat: Text.PlainText
                                    font.family: toast.fontText
                                    font.pixelSize: toast.labelSize
                                    font.weight: toast.labelWeight
                                    font.letterSpacing: toast.labelSpacing
                                    color: toast.theme.textSecondary
                                    opacity: toast.hovered ? 0 : 1
                                    Behavior on opacity { NumberAnimation { duration: 140 } }
                                }
                                Text {
                                    id: closeGlyph
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ""
                                    font.family: toast.fontIcon
                                    font.pixelSize: toast.labelSize
                                    color: closeMa.containsMouse ? toast.accentColor : toast.theme.textSecondary
                                    opacity: toast.hovered ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 140 } }
                                    MouseArea {
                                        id: closeMa
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        enabled: toast.hovered
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: toast.closeRequested()
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            visible: toast.summary !== ""
                            text: toast.summary
                            textFormat: Text.PlainText
                            font.family: toast.fontText
                            font.pixelSize: toast.summarySize
                            font.weight: toast.summaryWeight
                            font.letterSpacing: toast.summarySpacing
                            color: toast.theme.textPrimary
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 3
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
                            Layout.topMargin: 12
                            visible: toast.shownActions.length > 0
                            spacing: 8

                            Repeater {
                                model: toast.shownActions

                                Rectangle {
                                    id: btn
                                    required property var modelData
                                    required property int index
                                    readonly property bool primary: index === 0
                                    width: label.implicitWidth + 30
                                    height: 30
                                    radius: 15
                                    color: primary
                                        ? Qt.alpha(toast.accentColor, btnMa.pressed ? 0.30 : btnMa.containsMouse ? 0.24 : 0.16)
                                        : Qt.tint(toast.theme.bgItem,
                                            Qt.alpha(toast.theme.textPrimary, btnMa.pressed ? 0.12 : btnMa.containsMouse ? 0.07 : 0))
                                    Behavior on color { ColorAnimation { duration: 140 } }

                                    Text {
                                        id: label
                                        anchors.centerIn: parent
                                        text: btn.modelData.text
                                        textFormat: Text.PlainText
                                        font.family: toast.fontText
                                        font.pixelSize: toast.actionSize
                                        font.weight: toast.actionWeight
                                        color: btn.primary ? toast.accentColor : toast.theme.textPrimary
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
                            radius: 14
                            color: toast.theme.bgItem
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
                            Rectangle { anchors.fill: parent; radius: 14; color: "black" }
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: thumbImg
                            maskEnabled: true
                            maskSource: thumbMask
                            visible: thumbImg.status === Image.Ready
                        }
                    }
                }
            }
        }
    }
}

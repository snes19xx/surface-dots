import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications

// Text is copied out so the exit animation survives the sender closing it.
// Keep the interface in step with NotifToastRounded.
Item {
    id: toast

    required property var theme
    required property int nid
    // Count behind this card
    required property int more

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

    readonly property bool critical: urgency === NotificationUrgency.Critical
    readonly property bool low: urgency === NotificationUrgency.Low
    readonly property bool hovered: hover.hovered
    readonly property bool dragging: ma.drag.active
    readonly property color accentColor: critical ? theme.accentRed : theme.accent

    property real appear: 0

    property double born: Date.now()
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

    // Newer one resets the timeout
    property bool _ready: false
    onNidChanged: {
        if (!_ready) return
        adopt(Notifs.find(nid))
        born = Date.now()
        ageText = "now"
        timedOut = false
    }

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
        _ready = true
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

            Behavior on x {
                enabled: !ma.drag.active
                SpringSmooth { epsilon: 0.25 }
            }

            // inset to hide under card
            Rectangle {
                id: shadowSrc
                anchors.fill: card
                anchors.margins: 1
                radius: card.radius
                color: PopupStyle.surface(toast.theme)
                visible: false
            }
            MultiEffect {
                anchors.fill: shadowSrc
                source: shadowSrc
                shadowEnabled: true
                shadowColor: PopupStyle.shadowColor(toast.theme)
                shadowBlur: PopupStyle.shadowBlur
                blurMax: PopupStyle.shadowBlurMax
                shadowVerticalOffset: PopupStyle.shadowOffset
                shadowHorizontalOffset: 0
                autoPaddingEnabled: true
                z: -1
            }

            Rectangle {
                id: card
                width: parent.width
                height: content.implicitHeight + PopupStyle.toastPadY * 2
                radius: PopupStyle.radiusCard
                color: Qt.tint(
                    toast.critical
                        ? Qt.tint(PopupStyle.surface(toast.theme), Qt.alpha(toast.theme.accentRed, 0.22))
                        : PopupStyle.surface(toast.theme),
                    Qt.alpha(toast.accentColor, ma.pressed ? 0.34 : toast.hovered ? 0.16 : 0))
                antialiasing: true
                border.width: PopupStyle.hairline(toast.theme)
                border.color: toast.theme.outline
                Behavior on color { ColorAnimation { duration: 140 } }

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

                ColumnLayout {
                    id: content
                    x: PopupStyle.toastPadX
                    y: PopupStyle.toastPadY
                    width: card.width - PopupStyle.toastPadX * 2
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7

                        Item {
                            Layout.preferredWidth: PopupStyle.toastIconSize
                            Layout.preferredHeight: PopupStyle.toastIconSize
                            Layout.alignment: Qt.AlignVCenter

                            // app icons keep their colours
                            Image {
                                anchors.fill: parent
                                visible: toast.iconSource !== ""
                                source: toast.iconSource
                                sourceSize: Qt.size(PopupStyle.toastIconSize * 2, PopupStyle.toastIconSize * 2)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }
                            // black fallback svg, tinted below
                            Image {
                                id: glyphImg
                                anchors.fill: parent
                                source: toast.iconSource === "" ? Qt.resolvedUrl("notify.svg") : ""
                                sourceSize: Qt.size(PopupStyle.toastIconSize * 2, PopupStyle.toastIconSize * 2)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                                layer.enabled: true
                                visible: false
                            }
                            Rectangle {
                                id: glyphTint
                                anchors.fill: parent
                                color: toast.theme.textPrimary
                                layer.enabled: true
                                visible: false
                            }
                            MultiEffect {
                                anchors.fill: parent
                                visible: toast.iconSource === ""
                                source: glyphTint
                                maskEnabled: true
                                maskSource: glyphImg
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0
                            }
                        }

                        Text {
                            id: appLabel
                            Layout.fillWidth: true
                            Layout.maximumWidth: implicitWidth
                            text: (toast.appName !== "" ? toast.appName : "System").toUpperCase()
                            textFormat: Text.PlainText
                            font: PopupStyle.toastFont(PopupStyle.label(toast.theme))
                            renderType: Text.NativeRendering
                            color: PopupStyle.solid(toast.theme, toast.accentColor)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Rectangle {
                            visible: toast.more > 0
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: countLabel.implicitWidth + 20
                            implicitHeight: countLabel.implicitHeight + 8
                            radius: height / 2
                            color: Qt.alpha(toast.accentColor, 0.24)

                            Text {
                                id: countLabel
                                anchors.centerIn: parent
                                text: (toast.more + 1) + " messages"
                                textFormat: Text.PlainText
                                font: Qt.font({ family: toast.theme.textFont, pixelSize: 16, weight: Font.DemiBold })
                                renderType: Text.NativeRendering
                                color: PopupStyle.solid(toast.theme, toast.accentColor)
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // hover swaps age for close
                        Item {
                            Layout.preferredWidth: Math.max(ageLabel.implicitWidth, closeGlyph.implicitWidth)
                            Layout.preferredHeight: ageLabel.implicitHeight

                            Text {
                                id: ageLabel
                                anchors.right: parent.right
                                text: toast.ageText
                                textFormat: Text.PlainText
                                font: PopupStyle.toastFont(PopupStyle.detail(toast.theme))
                                renderType: Text.NativeRendering
                                color: Qt.alpha(toast.theme.textSecondary, PopupStyle.detailOpacity)
                                opacity: toast.hovered ? 0 : 1
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }
                            Text {
                                id: closeGlyph
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: ""
                                font.family: toast.theme.iconFont
                                font.pixelSize: PopupStyle.toastFont(PopupStyle.detail(toast.theme)).pixelSize
                                color: closeMa.containsMouse
                                    ? PopupStyle.solid(toast.theme, toast.accentColor)
                                    : toast.theme.textSecondary
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

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                visible: toast.summary !== ""
                                text: toast.summary
                                textFormat: Text.PlainText
                                font: Qt.font({ family: toast.theme.textFont, pixelSize: 21, weight: Font.Medium })
                                renderType: Text.NativeRendering
                                color: toast.theme.textPrimary
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                visible: toast.body !== ""
                                text: toast.safeBody
                                textFormat: Text.StyledText
                                font: PopupStyle.toastFont(PopupStyle.body(toast.theme))
                                renderType: Text.NativeRendering
                                lineHeight: PopupStyle.bodyLine
                                lineHeightMode: Text.ProportionalHeight
                                color: toast.theme.textPrimary
                                linkColor: PopupStyle.solid(toast.theme, toast.theme.accent)
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                onLinkActivated: link => toast.openLink(link)
                            }
                        }

                        Item {
                            Layout.preferredWidth: PopupStyle.toastImageSize
                            Layout.preferredHeight: PopupStyle.toastImageSize
                            Layout.alignment: Qt.AlignTop
                            visible: toast.imageSource !== ""

                            Rectangle {
                                anchors.fill: parent
                                radius: PopupStyle.radiusInner
                                color: toast.theme.bgItem
                            }
                            Image {
                                id: thumbImg
                                anchors.fill: parent
                                source: toast.imageSource
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(PopupStyle.toastImageSize * 2, PopupStyle.toastImageSize * 2)
                                asynchronous: true
                                smooth: true
                                visible: false
                            }
                            Item {
                                id: thumbMask
                                anchors.fill: parent
                                layer.enabled: true
                                visible: false
                                Rectangle { anchors.fill: parent; radius: PopupStyle.radiusInner; color: "black" }
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
                                radius: PopupStyle.radiusInner
                                color: "transparent"
                                border.width: PopupStyle.hairline(toast.theme)
                                border.color: toast.theme.outline
                            }
                        }
                    }

                    // negative margins span full width
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: -PopupStyle.toastPadX
                        Layout.rightMargin: -PopupStyle.toastPadX
                        Layout.topMargin: 10
                        Layout.preferredHeight: PopupStyle.rule
                        visible: toast.shownActions.length > 0
                        color: toast.theme.outline
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: 10
                        visible: toast.shownActions.length > 0
                        spacing: 8

                        Repeater {
                            model: toast.shownActions

                            Rectangle {
                                id: btn
                                required property var modelData
                                required property int index
                                // card clicks never run these
                                readonly property bool lit: btnMa.containsMouse
                                width: label.implicitWidth + PopupStyle.toastButtonPadX * 2
                                height: PopupStyle.toastButtonHeight
                                radius: PopupStyle.radiusInner
                                color: lit ? PopupStyle.solid(toast.theme, toast.theme.accent) : "transparent"
                                border.width: PopupStyle.hairline(toast.theme)
                                border.color: lit ? color : toast.theme.outline
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: label
                                    anchors.centerIn: parent
                                    text: btn.modelData.text
                                    textFormat: Text.PlainText
                                    font: PopupStyle.toastFont(PopupStyle.action(toast.theme))
                                    renderType: Text.NativeRendering
                                    color: btn.lit ? toast.theme.textOnAccent : toast.theme.textPrimary
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
            }
        }
    }
}

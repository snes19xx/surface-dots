import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// Keep the interface in step with OsdCardCassini and OsdCard.
Item {
    id: osd

    required property var theme

    property bool shown: false
    property int fadeInMs: 160
    property int fadeOutMs: 320
    property real slideY: 22
    property string label: ""
    property string value: ""
    property string secondary: ""
    property color accentColor: theme.accent
    // iconSource wins over glyph
    property string glyph: ""
    property url iconSource: ""

    property bool showLevel: false
    property real level: 0
    property bool dimLevel: false
    property bool dragging: false
    property bool iconClickable: false

    signal levelPressed(real frac)
    signal levelMoved(real frac)
    signal levelReleased()
    signal levelWheeled(int delta)
    signal iconClicked()

    // same scale as NotifToastRounded
    readonly property string fontText: theme.textFont
    readonly property string fontIcon: theme.iconFont
    // pixelSize is an int
    readonly property int labelSize: Math.round(10.5)
    readonly property int labelWeight: Font.DemiBold
    readonly property real labelSpacing: 0.9
    readonly property int valueSize: 14
    readonly property int valueWeight: Font.DemiBold
    readonly property real valueSpacing: -0.1
    readonly property int subSize: Math.round(12.5)
    readonly property int subWeight: Font.Medium

    readonly property int pad: 16
    readonly property bool hovered: hover.hovered

    function pulse() { pulseAnim.restart() }
    function swap() { swapAnim.restart() }

    width: 300
    height: card.height

    opacity: shown ? 1.0 : 0.0
    Behavior on opacity {
        NumberAnimation {
            duration: osd.shown ? osd.fadeInMs : osd.fadeOutMs
            easing.type: osd.shown ? Easing.OutQuad : Easing.InCubic
        }
    }
    transform: Translate {
        y: osd.shown ? 0 : osd.slideY
        Behavior on y { SpringGentle { epsilon: 0.25 } }
    }

    Item {
        id: lift
        anchors.fill: parent
        scale: osd.hovered ? 1.01 : 1.0
        Behavior on scale { SpringSnappy {} }

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
            shadowOpacity: (osd.theme.isDarkMode ? 0.42 : 0.2) * (osd.hovered ? 1.25 : 1.0)
            shadowBlur: 1.0
            shadowVerticalOffset: osd.hovered ? 16 : 12
            z: -2
            Behavior on shadowVerticalOffset { NumberAnimation { duration: 180 } }
        }
        // contact shadow
        MultiEffect {
            anchors.fill: shadowSrc
            source: shadowSrc
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: osd.theme.isDarkMode ? 0.5 : 0.22
            shadowBlur: 0.25
            shadowVerticalOffset: 2
            z: -1
        }

        Rectangle {
            id: card
            width: parent.width
            height: row.implicitHeight + osd.pad * 2
            radius: osd.theme.radiusOuter + 4

            // lifted a step in dark
            readonly property color base: osd.theme.isDarkMode
                ? Qt.tint(osd.theme.bgCard, osd.theme.subtleFill) : osd.theme.bgCard
            color: osd.hovered ? Qt.tint(base, Qt.alpha(osd.theme.accent, 0.07)) : base
            Behavior on color { ColorAnimation { duration: 160 } }

            HoverHandler {
                id: hover
            }

            // before row, so bar wins
            MouseArea {
                x: row.x + textCol.x
                y: row.y + textCol.y
                width: textCol.width
                height: valueRow.y + valueRow.height
                enabled: osd.iconClickable
                cursorShape: Qt.PointingHandCursor
                onClicked: osd.iconClicked()
            }

            RowLayout {
                id: row
                x: osd.pad
                y: osd.pad
                width: card.width - osd.pad * 2
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    radius: 999
                    color: Qt.alpha(osd.accentColor, 0.16)
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Item {
                        id: iconWrap
                        anchors.centerIn: parent
                        width: 22
                        height: 22

                        SequentialAnimation {
                            id: pulseAnim
                            NumberAnimation {
                                target: iconWrap
                                property: "scale"
                                to: 1.2
                                duration: 80
                                easing.type: Easing.OutQuad
                            }
                            SpringBouncy { target: iconWrap; property: "scale"; to: 1.0 }
                        }
                        SpringSnappy {
                            id: swapAnim
                            target: iconWrap
                            property: "scale"
                            from: 0.7
                            to: 1.0
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: osd.iconSource.toString() === ""
                            text: osd.glyph
                            font.family: osd.fontIcon
                            font.pixelSize: 22
                            color: osd.accentColor
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        // exact tint for any fill
                        Image {
                            id: svgImg
                            anchors.fill: parent
                            source: osd.iconSource
                            sourceSize: Qt.size(44, 44)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            layer.enabled: true
                            visible: false
                        }
                        Rectangle {
                            id: svgTint
                            anchors.fill: parent
                            color: osd.accentColor
                            layer.enabled: true
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: parent
                            visible: osd.iconSource.toString() !== ""
                            source: svgTint
                            maskEnabled: true
                            maskSource: svgImg
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: osd.iconClickable
                        cursorShape: Qt.PointingHandCursor
                        onClicked: osd.iconClicked()
                    }
                }

                ColumnLayout {
                    id: textCol
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: osd.label.toUpperCase()
                        textFormat: Text.PlainText
                        font.family: osd.fontText
                        font.pixelSize: osd.labelSize
                        font.weight: osd.labelWeight
                        font.letterSpacing: osd.labelSpacing
                        color: osd.accentColor
                        Behavior on color { ColorAnimation { duration: 200 } }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    RowLayout {
                        id: valueRow
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 8

                        Text {
                            text: osd.value
                            textFormat: Text.PlainText
                            font.family: osd.fontText
                            font.pixelSize: osd.valueSize
                            font.weight: osd.valueWeight
                            font.letterSpacing: osd.valueSpacing
                            color: osd.theme.textPrimary
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: osd.secondary !== ""
                            text: osd.secondary
                            textFormat: Text.PlainText
                            horizontalAlignment: Text.AlignRight
                            font.family: osd.fontText
                            font.pixelSize: osd.subSize
                            font.weight: osd.subWeight
                            color: osd.theme.textSecondary
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        Item {
                            Layout.fillWidth: true
                            visible: osd.secondary === ""
                        }
                    }

                    Item {
                        id: barArea
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.preferredHeight: 20
                        visible: osd.showLevel
                        opacity: osd.dimLevel ? 0.35 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        Rectangle {
                            id: barTrack
                            width: parent.width
                            height: osd.dragging ? 10 : 8
                            anchors.verticalCenter: parent.verticalCenter
                            radius: height / 2
                            color: Qt.tint(card.base, Qt.alpha(osd.theme.textPrimary, 0.1))
                            Behavior on height {
                                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                            }
                        }

                        Rectangle {
                            height: barTrack.height
                            width: Math.max(barTrack.radius * 2,
                                            barTrack.width * Math.max(0, Math.min(1, osd.level)))
                            radius: barTrack.radius
                            anchors.verticalCenter: barTrack.verticalCenter
                            color: osd.accentColor
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on width {
                                NumberAnimation {
                                    duration: osd.dragging ? 0 : 120
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: osd.showLevel
                            cursorShape: Qt.PointingHandCursor

                            function frac(mx) {
                                return Math.max(0, Math.min(1, mx / barTrack.width))
                            }

                            onPressed: mouse => osd.levelPressed(frac(mouse.x))
                            onPositionChanged: mouse => {
                                if (pressed) osd.levelMoved(frac(mouse.x))
                            }
                            onReleased: osd.levelReleased()
                            onWheel: wheel => osd.levelWheeled(wheel.angleDelta.y > 0 ? 5 : -5)
                        }
                    }
                }
            }
        }
    }
}

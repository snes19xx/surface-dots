import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes

// Keep the interface in step with OsdCardRounded and OsdCard.
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
    // interface parity only
    property bool dragging: false
    property bool iconClickable: false

    signal levelPressed(real frac)
    signal levelMoved(real frac)
    signal levelReleased()
    signal levelWheeled(int delta)
    signal iconClicked()

    readonly property bool hovered: hover.hovered
    readonly property color surface: PopupStyle.surface(theme)
    // "62%" splits, words stay whole
    readonly property var numMatch: /^(\d+)(%)$/.exec(value)
    readonly property bool numeric: numMatch !== null

    function pulse() { pulseAnim.restart() }
    function swap() { swapAnim.restart() }

    width: PopupStyle.osdWidth
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

    // inset to hide under card
    Rectangle {
        id: shadowSrc
        anchors.fill: card
        anchors.margins: 1
        radius: card.radius
        color: osd.surface
        visible: false
    }
    MultiEffect {
        anchors.fill: shadowSrc
        source: shadowSrc
        shadowEnabled: true
        shadowColor: PopupStyle.shadowColor(osd.theme)
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
        height: row.implicitHeight + PopupStyle.osdPadY * 2
        radius: PopupStyle.radiusCard
        color: osd.surface
        antialiasing: true
        border.width: PopupStyle.hairline(osd.theme)
        border.color: PopupStyle.frame(osd.theme, osd.hovered, osd.theme.accent)
        Behavior on border.color { ColorAnimation { duration: 140 } }

        HoverHandler {
            id: hover
        }

        // before row, so scale wins
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
            x: PopupStyle.osdPadX
            y: PopupStyle.osdPadY
            width: card.width - PopupStyle.osdPadX * 2
            spacing: 14

            Item {
                Layout.preferredWidth: PopupStyle.osdIconSize + 2
                Layout.preferredHeight: PopupStyle.osdIconSize + 2
                Layout.alignment: Qt.AlignVCenter

                Item {
                    id: iconWrap
                    anchors.centerIn: parent
                    width: PopupStyle.osdIconSize
                    height: PopupStyle.osdIconSize

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
                        font.family: osd.theme.iconFont
                        font.pixelSize: PopupStyle.osdIconSize
                        renderType: Text.NativeRendering
                        color: osd.theme.textPrimary
                    }

                    // exact tint for any fill
                    Image {
                        id: svgImg
                        anchors.fill: parent
                        source: osd.iconSource
                        sourceSize: Qt.size(PopupStyle.osdIconSize * 2, PopupStyle.osdIconSize * 2)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        layer.enabled: true
                        visible: false
                    }
                    Rectangle {
                        id: svgTint
                        anchors.fill: parent
                        color: osd.theme.textPrimary
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

            Rectangle {
                Layout.preferredWidth: PopupStyle.rule
                Layout.fillHeight: true
                color: osd.theme.outline
            }

            ColumnLayout {
                id: textCol
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: osd.label.toUpperCase()
                        textFormat: Text.PlainText
                        font: PopupStyle.label(osd.theme)
                        renderType: Text.NativeRendering
                        color: PopupStyle.solid(osd.theme, osd.accentColor)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    Text {
                        Layout.fillWidth: true
                        text: osd.secondary
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignRight
                        font: PopupStyle.detail(osd.theme)
                        renderType: Text.NativeRendering
                        color: Qt.alpha(osd.theme.textSecondary, PopupStyle.detailOpacity)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                Item {
                    id: valueRow
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    // fixed height, words don't resize
                    Layout.preferredHeight: sizer.implicitHeight

                    Text {
                        id: sizer
                        visible: false
                        text: "0"
                        font: PopupStyle.osdValue
                    }
                    Text {
                        id: valueText
                        text: osd.numeric ? osd.numMatch[1] : osd.value
                        textFormat: Text.PlainText
                        font: osd.numeric ? PopupStyle.osdValue : PopupStyle.osdValueWord
                        renderType: Text.NativeRendering
                        color: osd.theme.textPrimary
                        y: sizer.baselineOffset - baselineOffset
                    }
                    Text {
                        visible: osd.numeric
                        x: valueText.width + PopupStyle.osdUnitGap
                        y: sizer.baselineOffset - baselineOffset
                        text: osd.numeric ? osd.numMatch[2] : ""
                        textFormat: Text.PlainText
                        font: PopupStyle.osdUnit(osd.theme)
                        renderType: Text.NativeRendering
                        color: osd.theme.textSecondary
                    }
                }

                // marker tracks value, no spring
                Item {
                    id: ruler
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.preferredHeight: PopupStyle.osdRulerHeight
                    visible: osd.showLevel

                    readonly property int baseY: PopupStyle.osdBaseY
                    readonly property color lineColor: PopupStyle.osdTick(osd.theme)
                    readonly property color markColor: PopupStyle.solid(osd.theme, osd.accentColor)
                    // muted dims line and marker
                    readonly property real markOpacity: osd.dimLevel ? PopupStyle.osdDimOpacity : 1.0
                    // whole pixels keep ticks crisp
                    readonly property int span: Math.max(1, Math.floor(width) - 1)
                    readonly property real frac: Math.max(0, Math.min(1, osd.level))
                    readonly property int markX: Math.round(frac * span)

                    Rectangle {
                        x: 0
                        y: ruler.baseY
                        width: ruler.span + 1
                        height: PopupStyle.rule
                        color: ruler.lineColor
                    }

                    Repeater {
                        model: 11
                        Rectangle {
                            required property int index
                            readonly property bool major: index % 5 === 0
                            readonly property int tall: major ? PopupStyle.osdTickMajor : PopupStyle.osdTickMinor
                            x: Math.round(index * ruler.span / 10)
                            y: ruler.baseY - tall
                            width: PopupStyle.rule
                            height: tall
                            color: ruler.lineColor
                        }
                    }

                    Rectangle {
                        x: 0
                        y: ruler.baseY
                        width: ruler.markX + 1
                        height: PopupStyle.osdLevelLine
                        color: ruler.markColor
                        opacity: ruler.markOpacity
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }

                    Shape {
                        x: ruler.markX - Math.floor(PopupStyle.osdMarkerWidth / 2)
                        y: ruler.baseY - PopupStyle.osdMarkerHeight - 1
                        width: PopupStyle.osdMarkerWidth
                        height: PopupStyle.osdMarkerHeight
                        opacity: ruler.markOpacity
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: ruler.markColor
                            strokeColor: "transparent"
                            strokeWidth: 0
                            startX: 0; startY: 0
                            PathLine { x: PopupStyle.osdMarkerWidth; y: 0 }
                            PathLine { x: PopupStyle.osdMarkerWidth / 2; y: PopupStyle.osdMarkerHeight }
                            PathLine { x: 0; y: 0 }
                        }
                    }

                    Text {
                        x: 0
                        y: ruler.baseY + 5
                        text: "0"
                        font: PopupStyle.osdNumeral(osd.theme)
                        renderType: Text.NativeRendering
                        color: Qt.alpha(osd.theme.textSecondary, PopupStyle.detailOpacity)
                    }
                    Text {
                        x: Math.round(ruler.span / 2 - width / 2)
                        y: ruler.baseY + 5
                        text: "50"
                        font: PopupStyle.osdNumeral(osd.theme)
                        renderType: Text.NativeRendering
                        color: Qt.alpha(osd.theme.textSecondary, PopupStyle.detailOpacity)
                    }
                    Text {
                        x: ruler.span + 1 - width
                        y: ruler.baseY + 5
                        text: "100"
                        font: PopupStyle.osdNumeral(osd.theme)
                        renderType: Text.NativeRendering
                        color: Qt.alpha(osd.theme.textSecondary, PopupStyle.detailOpacity)
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: osd.showLevel
                        cursorShape: Qt.PointingHandCursor

                        function frac(mx) {
                            return Math.max(0, Math.min(1, mx / ruler.span))
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

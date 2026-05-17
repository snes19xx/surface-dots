import QtQuick

Item {
    id: root
    property real value: 0.55            // 0..1
    property bool active: false

    property color color: Qt.rgba(1,1,1,0.65)      // wave
    property color trackColor: Qt.rgba(1,1,1,0.18) // right track

    property real amplitude: 3
    property real frequency: 0.15
    property real lineWidth: 3

    property int fps: 24
    property real speed: 1.0
    property real gap: 10

    implicitHeight: 12
    implicitWidth: 200
    clip: true

    property real phase: 0.0

    function clamp01(x) { return Math.max(0, Math.min(1, x)) }

    Timer {
        interval: Math.max(16, Math.floor(1000 / Math.max(1, root.fps)))
        repeat: true
        running: root.active
        onTriggered: {
            root.phase += 0.22 * root.speed
            if (root.phase > Math.PI * 2) root.phase -= Math.PI * 2
            c.requestPaint()
        }
    }

    onWidthChanged: c.requestPaint()
    onHeightChanged: c.requestPaint()
    onValueChanged: c.requestPaint()
    onColorChanged: c.requestPaint()
    onTrackColorChanged: c.requestPaint()

    Canvas {
        id: c
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var midY = height / 2
            var amp = root.active ? root.amplitude : 0
            var fillW = width * root.clamp01(root.value)

            // RIGHT track only (no track behind wave)
            var trackStart = Math.min(width, fillW + root.gap)
            if (trackStart < width - 1) {
                ctx.lineWidth = root.lineWidth
                ctx.lineCap = "round"
                ctx.strokeStyle = root.trackColor
                ctx.beginPath()
                ctx.moveTo(trackStart, midY)
                ctx.lineTo(width, midY)
                ctx.stroke()
            }

            // LEFT wave (clipped)
            if (fillW > 2 && amp > 0.01) {
                ctx.save()
                ctx.beginPath()
                ctx.rect(0, 0, fillW, height)
                ctx.clip()

                ctx.lineWidth = root.lineWidth
                ctx.lineCap = "round"
                ctx.strokeStyle = root.color
                ctx.beginPath()

                // step sampling, not per-pixel
                var step = Math.max(2, Math.floor(width / 180))
                for (var x = 0; x <= width; x += step) {
                    var y = midY + Math.sin((x * root.frequency) + root.phase) * amp
                    if (x === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.stroke()
                ctx.restore()
            }
        }
    }
}

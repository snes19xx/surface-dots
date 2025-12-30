import QtQuick

Item {
    id: root
    
    // Visual Properties
    property color color: "white"
    property real lineWidth: 3
    property real amplitude: 6 
    property bool running: false 
    onColorChanged: canvas.requestPaint()
    onLineWidthChanged: canvas.requestPaint()
    onAmplitudeChanged: canvas.requestPaint()

    clip: true 

    // The Sliding Container 
    Item {
        id: slider
        height: root.height
        width: root.width * 2 
        
        // This makes it move. Slides from 0 to -width forever.
        NumberAnimation on x {
            from: 0
            to: -root.width 
            duration: 4000 // Speed of the wave
            loops: Animation.Infinite
            running: root.running
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            renderTarget: Canvas.Image 
            
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                
                ctx.strokeStyle = root.color;
                ctx.lineWidth = root.lineWidth;
                ctx.lineCap = "round";
                ctx.beginPath();
                
                var midY = height / 2;
                var cyclesInView = 2; 
                var totalCycles = cyclesInView * 2; 
                var freq = (Math.PI * 2 * totalCycles) / width;

                for (var x = 0; x <= width; x += 2) {
                    var y = midY + Math.sin(x * freq) * root.amplitude;
                    if (x === 0) ctx.moveTo(x, y);
                    else ctx.lineTo(x, y);
                }
                ctx.stroke();
            }
            
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }
    }
}
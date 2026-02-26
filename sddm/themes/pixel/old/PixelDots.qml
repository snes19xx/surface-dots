// Heavily inspired by PixelDots by @mahaveergurjar
// PLease check https://github.com/mahaveergurjar/sddm/tree/pixel

import QtQuick 2.15

Row {
    id: dotsRoot

    property int dotCount: 0
    property color dotColor: "#D3C6AA"
    property color animColor: "#A7C080"


    property real dynamicScale: dotCount > 6 ? (6 / dotCount) : 1.0
    anchors.horizontalCenter: parent.horizontalCenter
    
    // Scale spacing along with the dots
    spacing: 14 * dynamicScale 

    Repeater {
        model: dotsRoot.dotCount

        delegate: Item {
            // Scale dimensions
            width: 20 * dotsRoot.dynamicScale
            height: 20 * dotsRoot.dynamicScale
            scale: dotsRoot.dynamicScale 

            // Animation for smooth entry
            Behavior on scale { NumberAnimation { duration: 100 } }

            property int shapeType: index % 8

            Canvas {
                id: shapeCanvas
                anchors.centerIn: parent
                width: 26
                height: 26

                property color currentColor: dotsRoot.dotColor
                onCurrentColorChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = shapeCanvas.currentColor;

                    var cx = width / 2;
                    var cy = height / 2;
                    var baseSize = width * 0.9;

                    ctx.beginPath();


                    if (shapeType === 0) {
                        var r = baseSize / 2;
                        ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    } else if (shapeType === 1) {
                        var dSize = baseSize * 1.1;
                        var half = dSize / 2;
                        ctx.moveTo(cx, cy - half);
                        ctx.lineTo(cx + half, cy);
                        ctx.lineTo(cx, cy + half);
                        ctx.lineTo(cx - half, cy);
                        ctx.closePath();
                    } else if (shapeType === 2) {
                        var tSize = baseSize * 1.15;
                        var tHeight = (Math.sqrt(3)/2) * tSize;
                        var yOffset = tHeight / 6;
                        ctx.moveTo(cx, cy - (tHeight/2) - yOffset);
                        ctx.lineTo(cx + (tSize/2), cy + (tHeight/2) - yOffset);
                        ctx.lineTo(cx - (tSize/2), cy + (tHeight/2) - yOffset);
                        ctx.closePath();
                    } else if (shapeType === 3) {
                        var sqSize = baseSize * 0.85;
                        var offset = sqSize / 2;
                        var radius = sqSize * 0.4;
                        ctx.moveTo(cx - offset + radius, cy - offset);
                        ctx.lineTo(cx + offset - radius, cy - offset);
                        ctx.quadraticCurveTo(cx + offset, cy - offset, cx + offset, cy - offset + radius);
                        ctx.lineTo(cx + offset, cy + offset - radius);
                        ctx.quadraticCurveTo(cx + offset, cy + offset, cx + offset - radius, cy + offset);
                        ctx.lineTo(cx - offset + radius, cy + offset);
                        ctx.quadraticCurveTo(cx - offset, cy + offset, cx - offset, cy + offset - radius);
                        ctx.lineTo(cx - offset, cy - offset + radius);
                        ctx.quadraticCurveTo(cx - offset, cy - offset, cx - offset + radius, cy - offset);
                        ctx.closePath();
                    } else if (shapeType === 4) {
                        var outerRadius = baseSize * 0.75;
                        var innerRadius = baseSize * 0.32;
                        var spikes = 5;
                        var step = Math.PI / spikes;
                        var rot = Math.PI / 2 * 3;
                        var x = cx; var y = cy;
                        ctx.moveTo(cx, cy - outerRadius);
                        for (var i = 0; i < spikes; i++) {
                            x = cx + Math.cos(rot) * outerRadius;
                            y = cy + Math.sin(rot) * outerRadius;
                            ctx.lineTo(x, y);
                            rot += step;
                            x = cx + Math.cos(rot) * innerRadius;
                            y = cy + Math.sin(rot) * innerRadius;
                            ctx.lineTo(x, y);
                            rot += step;
                        }
                        ctx.lineTo(cx, cy - outerRadius);
                        ctx.closePath();
                    } else if (shapeType === 5) {
                        var pRadius = baseSize * 0.55;
                        var pAngle = (Math.PI * 2) / 5;
                        var startAngle = -Math.PI / 2;
                        ctx.moveTo(cx + pRadius * Math.cos(startAngle), cy + pRadius * Math.sin(startAngle));
                        for (var i = 1; i <= 5; i++) {
                            ctx.lineTo(cx + pRadius * Math.cos(startAngle + i * pAngle),
                                       cy + pRadius * Math.sin(startAngle + i * pAngle));
                        }
                        ctx.closePath();
                    } else if (shapeType === 6) {
                        var hRadius = baseSize * 0.5;
                        var hAngle = (Math.PI * 2) / 6;
                        var hStart = -Math.PI / 2;
                        ctx.moveTo(cx + hRadius * Math.cos(hStart), cy + hRadius * Math.sin(hStart));
                        for (var i = 1; i <= 6; i++) {
                            ctx.lineTo(cx + hRadius * Math.cos(hStart + i * hAngle),
                                       cy + hRadius * Math.sin(hStart + i * hAngle));
                        }
                        ctx.closePath();
                    } else {
                        var fRadius = baseSize * 0.5;
                        var petals = 8;
                        var step2 = (Math.PI * 2) / petals;
                        for (var j = 0; j < petals; j++) {
                            var theta1 = j * step2;
                            var theta2 = (j + 1) * step2;
                            var cpRadius = fRadius * 1.25;
                            var cpTheta = (theta1 + theta2) / 2;
                            var startX = cx + fRadius * Math.cos(theta1);
                            var startY = cy + fRadius * Math.sin(theta1);
                            var endX = cx + fRadius * Math.cos(theta2);
                            var endY = cy + fRadius * Math.sin(theta2);
                            var cpX = cx + cpRadius * Math.cos(cpTheta);
                            var cpY = cy + cpRadius * Math.sin(cpTheta);
                            if (j === 0) ctx.moveTo(startX, startY);
                            ctx.quadraticCurveTo(cpX, cpY, endX, endY);
                        }
                        ctx.closePath();
                    }
                    ctx.fill();
                }
            }
        }
    }
}
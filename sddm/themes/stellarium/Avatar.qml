////////////////
// [Stellarium SDDM theme by @snes19xx]
//
// Avatar.qml -- 8 of 8 files
//
////////////////
import QtQuick 2.15

Item {
    id: root
    width: 106
    height: 106

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 6
        color: "transparent"
        border.color: typeof hairlineStrong !== "undefined" ? hairlineStrong : Qt.rgba(236/255, 230/255, 214/255, 0.42)
        border.width: 1

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 5
            color: "transparent"
            border.color: Qt.rgba(236/255, 230/255, 214/255, 0.02)
            border.width: 6
        }

        Canvas {
            anchors.fill: parent
            antialiasing: true
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var grad = ctx.createRadialGradient(width*0.32, height*0.28, 0, width*0.32, height*0.28, width*0.7);
                grad.addColorStop(0.0, "rgba(236, 230, 214, 0.10)");
                grad.addColorStop(0.7, Qt.rgba(236/255, 230/255, 214/255, 0.02));
                grad.addColorStop(1.0, "rgba(0,0,0,0.10)");
                ctx.fillStyle = grad;
                ctx.fillRect(0, 0, width, height);

                ctx.strokeStyle = root.parent && root.parent.hairlineStrong ? root.parent.hairlineStrong : "rgba(236, 230, 214, 0.42)";
                ctx.lineWidth = 1;
                ctx.beginPath();
                // TL
                ctx.moveTo(4+8, 4); ctx.lineTo(4, 4); ctx.lineTo(4, 4+8);
                // TR
                ctx.moveTo(width-4-8, 4); ctx.lineTo(width-4, 4); ctx.lineTo(width-4, 4+8);
                // BL
                ctx.moveTo(4+8, height-4); ctx.lineTo(4, height-4); ctx.lineTo(4, height-4-8);
                // BR
                ctx.moveTo(width-4-8, height-4); ctx.lineTo(width-4, height-4); ctx.lineTo(width-4, height-4-8);
                ctx.stroke();
            }
        }

        Canvas {
            x: 20
            y: 20
            width: 66
            height: 66
            antialiasing: true
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.scale(1.1, 1.1); 
                ctx.save();
                ctx.translate(30, 32);
                ctx.rotate(-12 * Math.PI / 180);
                ctx.beginPath();
                ctx.ellipse(0, 0, 24, 9, 0, 0, Math.PI*2);
                ctx.strokeStyle = root.parent && root.parent.hairlineStrong ? root.parent.hairlineStrong : "rgba(236, 230, 214, 0.42)";
                ctx.lineWidth = 0.6;
                ctx.stroke();
                ctx.restore();

                // Crescent
                ctx.beginPath();
                ctx.arc(30, 28, 15, 0, Math.PI*2);
                ctx.fillStyle = "rgba(236, 230, 214, 0.92)"; 
                ctx.fill();
                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(36, 24, 14, 0, Math.PI*2);
                ctx.fillStyle = "black";
                ctx.fill();
                ctx.globalCompositeOperation = "source-over";

                ctx.save();
                ctx.translate(15, 14);
                ctx.beginPath();
                ctx.moveTo(0, -4);
                ctx.lineTo(1, -1);
                ctx.lineTo(4, -0.5);
                ctx.lineTo(1.5, 1);
                ctx.lineTo(2.2, 4);
                ctx.lineTo(0, 2.5);
                ctx.lineTo(-2.2, 4);
                ctx.lineTo(-1.5, 1);
                ctx.lineTo(-4, -0.5);
                ctx.lineTo(-1, -1);
                ctx.closePath();
                ctx.fillStyle = "#87b08a"; 
                ctx.fill();
                ctx.restore();

                // Tiny far dot
                ctx.beginPath();
                ctx.arc(50, 46, 1.2, 0, Math.PI*2);
                ctx.fillStyle = "#c8c1b2"; 
                ctx.fill();
            }
        }

        Rectangle {
            width: 5
            height: 5
            radius: 2.5
            color: "#87b08a" 
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: 8
            border.color: Qt.rgba(8/255, 10/255, 12/255, 0.6)
            border.width: 2
        }
    }
}

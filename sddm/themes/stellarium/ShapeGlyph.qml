////////////////
// [Stellarium SDDM theme by @snes19xx]
//
// ShapeGlyph.qml -- 4 of 8 files
// Astronomy inspired glyphs for password chars and status icons.
//
////////////////

import QtQuick 2.15

Item {
    id: root
    property string kind: "star"
    property real size: 18
    property color color: "#ece6d6" 

    width: size
    height: size

    Canvas {
        id: cv
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var s = width;
            var c = s / 2;
            var r = s * 0.38;
            ctx.fillStyle = root.color;
            ctx.strokeStyle = root.color;
            ctx.lineWidth = 1.2;

            if (root.kind === "star") {
                var R = r * 1.08, r2 = R * 0.42;
                ctx.beginPath();
                for (var i = 0; i < 10; i++) {
                    var a = -Math.PI/2 + i * Math.PI / 5;
                    var rad = (i % 2 === 0) ? R : r2;
                    if (i===0) ctx.moveTo(c + rad*Math.cos(a), c + rad*Math.sin(a));
                    else ctx.lineTo(c + rad*Math.cos(a), c + rad*Math.sin(a));
                }
                ctx.closePath();
                ctx.fill();
            } else if (root.kind === "crescent") {
                ctx.beginPath();
                ctx.arc(c, c, r, 0, Math.PI*2);
                ctx.fill();
                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(c + r*0.42, c - r*0.18, r*0.95, 0, Math.PI*2);
                ctx.fill();
                ctx.globalCompositeOperation = "source-over";
            } else if (root.kind === "saturn") {
                var tilt = -18 * Math.PI / 180;
                var rX = r * 1.48;
                var rY = r * 0.30;

                ctx.save();
                ctx.translate(c, c);
                ctx.rotate(tilt);
                ctx.scale(1.0, rY / rX);
                ctx.beginPath();
                ctx.arc(0, 0, rX, Math.PI, Math.PI * 2);
                ctx.restore();
                ctx.lineWidth = 1.4;
                ctx.globalAlpha = 0.35;
                ctx.stroke();
                ctx.globalAlpha = 1.0;

                ctx.beginPath();
                ctx.arc(c, c, r * 0.64, 0, Math.PI * 2);
                ctx.fill();

                ctx.save();
                ctx.translate(c, c);
                ctx.rotate(tilt);
                ctx.scale(1.0, rY / rX);
                ctx.beginPath();
                ctx.arc(0, 0, rX, 0, Math.PI);
                ctx.restore();
                ctx.lineWidth = 1.4;
                ctx.stroke();
            } else if (root.kind === "sun") {
                ctx.beginPath();
                ctx.arc(c, c, r*0.55, 0, Math.PI*2);
                ctx.fill();
                ctx.lineCap = "round";
                for (var j = 0; j < 8; j++) {
                    var aj = j * Math.PI/4;
                    ctx.beginPath();
                    ctx.moveTo(c + Math.cos(aj) * r * 0.78, c + Math.sin(aj) * r * 0.78);
                    ctx.lineTo(c + Math.cos(aj) * r * 1.12, c + Math.sin(aj) * r * 1.12);
                    ctx.stroke();
                }
            } else if (root.kind === "ring") {
                ctx.beginPath();
                ctx.arc(c, c, r, 0, Math.PI*2);
                ctx.lineWidth = 1.4;
                ctx.stroke();
            } else if (root.kind === "sparkle") {
                var Rs = r * 1.05;
                ctx.beginPath();
                ctx.moveTo(c, c-Rs);
                ctx.lineTo(c+Rs*0.32, c);
                ctx.lineTo(c, c+Rs);
                ctx.lineTo(c-Rs*0.32, c);
                ctx.fill();

                ctx.globalAlpha = 0.95;
                ctx.beginPath();
                ctx.moveTo(c-Rs, c);
                ctx.lineTo(c, c+Rs*0.32);
                ctx.lineTo(c+Rs, c);
                ctx.lineTo(c, c-Rs*0.32);
                ctx.fill();
                ctx.globalAlpha = 1.0;
            } else if (root.kind === "compass") {
                var Rc = r * 1.05;
                var drawDiamond = function() {
                    ctx.beginPath();
                    ctx.moveTo(c, c-Rc);
                    ctx.lineTo(c+Rc*0.28, c);
                    ctx.lineTo(c, c+Rc);
                    ctx.lineTo(c-Rc*0.28, c);
                    ctx.fill();
                };
                drawDiamond();
                ctx.save();
                ctx.globalAlpha = 0.45;
                ctx.translate(c, c);
                ctx.rotate(45 * Math.PI / 180);
                ctx.translate(-c, -c);
                drawDiamond();
                ctx.restore();
            } else if (root.kind === "nova") {
                ctx.beginPath();
                ctx.arc(c, c, r*0.35, 0, Math.PI*2);
                ctx.fill();
                ctx.lineCap = "round";
                for(var kn=0; kn<6; kn++){
                    var an = -Math.PI/2 + kn * Math.PI / 3;
                    ctx.beginPath();
                    ctx.moveTo(c + Math.cos(an)*r*0.5, c + Math.sin(an)*r*0.5);
                    ctx.lineTo(c + Math.cos(an)*r*1.2, c + Math.sin(an)*r*1.2);
                    ctx.stroke();
                }
            } else if (root.kind === "eclipse") {
                ctx.beginPath();
                ctx.arc(c, c, r, 0, Math.PI*2);
                ctx.fill();
                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(c, c, r*0.45, 0, Math.PI*2);
                ctx.fill();
                ctx.globalCompositeOperation = "source-over";
            } else if (root.kind === "comet") {
                ctx.lineCap = "round";
                ctx.lineWidth = 1.4;
                ctx.globalAlpha = 0.55;
                ctx.beginPath();
                ctx.moveTo(c - r*1.1, c + r*0.9);
                ctx.lineTo(c + r*0.1, c - r*0.1);
                ctx.stroke();

                ctx.globalAlpha = 0.85;
                ctx.beginPath();
                ctx.moveTo(c - r*0.6, c + r*0.6);
                ctx.lineTo(c + r*0.2, c - r*0.2);
                ctx.stroke();

                ctx.globalAlpha = 1.0;
                ctx.beginPath();
                ctx.arc(c + r*0.5, c - r*0.5, r*0.5, 0, Math.PI*2);
                ctx.fill();
            } else if (root.kind === "atom") {
                ctx.save();
                ctx.translate(c, c);
                ctx.rotate(30 * Math.PI / 180);
                ctx.beginPath();
                ctx.ellipse(0, 0, r*1.15, r*0.42, 0, 0, Math.PI*2);
                ctx.lineWidth = 1.1;
                ctx.stroke();
                ctx.restore();

                ctx.save();
                ctx.translate(c, c);
                ctx.rotate(-30 * Math.PI / 180);
                ctx.beginPath();
                ctx.ellipse(0, 0, r*1.15, r*0.42, 0, 0, Math.PI*2);
                ctx.lineWidth = 1.1;
                ctx.stroke();
                ctx.restore();

                ctx.beginPath();
                ctx.arc(c, c, r*0.32, 0, Math.PI*2);
                ctx.fill();
            } else if (root.kind === "asterism") {
                var Ra = r * 0.85;
                ctx.beginPath(); ctx.arc(c, c - Ra, r*0.32, 0, Math.PI*2); ctx.fill();
                ctx.beginPath(); ctx.arc(c - Ra*0.866, c + Ra*0.5, r*0.32, 0, Math.PI*2); ctx.fill();
                ctx.beginPath(); ctx.arc(c + Ra*0.866, c + Ra*0.5, r*0.32, 0, Math.PI*2); ctx.fill();
            } else if (root.kind === "planet") {
                ctx.beginPath();
                ctx.arc(c, c, r*0.78, 0, Math.PI*2);
                ctx.fill();
                ctx.globalAlpha = 0.7;
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.ellipse(c, c, r*1.25, r*0.28, 0, 0, Math.PI*2);
                ctx.stroke();
                ctx.globalAlpha = 1.0;
            } else if (root.kind === "waning") {
                ctx.beginPath();
                ctx.arc(c, c, r, 0, Math.PI*2);
                ctx.fill();
                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(c - r*0.42, c - r*0.18, r*0.95, 0, Math.PI*2);
                ctx.fill();
                ctx.globalCompositeOperation = "source-over";


            } else if (root.kind === "pulsar") {
                ctx.beginPath();
                ctx.arc(c, c, r*0.22, 0, Math.PI*2);
                ctx.fill();
                ctx.lineCap = "round";
                ctx.lineWidth = 1.3;
                ctx.beginPath();
                ctx.moveTo(c, c - r*0.35);
                ctx.lineTo(c, c - r*1.1);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(c, c + r*0.35);
                ctx.lineTo(c, c + r*1.1);
                ctx.stroke();
                ctx.lineWidth = 0.9;
                ctx.globalAlpha = 0.5;
                ctx.beginPath(); ctx.arc(c, c, r*0.58, 0, Math.PI*2); ctx.stroke();
                ctx.globalAlpha = 0.25;
                ctx.beginPath(); ctx.arc(c, c, r*0.88, 0, Math.PI*2); ctx.stroke();
                ctx.globalAlpha = 1.0;

            } else if (root.kind === "binary") {

                ctx.beginPath();
                ctx.arc(c - r*0.48, c, r*0.42, 0, Math.PI*2);
                ctx.fill();
                ctx.beginPath();
                ctx.arc(c + r*0.58, c, r*0.26, 0, Math.PI*2);
                ctx.fill();
                ctx.lineWidth = 0.9;
                ctx.globalAlpha = 0.5;
                ctx.beginPath();
                ctx.ellipse(c, c, r*1.15, r*0.32, 0, 0, Math.PI*2);
                ctx.stroke();
                ctx.globalAlpha = 1.0;

            } else if (root.kind === "solstice") {
                ctx.beginPath();
                ctx.arc(c, c, r*0.44, 0, Math.PI*2);
                ctx.fill();
                ctx.lineCap = "round";
                for (var si = 0; si < 8; si++) {
                    var sa = -Math.PI/2 + si * Math.PI / 4;
                    var isMain = (si % 2 === 0);
                    var inner = r * 0.62;
                    var outer = isMain ? r * 1.18 : r * 0.88;
                    ctx.lineWidth = isMain ? 1.4 : 1.0;
                    ctx.beginPath();
                    ctx.moveTo(c + Math.cos(sa) * inner, c + Math.sin(sa) * inner);
                    ctx.lineTo(c + Math.cos(sa) * outer, c + Math.sin(sa) * outer);
                    ctx.stroke();
                }

            } else if (root.kind === "vortex") {
                ctx.lineCap = "round";
                ctx.lineWidth = 1.2;
                ctx.beginPath();
                var vsteps = 72;
                for (var vi = 0; vi <= vsteps; vi++) {
                    var vt = vi / vsteps;
                    var vangle = -Math.PI/2 + vt * Math.PI * 2.6;
                    var vrad = r * 0.12 + vt * r * 0.92;
                    var vx = c + Math.cos(vangle) * vrad;
                    var vy = c + Math.sin(vangle) * vrad;
                    if (vi === 0) ctx.moveTo(vx, vy); else ctx.lineTo(vx, vy);
                }
                ctx.stroke();
                // Center dot
                ctx.beginPath();
                ctx.arc(c, c, r*0.18, 0, Math.PI*2);
                ctx.fill();

            } else if (root.kind === "halo") {
                ctx.beginPath();
                ctx.arc(c, c, r*0.5, 0, Math.PI*2);
                ctx.fill();
                ctx.lineWidth = 1.3;
                ctx.beginPath();
                ctx.arc(c, c, r*0.92, 0, Math.PI*2);
                ctx.stroke();
                ctx.globalAlpha = 0.75;
                for (var hi = 0; hi < 4; hi++) {
                    var ha = hi * Math.PI / 2;
                    ctx.beginPath();
                    ctx.arc(c + Math.cos(ha)*r*0.92, c + Math.sin(ha)*r*0.92, r*0.11, 0, Math.PI*2);
                    ctx.fill();
                }
                ctx.globalAlpha = 1.0;

            } else if (root.kind === "nebula") {
                ctx.lineWidth = 1.1;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.globalAlpha = 0.92;
                ctx.beginPath();
                ctx.moveTo(c - r*0.7,  c + r*0.25);
                ctx.bezierCurveTo(c - r*1.05, c - r*0.45,  c - r*0.3,  c - r*1.05,  c + r*0.15, c - r*0.95);
                ctx.bezierCurveTo(c + r*0.55,  c - r*0.85,  c + r*1.05, c - r*0.2,   c + r*0.85, c + r*0.38);
                ctx.bezierCurveTo(c + r*0.65,  c + r*0.9,   c + r*0.0,  c + r*1.05,  c - r*0.45, c + r*0.8);
                ctx.bezierCurveTo(c - r*0.88,  c + r*0.72,  c - r*0.4,  c + r*0.45,  c - r*0.7,  c + r*0.25);
                ctx.stroke();
                ctx.globalAlpha = 1.0;
                // Bright core
                ctx.beginPath();
                ctx.arc(c + r*0.08, c - r*0.12, r*0.22, 0, Math.PI*2);
                ctx.fill();
            }
        }
    }

    onColorChanged: cv.requestPaint()
    onKindChanged: cv.requestPaint()
}

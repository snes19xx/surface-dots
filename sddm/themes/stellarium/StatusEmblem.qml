////////////////
// [Stellarium SDDM theme by @snes19xx]
//
// StatusEmblem.qml -- 7 of 8 files
// A status emblem for displaying authentication states uses glyphs from @ShapeGlyph.qml 
// and custom canvas drawings for animations.
//
////////////////

import QtQuick 2.15

Item {
    id: root
    width: 72
    height: 72
    property string state: "idle" // idle | typing | auth | ok | wrong
    property color accent: "#87b08a"

    // Shake animation for "wrong" state
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: contentRoot; property: "x"; from: 0; to: -3; duration: 90 }
        NumberAnimation { target: contentRoot; property: "rotation"; from: 0; to: -2; duration: 90 }
        NumberAnimation { target: contentRoot; property: "x"; from: -3; to: 3; duration: 90 }
        NumberAnimation { target: contentRoot; property: "rotation"; from: -2; to: 2; duration: 90 }
        NumberAnimation { target: contentRoot; property: "x"; from: 3; to: -2; duration: 90 }
        NumberAnimation { target: contentRoot; property: "rotation"; from: 2; to: 0; duration: 90 }
        NumberAnimation { target: contentRoot; property: "x"; from: -2; to: 0; duration: 90 }
    }

    onStateChanged: {
        if (state === "wrong") {
            shakeAnim.restart();
            meteorAnim.restart();
        } else if (state === "ok") {
            bloomAnim.restart();
        }
    }

    Item {
        id: contentRoot
        anchors.fill: parent

        // IDLE (crescent)
        Canvas {
            anchors.fill: parent
            opacity: root.state === "idle" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 240 } }
            onPaint: {
                var ctx = getContext("2d"); ctx.reset();
                ctx.beginPath(); ctx.arc(36, 36, 14, 0, Math.PI*2);
                ctx.strokeStyle = "#8d8676"; ctx.lineWidth = 1; ctx.stroke();
                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath(); ctx.arc(42, 32, 13, 0, Math.PI*2); ctx.fill();
            }
        }

        // TYPING (orbit of 3 dots around faint crescent)
        Item {
            anchors.fill: parent
            opacity: root.state === "typing" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 240 } }

            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset();
                    ctx.beginPath(); ctx.arc(36, 36, 11, 0, Math.PI*2);
                    ctx.strokeStyle = "#8d8676"; ctx.lineWidth = 1; ctx.stroke();
                    ctx.globalCompositeOperation = "destination-out";
                    ctx.beginPath(); ctx.arc(40, 33, 10, 0, Math.PI*2); ctx.fill();
                }
            }

            Item {
                width: 72; height: 72
                anchors.centerIn: parent
                RotationAnimation on rotation {
                    loops: Animation.Infinite; from: 0; to: 360; duration: 3400; running: root.state === "typing"
                }
                Rectangle { x: 36-2.4; y: 14-2.4; width: 4.8; height: 4.8; radius: 2.4; color: root.accent }
                Rectangle { x: 55-1.6; y: 46-1.6; width: 3.2; height: 3.2; radius: 1.6; color: root.accent; opacity: 0.65 }
                Rectangle { x: 17-1.2; y: 46-1.2; width: 2.4; height: 2.4; radius: 1.2; color: root.accent; opacity: 0.35 }
            }
        }

        // AUTH (tight orbit, inner pulse)
        Item {
            anchors.fill: parent
            opacity: root.state === "auth" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 240 } }

            Rectangle {
                width: 12; height: 12; radius: 6; color: root.accent
                anchors.centerIn: parent
                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: root.state === "auth"
                    NumberAnimation { from: 1; to: 1.08; duration: 450; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.08; to: 1; duration: 450; easing.type: Easing.InOutQuad }
                }
            }

            Item {
                width: 72; height: 72
                anchors.centerIn: parent
                RotationAnimation on rotation {
                    loops: Animation.Infinite; from: 0; to: 360; duration: 1200; running: root.state === "auth"
                }
                Rectangle { x: 36-2; y: 18-2; width: 4; height: 4; radius: 2; color: root.accent }
                Rectangle { x: 54-2; y: 36-2; width: 4; height: 4; radius: 2; color: root.accent }
                Rectangle { x: 36-2; y: 54-2; width: 4; height: 4; radius: 2; color: root.accent }
                Rectangle { x: 18-2; y: 36-2; width: 4; height: 4; radius: 2; color: root.accent }
            }
        }

        // OK (sun bloom)
        Item {
            id: okItem
            anchors.fill: parent
            opacity: root.state === "ok" ? 1 : 0
            // The bloom anim is triggered in onStateChanged
            SequentialAnimation {
                id: bloomAnim
                ParallelAnimation {
                    NumberAnimation { target: okItem; property: "scale"; from: 0.4; to: 1.15; duration: 336; easing.type: Easing.OutCubic }
                    NumberAnimation { target: okItem; property: "opacity"; from: 0; to: 1; duration: 336 }
                }
                NumberAnimation { target: okItem; property: "scale"; from: 1.15; to: 1; duration: 224; easing.type: Easing.OutCubic }
            }

            Rectangle { width: 16; height: 16; radius: 8; color: root.accent; anchors.centerIn: parent }
            Canvas {
                anchors.fill: parent
                property real rayProgress: 0
                SequentialAnimation on rayProgress {
                    id: rayAnim
                    running: root.state === "ok"
                    NumberAnimation { from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }
                }
                onRayProgressChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset();
                    ctx.strokeStyle = root.accent; ctx.lineWidth = 1.6; ctx.lineCap = "round";
                    for(var i=0; i<12; i++){
                        var a = i * Math.PI / 6;
                        var progressOffset = Math.max(0, rayProgress - i * 0.05);
                        if (progressOffset <= 0) continue;
                        var ext = 14 + 10 * Math.min(1, progressOffset * 2);
                        ctx.beginPath();
                        ctx.moveTo(36 + Math.cos(a)*14, 36 + Math.sin(a)*14);
                        ctx.lineTo(36 + Math.cos(a)*ext, 36 + Math.sin(a)*ext);
                        ctx.stroke();
                    }
                }
            }
        }

        // WRONG (meteor break off)
        Item {
            anchors.fill: parent
            opacity: root.state === "wrong" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 240 } }

            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset();
                    ctx.beginPath(); ctx.arc(36, 36, 14, 0, Math.PI*2);
                    ctx.strokeStyle = "rgba(217,144,137,0.7)"; ctx.lineWidth = 1.2; ctx.stroke();
                    ctx.globalCompositeOperation = "destination-out";
                    ctx.beginPath(); ctx.arc(42, 32, 13, 0, Math.PI*2); ctx.fill();
                }
            }

            Item {
                id: meteorItem
                anchors.fill: parent
                NumberAnimation {
                    id: meteorAnim
                    target: meteorItem
                    property: "x"
                    from: 0; to: 28; duration: 700; easing.type: Easing.OutQuad
                }
                NumberAnimation on y {
                    running: meteorAnim.running
                    from: 0; to: 28; duration: 700; easing.type: Easing.OutQuad
                }
                NumberAnimation on opacity {
                    running: meteorAnim.running
                    from: 1; to: 0; duration: 700; easing.type: Easing.OutQuad
                }

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset();
                        ctx.strokeStyle = "rgba(217,144,137,0.7)"; ctx.lineWidth = 1.4; ctx.lineCap = "round";
                        ctx.beginPath(); ctx.moveTo(36, 20); ctx.lineTo(46, 30); ctx.stroke();
                        ctx.fillStyle = "#d99089";
                        ctx.beginPath(); ctx.arc(36, 20, 2.2, 0, Math.PI*2); ctx.fill();
                    }
                }
            }
        }
    }
}
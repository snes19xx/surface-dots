import QtQuick 2.15
import QtQuick.Shapes 1.15

Item {
    id: root
    width: 320
    height: 170

    // --- PROPERTIES ---
    property string status: "idle"
    property string username: ""

    property color colorScan:     "#ffffff"
    property color colorVerified: "#ffffff"
    property color colorError:    "#ff6b6b"

    property color currentColor: colorScan
    property real  currentY:     30
    property real  curveDepth:   0


    // --- FACE CONTAINER ---
    Item {
        id: faceContainer
        width: 120
        height: 120
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        // EYES
        Item {
            id: eyesContainer
            y: 25; width: 70; height: 20
            anchors.horizontalCenter: parent.horizontalCenter
            z: 2

            Rectangle {
                id: eyeLeft
                width: 18; height: 18; radius: 9
                color: root.currentColor
                anchors.left: parent.left
                opacity: 0; scale: 0
            }
            Rectangle {
                id: eyeRight
                width: 18; height: 18; radius: 9
                color: root.currentColor
                anchors.right: parent.right
                opacity: 0; scale: 0
            }
        }

        // MOUTH
        Shape {
            id: mouthShape
            width: 80; height: 60
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.status === "verified" ? 15 : 0
            layer.enabled: true; layer.samples: 4

            ShapePath {
                strokeColor: root.currentColor
                strokeWidth: 10
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: 10; startY: root.currentY - root.curveDepth
                PathQuad {
                    controlX: 40; controlY: root.currentY + root.curveDepth
                    x: 70;       y: root.currentY - root.curveDepth
                }
            }
            Behavior on anchors.verticalCenterOffset {
                NumberAnimation { duration: 400; easing.type: Easing.InOutQuad }
            }
        }
    }


    // --- STATUS TEXT ---
    Text {
        id: statusText
        anchors.top: faceContainer.bottom
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter

        font.pixelSize: 17
        font.family: "Inter"
        font.weight: Font.Medium

        color: {
            if (root.status === "verified") return root.colorVerified
            if (root.status === "failed")   return root.colorError
            return root.colorScan
        }

        text: {
            if (root.status === "scanning") return "Looking for you..."
            if (root.status === "verified") return "Face verified. Welcome back, " + root.username + "!"
            if (root.status === "failed")   return "Face not recognized."
            return ""
        }

        opacity: (root.status !== "idle") ? 1.0 : 0.0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 400 } }
        Behavior on color   { ColorAnimation  { duration: 300 } }
    }


    // --- SCANNING MOUTH ---
    SequentialAnimation {
        running: root.status === "scanning"
        loops: Animation.Infinite
        alwaysRunToEnd: false
        NumberAnimation { target: root; property: "currentY"; from: 20; to: 40; duration: 1000; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "currentY"; from: 40; to: 20; duration: 1000; easing.type: Easing.InOutSine }
    }


    // --- STATES ---
    states: [
        State {
            name: "idle"
            when: root.status === "idle"
            PropertyChanges { target: root;     currentColor: root.colorScan; curveDepth: 0; currentY: 30 }
            PropertyChanges { target: eyeLeft;  opacity: 0; scale: 0 }
            PropertyChanges { target: eyeRight; opacity: 0; scale: 0 }
        },
        State {
            name: "scanning"
            when: root.status === "scanning"
            PropertyChanges { target: root;     currentColor: root.colorScan; curveDepth: 0 }
            PropertyChanges { target: eyeLeft;  opacity: 0; scale: 0 }
            PropertyChanges { target: eyeRight; opacity: 0; scale: 0 }
        },
        State {
            name: "verified"
            when: root.status === "verified"
            PropertyChanges { target: root;    currentColor: root.colorVerified; currentY: 30; curveDepth: 15 }
            PropertyChanges { target: eyeLeft; opacity: 1; scale: 1 }
        },
        State {
            name: "failed"
            when: root.status === "failed"
            PropertyChanges { target: root; currentColor: root.colorError; currentY: 30; curveDepth: -5 }
        }
    ]


    // --- TRANSITIONS ---
    transitions: [
        Transition {
            from: "*"; to: "verified"
            // Eyes appear + color change
            ParallelAnimation {
                ColorAnimation  { duration: 300 }
                NumberAnimation { properties: "currentY, curveDepth"; duration: 400; easing.type: Easing.OutBack }
                NumberAnimation { target: eyeLeft;  properties: "opacity, scale"; to: 1; duration: 300; easing.type: Easing.OutBack }
                NumberAnimation { target: eyeRight; properties: "opacity, scale"; to: 1; duration: 300; easing.type: Easing.OutBack }
            }
            // Right eye winks after smile settles
            SequentialAnimation {
                PauseAnimation { duration: 400 }
                ParallelAnimation {
                    NumberAnimation { target: eyeRight; property: "height"; to: 4; duration: 150 }
                    NumberAnimation { target: eyeRight; property: "radius"; to: 2; duration: 150 }
                }
            }
        },
        Transition {
            from: "*"; to: "failed"
            ParallelAnimation {
                ColorAnimation  { duration: 200 }
                NumberAnimation { properties: "curveDepth"; duration: 200 }
            }
        }
    ]
}

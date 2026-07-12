import QtQuick
import "../theme.js" as Theme

Rectangle {
    id: root
    
    // --- PROPERTIES ---
    property string icon: ""
    property real size: 30
    property color tint: Qt.rgba(1,1,1,0.85) 
    
    signal clicked()

    width: size
    height: size
    radius: size / 2
    
    // Hover background
    color: mouse.pressed ? Qt.rgba(tint.r, tint.g, tint.b, 0.22)
                         : (mouse.containsMouse ? Qt.rgba(tint.r, tint.g, tint.b, 0.14) : "transparent")
    
    Behavior on color { ColorAnimation { duration: 140 } }

    // --- RIPPLE PULSE EFFECT ---
    Rectangle {
        id: pulse
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: width / 2
        color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.18)
        opacity: 0.0
        scale: 0.6
    }

    SequentialAnimation {
        id: pulseAnim
        NumberAnimation { target: pulse; property: "opacity"; from: 0.0; to: 1.0; duration: 70 }
        NumberAnimation { target: pulse; property: "scale"; from: 0.6; to: 1.25; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: pulse; property: "opacity"; from: 1.0; to: 0.0; duration: 160 }
        ScriptAction { script: { pulse.scale = 0.6 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Theme.iconFont
        font.pixelSize: root.size * 0.58
        color: root.tint
        opacity: mouse.pressed ? 0.75 : 0.95
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            pulseAnim.restart()
            root.clicked()
        }
    }
    
    // ---SQUISH EFFECT ---
    scale: mouse.pressed ? 0.90 : 1.0
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
}
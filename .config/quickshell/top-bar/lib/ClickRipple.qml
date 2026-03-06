import QtQuick

Item {
    id: root
    anchors.fill: parent
    clip: true 

    property color color: Qt.rgba(1, 1, 1, 0.12)
    property int duration: 450
    
    function burst(x, y) {
        rippleAnim.stop()
        ripple.x = x - (ripple.width / 2)
        ripple.y = y - (ripple.height / 2)
        rippleAnim.start()
    }

    Rectangle {
        id: ripple
        width: Math.max(root.width, root.height) * 2.2
        height: width
        radius: width / 2
        color: root.color
        
        // Start invisible and small
        opacity: 0
        scale: 0

        ParallelAnimation {
            id: rippleAnim
            NumberAnimation {
                target: ripple
                property: "scale"
                from: 0.0; to: 1.0
                duration: root.duration
                easing.type: Easing.OutQuart
            }

            // Fade in quickly, then fade out slowly
            SequentialAnimation {
                NumberAnimation {
                    target: ripple
                    property: "opacity"
                    from: 0.0; to: 0.4
                    duration: root.duration * 0.2
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: ripple
                    property: "opacity"
                    from: 0.4; to: 0.0
                    duration: root.duration * 0.8
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
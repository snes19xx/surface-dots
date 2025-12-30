import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme.js" as Theme

Item {
    property QtObject theme: null

    id: root
    property string icon: ""
    property real from: 0; property real to: 100
    property alias value: slider.value
    property bool pressed: slider.pressed
    property color accentColor: (root.theme ? (root.theme.accentSlider !== undefined ? root.theme.accentSlider : root.theme.accent) : Theme.accent)
    signal userChanged(real v)

    implicitHeight: 32
    Layout.fillWidth: true

    Timer {
        id: send; interval: 70; repeat: false
        onTriggered: root.userChanged(slider.value)
    }

    Slider {
        id: slider
        anchors.fill: parent
        from: root.from; to: root.to
        
        hoverEnabled: true 

        onMoved: send.restart()
        onPressedChanged: if (!pressed) send.restart()

        background: Rectangle {
            x: slider.leftPadding
            y: (slider.availableHeight - height) / 2
            width: slider.availableWidth
            height: 32
            radius: 16 
            
            // Track Color
            color: (root.theme ? root.theme.bgItem : Theme.bgItem) 

            // SQUISH
            transform: Scale {
                origin.x: parent.width / 2
                origin.y: parent.height / 2
                xScale: slider.pressed ? 1.02 : 1.0
                yScale: slider.pressed ? 0.95 : 1.0
                Behavior on xScale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                Behavior on yScale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            }

            // FILL (+ Vibrancy)
            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 16
                color: root.accentColor
                opacity: 0.2 + (slider.visualPosition * 0.6)
                Behavior on width { NumberAnimation { duration: 80 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            // ICON (Inside the slider)
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 14 
                
                text: root.icon
                font.family: Theme.iconFont
                font.pixelSize: 18
                
                // Color vibrancy changes based on position
                color: slider.visualPosition > 0.15 ? (root.theme ? root.theme.textOnAccent : Theme.fgOnAccent) : (root.theme ? root.theme.textSecondary : Theme.fgMuted)
                Behavior on color { ColorAnimation { duration: 200 } }

                // --- ICON POP ---
                // Pop up when hovering OR dragging
                scale: slider.hovered || slider.pressed ? 1.3 : 1.0
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
            }
        }

        handle: Item { width: 0; height: 0 } 
    }
}
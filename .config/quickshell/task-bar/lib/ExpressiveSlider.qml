import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects 
import "../theme.js" as Theme

Item {
    id: root
    property QtObject theme: null
    property string icon: ""
    property real from: 0
    property real to: 100
    property alias value: slider.value
    property bool pressed: slider.pressed
    property int orientation: Qt.Horizontal 
    
    property color accentColor: (root.theme ? (root.theme.accentSlider !== undefined ? root.theme.accentSlider : root.theme.accent) : Theme.accent)
    signal userChanged(real v)


    implicitHeight: orientation === Qt.Horizontal ? 32 : 100
    implicitWidth: orientation === Qt.Horizontal ? 100 : 32
    
    Layout.fillWidth: orientation === Qt.Horizontal
    Layout.fillHeight: orientation === Qt.Vertical

    Timer {
        id: send
        interval: 70; repeat: false
        onTriggered: root.userChanged(slider.value)
    }

    Slider {
        id: slider
        anchors.fill: parent
        from: root.from
        to: root.to
        orientation: root.orientation 
        
        hoverEnabled: true 

        onMoved: send.restart()
        onPressedChanged: if (!pressed) send.restart()

        background: Rectangle {
            x: root.orientation === Qt.Horizontal ? slider.leftPadding : (slider.availableWidth - width) / 2
            y: root.orientation === Qt.Horizontal ? (slider.availableHeight - height) / 2 : slider.topPadding
            
            width: root.orientation === Qt.Horizontal ? slider.availableWidth : 32
            height: root.orientation === Qt.Horizontal ? 32 : slider.availableHeight
            
            radius: 16 
            color: (root.theme ? root.theme.bgItem : Theme.bgItem) 

            // The Fill
            Rectangle {
                width: root.orientation === Qt.Horizontal ? (slider.visualPosition * parent.width) : parent.width
                height: root.orientation === Qt.Horizontal ? parent.height : (slider.visualPosition * parent.height)
                
                y: root.orientation === Qt.Horizontal ? 0 : parent.height - height
                
                radius: 16
                color: root.accentColor
                opacity: 0.2 + (slider.visualPosition * 0.6)
            }

            // Icon Container
            Item {
                width: 18
                height: 18
                
                // Horizontal Position (Left Center)
                anchors.left: root.orientation === Qt.Horizontal ? parent.left : undefined
                anchors.verticalCenter: root.orientation === Qt.Horizontal ? parent.verticalCenter : undefined
                anchors.leftMargin: root.orientation === Qt.Horizontal ? 14 : 0

                // Vertical Position (Bottom Center)
                anchors.bottom: root.orientation === Qt.Vertical ? parent.bottom : undefined
                anchors.horizontalCenter: root.orientation === Qt.Vertical ? parent.horizontalCenter : undefined
                anchors.bottomMargin: root.orientation === Qt.Vertical ? 14 : 0

                Image {
                    id: iconImg
                    source: root.icon
                    sourceSize: Qt.size(width, height)
                    anchors.fill: parent
                    visible: false 
                    smooth: true
                    mipmap: true
                }

                ColorOverlay {
                    anchors.fill: iconImg
                    source: iconImg
                    cached: true
                    
                    // If slider covers icon (>15%), use Accent Text.
                    color: slider.visualPosition > 0.15 
                        ? (root.theme ? root.theme.textOnAccent : Theme.fgOnAccent) 
                        : (root.theme ? root.theme.textSecondary : Theme.fgMuted)
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                    
                    transformOrigin: Item.Center
                    scale: slider.hovered || slider.pressed ? 1.3 : 1.0
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                }
            }
        }

        handle: Item { width: 0; height: 0 } 
    }
}
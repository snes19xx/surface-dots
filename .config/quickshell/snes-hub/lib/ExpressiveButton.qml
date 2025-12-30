import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme

Item {
    id: root
    implicitHeight: Theme.btnH
    Layout.fillWidth: true 
    property QtObject theme: null

    
    property string icon: ""
    property string label: ""
    property bool active: false
    property int fixX: 0 
    
    property color customIconColor: "transparent"
    property bool hasCustomColor: false
    
    signal clicked()
    signal rightClicked()
    
    // squish effect on press
    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: mouse.pressed ? 1.03 : 1.0
        yScale: mouse.pressed ? 0.96 : 1.0
        Behavior on xScale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
        Behavior on yScale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radiusInner
        
        color: root.active ? (root.theme ? root.theme.accent : Theme.accent) : (root.theme ? root.theme.bgItem : Theme.bgItem)
        Behavior on color { ColorAnimation { duration: 200 } }
        
        // Hover Overlay
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.active ? "black" : ((root.theme && root.theme.isDarkMode === false) ? "black" : "white")
            opacity: mouse.containsMouse ? (root.active ? 0.10 : 0.08) : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
        
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            
            Text {
                text: root.icon
                font.family: Theme.iconFont
                font.pixelSize: 25
                
                color: root.active 
                       ? (root.theme ? root.theme.textOnAccent : Theme.fgOnAccent) 
                       : (root.hasCustomColor ? root.customIconColor : (root.theme ? root.theme.textPrimary : Theme.fgMain))
                
                topPadding: 2 
                leftPadding: root.fixX > 0 ? root.fixX : 0
                rightPadding: root.fixX < 0 ? -root.fixX : 0
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter

                // --- 2.ICON POP EFFECT ---
                transformOrigin: Item.Center
                scale: mouse.containsMouse ? 1.20 : 1.0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            }
            
            Text {
                text: root.label
                font.family: Theme.textFont
                font.pixelSize: 8 
                font.weight: 500
                opacity: root.active ? 0.9 : 0.7 
                
                color: root.active ? (root.theme ? root.theme.textOnAccent : Theme.fgOnAccent) : (root.theme ? root.theme.textPrimary : Theme.fgMain)
                
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: root.width - 8
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (m) => m.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
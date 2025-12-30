import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../theme.js" as Theme

Item {
    id: root
    property string icon: ""
    property string text: ""
    property color textColor: "#d5c9b2"
    property color iconColor: root.textColor
    property int borderWidth: 1
    property color bgColor: Qt.rgba(0.23, 0.25, 0.22, 0.25)
    property color borderColor: Qt.rgba(1, 1, 1, 0)
    
    // Spotlight Color- Dynamic
    property color hoverColor: Qt.rgba(1, 1, 1, 0.14)
    property bool shimmerEnabled: true

property bool toggleable: false
property bool checked: false
property string iconOff: root.icon
property string iconOn: root.icon
property string textOff: root.text
property string textOn: root.text
property color checkedBgColor: root.bgColor
property color checkedTextColor: root.textColor
property color checkedIconColor: root.iconColor
property int selectedRadius: 8
property int pressedRadius: 10
readonly property string shownIcon: toggleable ? (checked ? iconOn : iconOff) : icon
readonly property string shownText: toggleable ? (checked ? textOn : textOff) : text
    signal clicked(var mouse)

    height: 34
    implicitWidth: layout.implicitWidth + 24
    property real hx: width / 2
    property real hy: height / 2

    Rectangle { 
        id: mask
        anchors.fill: parent
        radius: height / 2
        visible: false
        antialiasing: true 
    }

    Item {
        id: maskedLayer
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask { maskSource: mask }

        Rectangle {
            anchors.fill: parent
            radius: mask.radius
            color: (toggleable && checked) ? checkedBgColor : root.bgColor
            Behavior on radius { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            antialiasing: true
            Behavior on color { ColorAnimation { duration: 180 } }
        }

Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: Qt.rgba(root.hoverColor.r, root.hoverColor.g, root.hoverColor.b, 1)
    opacity: press.pressed ? 0.22 : (hover.hovered ? 0.14 : 0.0)
    antialiasing: true
    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
}

        Rectangle { 
            id: hoverSrc
            anchors.fill: parent
            radius: mask.radius
            color: "white"
            visible: false 
        }

        RadialGradient {
            anchors.fill: parent
            source: hoverSrc
            horizontalRadius: width * 0.9
            verticalRadius: height * 1.7
            horizontalOffset: root.hx - width / 2
            verticalOffset: root.hy - height / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.hoverColor } 
                GradientStop { position: 0.7; color: "transparent" }
            }
            opacity: (hover.hovered || press.pressed) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        Rectangle {
            id: shimmer
            visible: root.shimmerEnabled
            width: 52
            height: parent.height * 2
            color: "transparent"
            rotation: 20
            x: -100
            y: -parent.height / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1,1,1,0.18) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        antialiasing: true
        border.width: root.borderWidth
        border.color: hover.hovered ? Qt.rgba(1,1,1,0.20) : root.borderColor
        Behavior on border.color { ColorAnimation { duration: 160 } }
    }

    NumberAnimation { 
        id: shimmerAnim
        target: shimmer
        property: "x"
        from: -60
        to: root.width + 60
        duration: 750
        easing.type: Easing.InOutQuad 
    }
    
    scale: (hover.hovered ? 1.06 : 1.0) * (press.pressed ? 0.94 : 1.0)
    y: press.pressed ? 2 : (hover.hovered ? -1 : 0)
    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.18 } }
    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 8
        Text { 
            visible: root.shownIcon !== ""
            text: root.shownIcon
            font.family: Theme.iconFont
            font.pixelSize: 14
            color: (toggleable && checked) ? checkedIconColor : root.iconColor
            Layout.alignment: Qt.AlignVCenter 
        }
        Text { 
            visible: root.shownText !== ""
            text: root.shownText
            font.family: Theme.textFont
            font.pixelSize: 13
            font.weight: 700
            color: (toggleable && checked) ? checkedTextColor : root.textColor
            Layout.alignment: Qt.AlignVCenter 
        }
    }
    MouseArea {
        id: press
        anchors.fill: parent
        hoverEnabled: true
        onClicked: (mouse) => { if (root.toggleable) root.checked = !root.checked; root.clicked(mouse) }
        onEntered: if (root.shimmerEnabled) shimmerAnim.restart()
        onPositionChanged: (mouse) => { root.hx = mouse.x; root.hy = mouse.y }
    }
    HoverHandler { id: hover }
}
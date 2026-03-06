import QtQuick 2.15

Item {
  id: root
  anchors.fill: parent
  clip: true

  property color rippleColor: Qt.rgba(1, 1, 1, 0.10)

  function burst(px, py) {
    circle.x = px - circle.width / 2
    circle.y = py - circle.height / 2
    anim.restart()
  }

  Rectangle {
    id: circle
    width: Math.max(root.width, root.height) * 2
    height: width
    radius: width / 2
    color: root.rippleColor
    opacity: 0
    scale: 0.2
  }

  SequentialAnimation {
    id: anim
    running: false

    ScriptAction { script: { circle.opacity = 0.9; circle.scale = 0.2 } }

    ParallelAnimation {
      NumberAnimation { target: circle; property: "scale"; to: 1.0; duration: 240; easing.type: Easing.OutCubic }
      NumberAnimation { target: circle; property: "opacity"; to: 0.0; duration: 260; easing.type: Easing.OutCubic }
    }
  }
}

import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme

Rectangle {
  id: root
  radius: 999
  color: Theme.bgItem
  border.width: 1
  border.color: Qt.rgba(1,1,1,0.06)

  property string icon: ""
  property string text: ""

  implicitHeight: 20 
  implicitWidth: row.implicitWidth + 14

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 4

    Text {
      text: root.icon
      font.family: Theme.iconFont
      font.pixelSize: 10
      font.weight: 900 
      color: Theme.accent
    }

    Text {
      text: root.text
      font.family: Theme.textFont
      font.pixelSize: 9
      font.weight: 800
      color: Theme.fgMain
    }
  }
}
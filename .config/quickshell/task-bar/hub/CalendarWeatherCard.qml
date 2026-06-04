import QtQuick
import QtQuick.Layouts
import Quickshell
import "../lib" as Lib
import "../theme.js" as Theme

Lib.Card {
  id: root
  signal closeRequested()
  property bool active: true
  property date now: new Date()
  color: root.theme ? root.theme.bgCard : Theme.bgCard
  
  // Minute timer only runs when visible
  Timer {
    interval: 60000
    repeat: true
    running: root.active && root.visible
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  Lib.CommandPoll {
    id: weather
    running: root.active && root.visible
    interval: 60000
    command: ["bash","-lc", "$HOME/.config/quickshell/task-bar/lib/weather.sh"]
    parse: function(out) {
      try {
        var d = JSON.parse(String(out))
        return { temp: d.temp ?? "--", icon: d.icon ?? "☁", desc: d.desc ?? "Error" }
      } catch(e) {
        return { temp:"--", icon:"☁", desc:"Error" }
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 0
    spacing: -5

    // Top: Date and Weather
    RowLayout {
      Layout.fillWidth: true
      spacing: 0
      
      // Left: Large date
      ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: -8
        transform: Translate { x: 10 }
        
        Text {
          text: Qt.formatDate(root.now, "dddd").toUpperCase()
          font.family: Theme.textFont
          font.pixelSize: 11
          font.weight: 700
          font.letterSpacing: 1.5
          color: (root.theme ? root.theme.accent : Theme.accent)
          opacity: 0.85
        }
        
        Text {
          text: Qt.formatDate(root.now, "d")
          font.family: Theme.textFont
          font.pixelSize: 68
          font.weight: 800
          color: (root.theme ? root.theme.textPrimary : Theme.fgMain)
          lineHeight: 0.8
          lineHeightMode: Text.ProportionalHeight
        }
        
        Text {
          text: Qt.formatDate(root.now, "MMMM yyyy").toUpperCase()
          font.family: Theme.textFont
          font.pixelSize: 10
          font.weight: 600
          font.letterSpacing: 1.0
          color: (root.theme ? root.theme.textSecondary : Theme.fgMuted)
          opacity: 0.65
        }
      }
      
      // Right: Weather
      ColumnLayout {
        Layout.alignment: Qt.AlignTop | Qt.AlignRight
        Layout.preferredWidth: 120
        transform: Translate { x: 19 }
        spacing: 6
        
        Text {
          text: weather.value ? weather.value.icon : "☁"
          font.family: "Symbols Nerd Font"
          font.pixelSize: 32
          color: (root.theme && root.theme.isDarkMode) ? Theme.weatherd : Theme.weatherl
          Layout.alignment: Qt.AlignRight
        }
        
        Text {
          text: weather.value ? weather.value.temp : "--"
          font.family: Theme.textFont
          font.pixelSize: 22
          font.weight: 700
          color: (root.theme ? root.theme.textPrimary : Theme.fgMain)
          Layout.alignment: Qt.AlignRight
        }
        
        Text {
          text: weather.value ? weather.value.desc : "Error"
          font.family: Theme.textFont
          font.pixelSize: 10
          font.weight: 500
          color: (root.theme ? root.theme.textSecondary : Theme.fgMuted)
          Layout.alignment: Qt.AlignRight
          Layout.maximumWidth: 110
          horizontalAlignment: Text.AlignRight
          wrapMode: Text.WordWrap
        }
      }
    }
    
    // Spacer
    Item { Layout.preferredHeight: 16 }
    
    // Calendar Grid
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: calGrid.implicitHeight
      
      CalendarGrid {
        id: calGrid
        anchors.right: parent.right
        when: root.now
        theme: root.theme
      }
    }
    
    Item { Layout.fillHeight: true }
  }
  
  // Click launches my calendar app
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      Quickshell.execDetached(["bash", "-lc", "/opt/evercal/ever_cal"])
      root.closeRequested()
    }
  }
}
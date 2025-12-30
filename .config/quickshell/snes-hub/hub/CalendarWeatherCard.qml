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
    command: ["bash","-lc", "$HOME/.config/quickshell/snes-hub/lib/weather.sh"]
    parse: function(out) {
      try {
        var d = JSON.parse(String(out))
        return { temp: d.temp ?? "--", icon: d.icon ?? "☁", desc: d.desc ?? "—" }
      } catch(e) {
        return { temp:"--", icon:"☁", desc:"Error" }
      }
    }
  }

  // Calendar events (khal) only when visible
  Lib.CommandPoll {
    id: calEvent
    running: root.active && root.visible
    interval: 60000
    command: ["bash", "-lc", "khal list now 1h --format '{title}::{start-time}-{end-time}' 2>/dev/null || true"]
    parse: function(out) {
      var lines = String(out).split("\n")
      var events = []
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line.indexOf("::") !== -1) {
          var parts = line.split("::")
          events.push(parts[0] + " " + parts[1])
        }
      }
      return events
    }
  }

  ColumnLayout {
    spacing: 12
    width: parent.width

    RowLayout {
      Layout.fillWidth: true
      spacing: 0

      ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: -15

        Text {
          text: Qt.formatDate(root.now, "ddd").toUpperCase()
          font.family: Theme.textFont
          font.pixelSize: 22
          font.weight: 600
          color: (root.theme ? root.theme.textPrimary : Theme.fgMain)
          lineHeight: 0.8
          leftPadding: 5
        }

        Text {
          text: Qt.formatDate(root.now, "d")
          font.family: Theme.textFont
          font.pixelSize: 54
          font.weight: 800
          color: (root.theme ? root.theme.textPrimary : Theme.fgMain)
          lineHeight: 0.65
          lineHeightMode: Text.ProportionalHeight
        }

        RowLayout {
          spacing: 6
          Layout.topMargin: 12
          Layout.fillWidth: true

          Text {
            text: weather.value ? weather.value.icon : "☁"
            font.family: Theme.iconFont
            font.pixelSize: 10
            color: ((root.theme && root.theme.accentBlue !== undefined) ? root.theme.accentBlue : Theme.accentBlue)
          }

          Text {
            text: weather.value ? (weather.value.temp + " • " + weather.value.desc) : "—"
            font.family: Theme.textFont
            font.pixelSize: 11
            font.weight: 600
            color: (root.theme ? root.theme.textSecondary : Theme.fgMuted)
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }

      ColumnLayout {
        Layout.preferredWidth: 120
        Layout.minimumWidth: 120
        Layout.maximumWidth: 120
        Layout.alignment: Qt.AlignTop | Qt.AlignRight
        spacing: 6

        Text {
          text: Qt.formatDate(root.now, "MMM").toUpperCase()
          font.family: Theme.textFont
          font.pixelSize: 11
          font.weight: 800
          color: (root.theme ? root.theme.accent : Theme.accent)
          font.letterSpacing: 2.0
          Layout.alignment: Qt.AlignRight
        }

        CalendarGrid {
          Layout.alignment: Qt.AlignRight
          when: root.now
          theme: root.theme
        }
      }
    }

    // AT A GLANCE
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 8

      visible: calEvent.value && calEvent.value.length > 0
      opacity: visible ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 200 } }

      Rectangle { Layout.fillWidth: true; height: 1; color: (root.theme ? (root.theme.isDarkMode ? Qt.rgba(1,1,1,0.05) : Qt.rgba(0,0,0,0.06)) : Qt.rgba(1,1,1,0.05)) }

      Repeater {
        model: calEvent.value
        RowLayout {
          spacing: 8
          Layout.fillWidth: true

          Text {
            text: ""
            font.family: Theme.iconFont
            font.pixelSize: 13
            color: (root.theme ? root.theme.accent : Theme.accent)
          }

          Text {
            text: modelData
            font.family: Theme.textFont
            font.pixelSize: 13
            color: (root.theme ? root.theme.textPrimary : Theme.fgMain)
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }  
    }
  }
  
  // To make CalendarWeatherCard launch my calendar app on click
  MouseArea {
        parent: root  
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Quickshell.execDetached(["bash", "-lc", "/opt/EverCal/ever_cal"])
            root.closeRequested()
        }
    }
}
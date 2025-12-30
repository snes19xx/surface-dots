import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import "../lib" as Lib
import "../theme.js" as Theme
import "../config.js" as Config

Item {
  id: root
  property bool active: true
  property QtObject theme: null

  // ---- Theme ----
  readonly property bool _hasTheme: theme !== null
  readonly property bool _isDark: (!_hasTheme || theme.isDarkMode === undefined) ? true : theme.isDarkMode

  readonly property color _textPrimary: theme ? theme.textPrimary : Theme.fgMain
  readonly property color _outline: theme ? theme.outline : Qt.rgba(1,1,1,0.10)
  readonly property color _subtleFill: theme ? theme.subtleFill : Qt.rgba(1,1,1,0.05)
  readonly property color _subtleFillHover: theme ? theme.subtleFillHover : Qt.rgba(1,1,1,0.15)

  // Power button colors:
  readonly property color _accentRed: _isDark
      ? Theme.accentRed
      : (_hasTheme && theme.accentRed !== undefined ? theme.accentRed : Theme.accentRed)

  readonly property color _pwrIdleBg: _isDark
      ? Qt.rgba(0.9,0.5,0.5,0.15)
      : Qt.rgba(0.5,0.1,0.1,0.12)

  readonly property color _pwrTextOnHover: _isDark
      ? Theme.bgCard
      : (_hasTheme && theme.textOnAccent !== undefined ? theme.textOnAccent : "#ffffff")

  property string profileName: Config.PROFILE_NAME
  property url profileImage: ("file://" + Config.PROFILE_IMG)

  signal closeRequested()

  implicitHeight: 52

  Timer {
    id: snapTimer
    interval: 320
    repeat: false
    onTriggered: Quickshell.execDetached(["bash", "-c", "/home/snes/.config/hypr/screenshots/captureArea.sh"])
  }

  RowLayout {
    anchors.fill: parent
    spacing: 12

    // Profile Pic (circle crop)
    Item {
      width: 48
      height: 48
      Layout.alignment: Qt.AlignVCenter

      Rectangle {
        id: pfpMask
        anchors.fill: parent
        radius: width / 2
        visible: false
        antialiasing: true
      }

      Item {
        anchors.fill: parent
        layer.enabled: root.visible  
        layer.smooth: true
        layer.effect: OpacityMask { maskSource: pfpMask }

        Image {
          id: pfp
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          source: root.profileImage
          mipmap: true
          smooth: true
          cache: true
          asynchronous: true
          sourceSize: Qt.size(256, 256)
        }
      }

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: root._outline
        antialiasing: true
      }
    }

    Text {
      text: root.profileName
      font.family: Theme.textFont
      font.pixelSize: 18
      font.weight: 700
      color: root._textPrimary
      Layout.fillWidth: true
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }

    ColumnLayout {
      Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
      spacing: 5

      RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: 8

        Rectangle {
          id: snapBtn
          width: 24
          height: 24
          radius: 12

          color: snapHover.hovered ? root._subtleFillHover : root._subtleFill
          border.width: 1
          border.color: root._outline

          Behavior on color { ColorAnimation { duration: 150 } }
          Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

          Text {
            anchors.centerIn: parent
            text: ""
            font.family: Theme.iconFont
            font.pixelSize: 16
            color: root._textPrimary
            topPadding: 1
          }

          HoverHandler { id: snapHover }

          SequentialAnimation {
            id: snapAnim

            ParallelAnimation {
              NumberAnimation { target: snapBtn; property: "scale"; to: 0.8; duration: 100; easing.type: Easing.OutBack }
              ColorAnimation { target: snapBtn; property: "color"; to: root._textPrimary; duration: 50 }
              ColorAnimation { target: snapBtn; property: "border.color"; to: root._textPrimary; duration: 50 }
            }

            ScriptAction {
              script: {
                root.closeRequested()
                snapTimer.restart()
              }
            }

            ParallelAnimation {
              NumberAnimation { target: snapBtn; property: "scale"; to: 1.0; duration: 300 }
              ColorAnimation { target: snapBtn; property: "color"; to: "transparent"; duration: 300 }
            }
          }

          TapHandler { onTapped: snapAnim.start() }
        }

        // Power Button 
        Rectangle {
          width: 24
          height: 24
          radius: 12
          color: pwrHover.hovered ? root._accentRed : root._pwrIdleBg
          border.width: 1
          border.color: root._accentRed

          Behavior on color { ColorAnimation { duration: 150 } }
          scale: tap.pressed ? 0.85 : 1.0
          Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutBack } }

          Text {
            anchors.centerIn: parent
            text: "⏻"
            font.family: Theme.iconFont
            font.pixelSize: 10
            color: pwrHover.hovered ? root._pwrTextOnHover : root._accentRed
            topPadding: 1
            rightPadding: -1
          }

          HoverHandler { id: pwrHover }
          TapHandler {
            id: tap
            onTapped: {
                root.closeRequested() 
                Quickshell.execDetached(["bash", "-c", "/home/snes/.config/rofi/power/powermenu.sh"])
            }
          }
        }
      }

      RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: 6
        Lib.Chip { icon: ""; text: cpu.value ?? "0%" }
        Lib.Chip { icon: ""; text: ram.value ?? "0%" }
      }
    }

    // Polls only when visible
    Lib.CommandPoll {
      id: cpu
      running: root.active && root.visible
      interval: 2000
      property var prevIdle: 0
      property var prevTotal: 0
      command: ["bash","-lc","grep 'cpu ' /proc/stat"]
      parse: function(out) {
        var parts = String(out).split(/\s+/)
        var idle = Number(parts[4]) + Number(parts[5])
        var total = 0
        for (var i=1; i<parts.length; i++) total += Number(parts[i])
        var diffTotal = total - prevTotal
        var usage = (diffTotal > 0) ? (1 - ((idle - prevIdle) / diffTotal)) * 100 : 0
        prevIdle = idle
        prevTotal = total
        return Math.round(usage) + "%"
      }
    }

    Lib.CommandPoll {
      id: ram
      running: root.active && root.visible
      interval: 3000
      command: ["bash","-lc","awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END{ if(t>0) printf(\"%d%%\", (100-(a*100/t))); else print \"0%\" }' /proc/meminfo || true"]
      parse: function(o) { return String(o).trim() || "0%" }
    }
  }
}

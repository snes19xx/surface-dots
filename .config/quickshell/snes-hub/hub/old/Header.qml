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
  property string profileName: Config.PROFILE_NAME
  property string profileImage: Config.PROFILE_IMG

  property bool expanded: false
  signal closeRequested()
  signal powerAction(string action, string label)

  readonly property bool _hasTheme: theme !== null
  readonly property bool _isDark: (!_hasTheme || theme.isDarkMode === undefined) ? true : theme.isDarkMode
  readonly property color _textPrimary: theme ? theme.textPrimary : Theme.fgMain
  readonly property color _outline: theme ? theme.outline : Qt.rgba(1,1,1,0.10)
  readonly property color _subtleFill: theme ? theme.subtleFill : Qt.rgba(1,1,1,0.05)
  readonly property color _subtleFillHover: theme ? theme.subtleFillHover : Qt.rgba(1,1,1,0.15)
  readonly property color _accentRed: _isDark ? Theme.accentRed : (_hasTheme && theme.accentRed !== undefined ? theme.accentRed : Theme.accentRed)

  // One animated value for everything
  property real powerContainerHeight: 0

  implicitHeight: 52 + powerContainerHeight
  Behavior on powerContainerHeight {
    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
  }

  function _openPowerMenu() {
    expanded = true
    powerContainerHeight = 240
  }

  function _closePowerMenu() {
    expanded = false
    powerContainerHeight = 0
  }

  onExpandedChanged: {
    if (!expanded) {
        powerContainerHeight = 0
    } else {
        powerContainerHeight = 240  
    }
}

  Timer {
    id: snapTimer
    interval: 320
    repeat: false
    onTriggered: Quickshell.execDetached(["bash", "-c", "/home/snes/.config/hypr/screenshots/captureArea.sh"])
  }

  ColumnLayout {
      anchors.fill: parent
      spacing: 0

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        spacing: 12

        // Profile Pic
        Item {
          width: 48; height: 48
          Layout.alignment: Qt.AlignVCenter
          Rectangle { id: pfpMask; anchors.fill: parent; radius: width/2; visible: false }
          Item {
            anchors.fill: parent; layer.enabled: root.visible; layer.smooth: true
            layer.effect: OpacityMask { maskSource: pfpMask }
            Image {
              anchors.fill: parent
              fillMode: Image.PreserveAspectCrop
              source: (root.profileImage.startsWith("file://") ? "" : "file://") + root.profileImage
              mipmap: true; smooth: true; cache: true; asynchronous: true
              sourceSize: Qt.size(256, 256)
            }
          }
          Rectangle {
            anchors.fill: parent
            radius: width/2
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
                    width: 24; height: 24; radius: 12
                    color: snapTap.pressed ? root._subtleFillHover
                          : (snapHover.hovered ? root._subtleFillHover : root._subtleFill)
                    border.width: 1; border.color: root._outline
                    scale: snapTap.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text { anchors.centerIn: parent; text: ""; font.family: Theme.iconFont; font.pixelSize: 16; color: root._textPrimary; topPadding: 1 }
                    HoverHandler { id: snapHover }
                    TapHandler { id: snapTap; onTapped: { root.closeRequested(); snapTimer.restart() } }
                }

                Rectangle {
                    id: pwrBtn
                    width: 24; height: 24; radius: 12
                    color: pwrTap.pressed ? root._accentRed
                          : ((pwrHover.hovered || root.expanded) ? root._accentRed : root._subtleFill)
                    border.width: 1
                    border.color: root.expanded ? root._accentRed : root._outline
                    scale: pwrTap.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                      anchors.centerIn: parent
                      topPadding: 1
                      rightPadding: -1 
                      
                      text: root.expanded ? "" : ""  // Swaps between Power and Close icons
                      font.family: Theme.iconFont
                      font.pixelSize: 12       
                      color: (pwrHover.hovered || root.expanded || pwrTap.pressed)
                      //  ACTIVE STATE (Hovered/Clicked)
                      ? (root._isDark ? "#e5e6c5" : "#e1e4bd")  
                      
                      //  INACTIVE STATE (Normal)
                      : root._accentRed       
                    }

                    HoverHandler { id: pwrHover }
                    TapHandler {
                        id: pwrTap
                        onTapped: root.expanded ? root._closePowerMenu() : root._openPowerMenu()
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
      }

      // Power Menu Container
      Item {
          id: powerContainer
          Layout.fillWidth: true
          Layout.preferredHeight: root.powerContainerHeight
          height: root.powerContainerHeight
          clip: true

          Loader {
              id: powerLoader
              active: root.expanded
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top

              sourceComponent: Component {
                  PowerMenuGrid {
                      theme: root.theme
                      onCloseRequested: root._closePowerMenu()
                      onActionRequested: function(act, lbl) { root.powerAction(act, lbl) }
                  }
              }

              // When loaded, set height to content
              onStatusChanged: {
                  if (status === Loader.Ready && item) {
                      root.powerContainerHeight = item.implicitHeight
                      item.forceActiveFocus()
                      // also run a delayed resync
                      resyncTimer.restart()
                  }
              }
          }

          // Follow any later implicitHeight changes 
          Connections {
              target: powerLoader.item
              function onImplicitHeightChanged() {
                  if (root.expanded && powerLoader.item)
                      root.powerContainerHeight = powerLoader.item.implicitHeight
              }
          }

          Timer {
              id: resyncTimer
              interval: 180
              repeat: false
              onTriggered: {
                  if (root.expanded && powerLoader.item)
                      root.powerContainerHeight = powerLoader.item.implicitHeight
              }
          }
      }
  }

  Lib.CommandPoll {
      id: cpu
      running: root.active && root.visible; interval: 4000
      property var prevIdle: 0; property var prevTotal: 0
      command: ["bash","-lc","grep 'cpu ' /proc/stat"]
      parse: function(out) {
          var parts = String(out).split(/\s+/)
          var idle = Number(parts[4]) + Number(parts[5])
          var total = 0
          for (var i=1; i<parts.length; i++) total += Number(parts[i])
          var diffTotal = total - prevTotal
          var usage = (diffTotal > 0) ? (1 - ((idle - prevIdle) / diffTotal)) * 100 : 0
          prevIdle = idle; prevTotal = total
          return Math.round(usage) + "%"
      }
  }

  Lib.CommandPoll {
      id: ram
      running: root.active && root.visible; interval: 5000
      command: ["bash","-lc","awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END{ if(t>0) printf(\"%d%%\", (100-(a*100/t))); else print \"0%\" }' /proc/meminfo || true"]
      parse: function(o) { return String(o).trim() || "0%" }
  }
}

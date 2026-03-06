import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import "../lib" as Lib
import "../config.js" as Config

Item {
  id: root
  property bool active: true
  required property QtObject theme
  property string profileName: Config.PROFILE_NAME
  property string profileImage: Config.PROFILE_IMG

  property bool expanded: false
  signal closeRequested()
  signal powerAction(string action, string label)

  // --- Theme Bindings ---
  readonly property bool _isDark: theme.isDarkMode
  readonly property color _textPrimary: theme.textPrimary
  readonly property color _outline: theme.outline
  readonly property color _subtleFill: theme.subtleFill
  readonly property color _subtleFillHover: theme.subtleFillHover
  readonly property color _accentRed: theme.accentRed
  
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
          width: 32; height: 32
          Layout.alignment: Qt.AlignVCenter
          Rectangle { id: pfpMask; anchors.fill: parent; radius: 8; visible: false }
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
          font.family: theme.textFont
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

            // Action Buttons Row
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 7

                // 1. Theme Toggle
                Rectangle {
                    id: themeBtn
                    width: 30; height: 30; radius: 12
                    color: themeTap.pressed ? root._subtleFillHover
                          : (themeHover.hovered ? root._subtleFillHover : root._subtleFill)
                    border.width: 1; border.color: root._outline
                    
                    scale: themeTap.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text { 
                        anchors.centerIn: parent
                        text: root._isDark ? "󰛨" : "󰽥"
                        font.family: theme.iconFont
                        font.pixelSize: 20
                        color: root._textPrimary 
                        topPadding: 1 
                    }
                    
                    HoverHandler { id: themeHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { 
                        id: themeTap
                        onTapped: { 
                           root.theme.toggle()
                           
                        } 
                    }
                }

                // 2. Snapshot
                Rectangle {
                    id: snapBtn
                    width: 30; height: 30; radius: 12
                    color: snapTap.pressed ? root._subtleFillHover
                          : (snapHover.hovered ? root._subtleFillHover : root._subtleFill)
                    border.width: 1; border.color: root._outline
                    scale: snapTap.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    Text { 
                        anchors.centerIn: parent
                        text: ""
                        font.family: theme.iconFont
                        font.pixelSize: 16
                        color: root._textPrimary
                        topPadding: 1 
                    }
                    HoverHandler { id: snapHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: snapTap; onTapped: { root.closeRequested(); snapTimer.restart() } }
                }

                // 3. Power
                Rectangle {
                    id: pwrBtn
                    width: 30; height: 30; radius: 12
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
                      
                      text: root.expanded ? "" : ""
                      font.family: theme.iconFont
                      font.pixelSize: 12       
                      color: (pwrHover.hovered || root.expanded || pwrTap.pressed)
                      ? (root._isDark ? "#e5e6c5" : "#e1e4bd")  
                      : root._accentRed       
                    }

                    HoverHandler { id: pwrHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: pwrTap
                        onTapped: root.expanded ? root._closePowerMenu() : root._openPowerMenu()
                    }
                }
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

              onStatusChanged: {
                  if (status === Loader.Ready && item) {
                      root.powerContainerHeight = item.implicitHeight
                      item.forceActiveFocus()
                      resyncTimer.restart()
                  }
              }
          }

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

}
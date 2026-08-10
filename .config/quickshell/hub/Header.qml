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
  property string profileImage: Qt.resolvedUrl("../profile.jpg").toString().replace("file://", "")

  property bool settingsOpen: false
  property bool batteryActive: false
  property bool monitorsOpen: false
  signal closeRequested()
  signal settingsRequested()
  signal batteryToggleRequested()
  signal monitorsRequested()

  // --- Theme Bindings ---
  readonly property bool _isDark: theme.isDarkMode
  readonly property color _textPrimary: theme.textPrimary
  readonly property color _outline: theme.outline
  readonly property color _subtleFill: theme.subtleFill
  readonly property color _subtleFillHover: theme.subtleFillHover
  readonly property color _accentRed: theme.accentRed

  implicitHeight: 52

  Timer {
    id: snapTimer
    interval: 320
    repeat: false
    onTriggered: Quickshell.execDetached(["bash", "-lc", Lib.Configuration.screenshotScript])
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

                // 0. Battery Stats
                Rectangle {
                    id: statsBtn
                    width: 30; height: 30; radius: 12
                    color: statsTap.pressed ? root._subtleFillHover
                          : (statsHover.hovered || root.batteryActive) ? root._subtleFillHover : root._subtleFill
                    border.width: 1
                    border.color: root.batteryActive ? theme.accent : root._outline
                    scale: statsTap.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on color  { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: theme.iconFont
                        font.pixelSize: 14
                        color: root.batteryActive ? theme.accent : root._textPrimary
                        topPadding: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    HoverHandler { id: statsHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: statsTap
                        onTapped: root.batteryToggleRequested()
                    }
                }

                // 1. Settings
                Rectangle {
                    id: settingsBtn
                    width: 30; height: 30; radius: 12
                    color: settingsTap.pressed ? root._subtleFillHover
                          : (settingsHover.hovered || root.settingsOpen) ? root._subtleFillHover : root._subtleFill
                    border.width: 1
                    border.color: root.settingsOpen ? theme.accent : root._outline
                    scale: settingsTap.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on color  { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: theme.iconFont
                        font.pixelSize: 16
                        color: root.settingsOpen ? theme.accent : root._textPrimary
                        topPadding: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    HoverHandler { id: settingsHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: settingsTap
                        onTapped: root.settingsRequested()
                    }
                }

                // 2. Displays
                Rectangle {
                    id: monBtn
                    width: 30; height: 30; radius: 12
                    color: monTap.pressed ? root._subtleFillHover
                          : (monHover.hovered || root.monitorsOpen) ? root._subtleFillHover : root._subtleFill
                    border.width: 1
                    border.color: root.monitorsOpen ? theme.accent : root._outline
                    scale: monTap.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on color  { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰍺"
                        font.family: theme.iconFont
                        font.pixelSize: 14
                        color: root.monitorsOpen ? theme.accent : root._textPrimary
                        topPadding: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    HoverHandler { id: monHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: monTap
                        onTapped: root.monitorsRequested()
                    }
                }

                // 3. Snapshot
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

            }
        }
      }

  }

}
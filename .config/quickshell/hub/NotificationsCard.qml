import QtQuick
import QtQuick.Layouts
import "../lib" as Lib

Lib.Card {
  id: root
  Layout.fillWidth: true
  property bool active: true

  // ---------- Color Mappings ----------
  readonly property color cFgMain: theme.textPrimary
  readonly property color cFgMuted: theme.textSecondary
  readonly property color cBgItem: theme.bgItem
  readonly property color cAccent: theme.accent

  readonly property color cSoftBtn: theme.subtleFill
  readonly property color cSoftBtnHover: theme.subtleFillHover

  readonly property color cItemHoverOverlay: theme.hoverSpotlight
  readonly property color cRipple: theme.hoverSpotlight
  readonly property color cIconBg: theme.subtleFill
  readonly property color cOvershoot: theme.hoverSpotlight

  readonly property color cAccentRed: theme.accentRed

  property bool compactMode: false
  property bool expanded: !compactMode
  onCompactModeChanged: { expanded = !compactMode; overrideCollapse = false }
  readonly property int notifCount: notifModel.count
  property bool overrideCollapse: false

  // --- DND ---
  property bool dndActive: false
  onDndActiveChanged: {
    if (dndActive) root.expanded = false
  }

  // ---------- Main Data ----------
  readonly property ListModel notifModel: Lib.Notifs.history

  function dismissOne(index, id) {
    Lib.Notifs.dismiss(id)
  }

  function triggerClearAll() {
    if (notifModel.count === 0) return
    wipeAnimation.start()
  }

  SequentialAnimation {
    id: wipeAnimation
    ParallelAnimation {
      NumberAnimation { target: list; property: "opacity"; to: 0; duration: 300; easing.type: Easing.OutExpo }
      NumberAnimation { target: list; property: "contentY"; to: list.contentY - 40; duration: 400; easing.type: Easing.OutExpo }
    }
    ScriptAction {
      script: {
        Lib.Notifs.clearAll()
      }
    }
    PropertyAction { target: list; property: "opacity"; value: 1 }
    PropertyAction { target: list; property: "contentY"; value: 0 }
  }

  // ---------- UI ----------
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 10

    // Header
    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Text {
        text: "Notifications"
        font.family: theme.textFont
        font.pixelSize: 13
        font.weight: 900
        color: root.cFgMain
        Layout.fillWidth: true
      }

      Rectangle {
        radius: 999
        color: root.cBgItem
        implicitHeight: 22
        implicitWidth: countText.implicitWidth + 18
        Layout.alignment: Qt.AlignVCenter

        Text {
          id: countText
          anchors.centerIn: parent
          text: String(notifModel.count)
          font.family: theme.textFont
          font.pixelSize: 11
          font.weight: 900
          color: root.cFgMain
        }
      }

      // Expand Button
      Rectangle {
        id: expandBtn
        visible: root.compactMode
        radius: 10
        implicitHeight: 26
        implicitWidth: 34
        color: root.cSoftBtn

        Rectangle {
          anchors.fill: parent; radius: parent.radius
          color: root.cSoftBtnHover
          opacity: expandArea.containsMouse ? 1 : 0
          visible: opacity > 0
          Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Text {
          anchors.centerIn: parent
          text: ""
          font.family: theme.iconFont
          font.pixelSize: 14
          color: root.cFgMain
          rotation: root.expanded ? 180 : 0
          // Springy rotation
          Behavior on rotation { Lib.SpringSnappy {} }
        }

        MouseArea {
          id: expandArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.expanded = !root.expanded
        }

        scale: expandArea.pressed ? 0.92 : 1.0
        // Springy click feedback
        Behavior on scale { Lib.SpringSnappy {} }
      }

      // Clear Button
      Rectangle {
        id: clearBtn
        visible: notifModel.count > 0
        radius: 10
        implicitHeight: 26
        implicitWidth: 56
        color: Qt.alpha(root.cAccentRed, 0.1)

        Rectangle {
          anchors.fill: parent; radius: parent.radius
          color: Qt.alpha(root.cAccentRed, 0.15)
          opacity: clearArea.containsMouse ? 1 : 0
          visible: opacity > 0
          Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        Text {
          anchors.centerIn: parent
          text: "Clear"
          font.family: theme.textFont
          font.pixelSize: 10
          font.weight: 700
          color: root.cAccentRed
        }

        MouseArea {
          id: clearArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.triggerClearAll()
        }

        scale: clearArea.pressed ? 0.94 : 1.0
        // Springy click feedback
        Behavior on scale { Lib.SpringSnappy {} }
      }
    }

    Text {
      visible: notifModel.count === 0 && (!root.compactMode || root.expanded)
      opacity: visible ? 1 : 0
      text: Lib.Notifs.active ? "No new notifications" : "Another notification daemon is running"
      font.family: theme.textFont
      font.pixelSize: 11
      font.italic: true
      color: root.cFgMuted
      horizontalAlignment: Text.AlignHCenter
      Layout.fillWidth: true
      topPadding: 6
      bottomPadding: 6
      Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    Item {
      id: listWrapper
      Layout.fillWidth: true
      clip: true

      property int itemH: 62
      property int spacing: 8
      property int compactMaxH: itemH * 3 + spacing * 2
      property int normalMaxH: 220

      property int viewHeight: ((!root.compactMode || root.expanded) && !root.overrideCollapse)
        ? Math.min(list.contentHeight, root.compactMode ? compactMaxH : normalMaxH)
        : 0

      Layout.preferredHeight: viewHeight
      Behavior on Layout.preferredHeight { Lib.SpringSmooth { epsilon: 0.25 } }
      height: Layout.preferredHeight

      ListView {
        id: list
        anchors.fill: parent
        model: notifModel
        spacing: listWrapper.spacing
        reuseItems: false
        boundsBehavior: Flickable.DragAndOvershootBounds

        property int itemH: listWrapper.itemH

        add: Transition {
          ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutSine }
            Lib.SpringSmooth { property: "scale"; from: 0.9; to: 1.0 }
          }
        }

        remove: Transition {
          ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: 250; easing.type: Easing.OutQuad }
            NumberAnimation { property: "scale"; to: 0.5; duration: 250; easing.type: Easing.InQuad }
          }
        }

        displaced: Transition {
          Lib.SpringSmooth { property: "y"; epsilon: 0.25 }
          Lib.SpringSmooth { property: "x"; epsilon: 0.25 }
        }

        delegate: NotifItem {
          width: list.width
          height: model.body ? listWrapper.itemH + 16 : listWrapper.itemH
          
          nId: model.nId
          app: model.app
          summary: model.summary
          body: model.body !== undefined ? model.body : ""
          theme: root.theme
          
          onClicked: root.dismissOne(index, model.nId)
        }
      }

      Rectangle {
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.9; height: Math.abs(list.verticalOvershoot) * 0.5
        radius: 12; color: root.cOvershoot
        visible: list.verticalOvershoot < -1
        opacity: Math.min(1.0, Math.abs(list.verticalOvershoot) / 60)
      }

      Rectangle {
        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.9; height: list.verticalOvershoot * 0.5
        radius: 20; color: root.cOvershoot
        visible: list.verticalOvershoot > 1
        opacity: Math.min(1.0, list.verticalOvershoot / 60)
      }
    }
  }
}
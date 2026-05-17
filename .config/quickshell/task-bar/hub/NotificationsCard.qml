import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../lib" as Lib

Lib.Card {
  id: root
  Layout.fillWidth: true
  property bool active: true

  // Theme
  property var engine: root.theme

  // ---------- Color Mappings ----------
  readonly property color cFgMain: engine.textPrimary
  readonly property color cFgMuted: engine.textSecondary
  readonly property color cBgItem: engine.bgItem
  readonly property color cAccent: engine.accent

  readonly property color cSoftBtn: engine.subtleFill
  readonly property color cSoftBtnHover: engine.subtleFillHover

  readonly property color cItemHoverOverlay: engine.hoverSpotlight
  readonly property color cRipple: engine.hoverSpotlight
  readonly property color cIconBg: engine.subtleFill
  readonly property color cOvershoot: engine.hoverSpotlight
  
  readonly property color cAccentRed: engine.accentRed

  property bool compactMode: false
  property bool expanded: !compactMode
  onCompactModeChanged: expanded = !compactMode

  // --- DND ---
  property bool dndActive: false
  onDndActiveChanged: {
    if (dndActive) root.expanded = false
  }

  // ---------- Main Data ----------
  ListModel { id: notifModel }
  property var dismissed: ({})
  property bool animationsEnabled: true

  function sh(cmd) { return ["bash","-lc", cmd] }
  function det(cmd) { Quickshell.execDetached(sh(cmd)) }

  property var pollCommand: sh("dunstctl history 2>/dev/null || true")

  property var pendingItems: null
  property bool hasPending: false

  Timer {
    id: applyPending
    interval: 180
    repeat: false
    running: root.active && root.visible
    onTriggered: {
      if (!hasPending) return
      if (list.moving || list.flicking) { restart(); return }
      hasPending = false
      root.applyItems(pendingItems || [])
    }
  }

  Process {
    id: proc
    stdout: StdioCollector {
      onStreamFinished: {
        if (!(root.active && root.visible)) return

        var raw = this.text ?? ""
        var items = root.parseDunstToItems(raw)

        if (list.moving || list.flicking) {
          pendingItems = items
          hasPending = true
          applyPending.restart()
        } else {
          root.applyItems(items)
        }
      }
    }
  }

  Timer {
    interval: 1800
    repeat: true
    running: root.active && root.visible
    triggeredOnStart: true
    onTriggered: proc.exec(root.pollCommand)
  }

  function parseDunstToItems(raw) {
    if (!raw || raw.trim() === "") return []
    var incoming = []
    try {
      var parsed = JSON.parse(raw)
      var notifs = (parsed.data && parsed.data.length > 0) ? parsed.data[0] : []
      
      for (var i = 0; i < notifs.length && incoming.length < 50; i++) {
        var n = notifs[i]
        var id = (n.id && n.id.data !== undefined) ? Number(n.id.data) : 0
        var app = (n.appname && n.appname.data) ? String(n.appname.data) : "SYSTEM"
        var summary = (n.summary && n.summary.data) ? String(n.summary.data) : "Notification"
        var body = (n.body && n.body.data) ? String(n.body.data) : ""

        if (!root.dismissed[id]) {
          incoming.push({ nId: id, app: app, summary: summary, body: body })
        }
      }
    } catch(e) {
      console.log("Dunst history parse error: " + e)
    }
    return incoming
  }

  function modelEquals(items) {
    if (notifModel.count !== items.length) return false
    for (var i = 0; i < items.length; i++) {
      var m = notifModel.get(i)
      var it = items[i]
      if (m.nId !== it.nId) return false
      if (m.app !== it.app) return false
      if (m.summary !== it.summary) return false
      if (m.body !== it.body) return false
    }
    return true
  }

  function applyItems(items) {
    if (root.modelEquals(items)) return
    root.animationsEnabled = false
    notifModel.clear()
    for (var i = 0; i < items.length; i++) notifModel.append(items[i])
    animReenable.restart()
  }

  Timer { id: animReenable; interval: 0; onTriggered: root.animationsEnabled = true }

  function dismissOne(index, id) {
    root.dismissed[id] = true
    notifModel.remove(index)
    det("dunstctl close " + id + " >/dev/null 2>&1; dunstctl history-rm " + id + " >/dev/null 2>&1 || true")
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
        for (var i = notifModel.count - 1; i >= 0; i--) {
          root.dismissed[notifModel.get(i).nId] = true
          notifModel.remove(i)
        }
        det("dunstctl close-all >/dev/null 2>&1; dunstctl history-clear >/dev/null 2>&1 || true")
      }
    }
    PropertyAction { target: list; property: "opacity"; value: 1 }
    PropertyAction { target: list; property: "contentY"; value: 0 }
  }

  // ---------- UI ----------
  ColumnLayout {
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: 10

    // Header
    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Text {
        text: "Notifications"
        font.family: engine.textFont
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
          font.family: engine.textFont
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
          font.family: engine.iconFont
          font.pixelSize: 14
          color: root.cFgMain
          rotation: root.expanded ? 180 : 0
          // Springy rotation
          Behavior on rotation { SpringAnimation { spring: 3; damping: 0.45; mass: 0.5 } }
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
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.4; mass: 0.5; epsilon: 0.005 } }
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
          font.family: engine.textFont
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
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.4; mass: 0.5; epsilon: 0.005 } }
      }
    }

    Text {
      visible: notifModel.count === 0 && (!root.compactMode || root.expanded)
      opacity: visible ? 1 : 0
      text: "No new notifications"
      font.family: engine.textFont
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

      property int viewHeight: (!root.compactMode || root.expanded)
        ? Math.min(list.contentHeight, root.compactMode ? compactMaxH : normalMaxH)
        : 0

      Layout.preferredHeight: viewHeight
      Behavior on Layout.preferredHeight { NumberAnimation { duration: 450; easing.type: Easing.OutExpo } }
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
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: root.animationsEnabled ? 300 : 0; easing.type: Easing.OutSine }
            NumberAnimation { 
              property: "scale"
              from: 0.9; to: 1.0
              duration: root.animationsEnabled ? 400 : 0
              easing.type: Easing.OutBack
              easing.overshoot: 0.8 
            }
          }
        }

        remove: Transition {
          ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: 250; easing.type: Easing.OutQuad }
            NumberAnimation { property: "scale"; to: 0.5; duration: 250; easing.type: Easing.InQuad }
          }
        }

        displaced: Transition {
          SpringAnimation { property: "y"; spring: 4; damping: 0.6; epsilon: 0.1 }
          SpringAnimation { property: "x"; spring: 4; damping: 0.6; epsilon: 0.1 }
        }

        delegate: NotifItem {
          width: list.width
          height: model.body ? listWrapper.itemH + 16 : listWrapper.itemH
          
          nId: model.nId
          app: model.app
          summary: model.summary
          body: model.body !== undefined ? model.body : ""
          theme: root.engine
          
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
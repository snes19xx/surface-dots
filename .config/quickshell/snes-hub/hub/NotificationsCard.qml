import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../lib" as Lib
import "../theme.js" as Theme

Lib.Card {
  id: root
  Layout.fillWidth: true
  property bool active: true

  // ---------- Theme ----------
  readonly property bool hasTheme: root.theme !== null
  readonly property bool isDarkMode: (!hasTheme || (root.theme.isDarkMode === undefined)) ? true : root.theme.isDarkMode

  readonly property color cFgMain: isDarkMode ? Theme.fgMain : root.theme.textPrimary
  readonly property color cFgMuted: isDarkMode ? Theme.fgMuted : root.theme.textSecondary
  readonly property color cBgItem: isDarkMode ? Theme.bgItem : root.theme.bgItem
  readonly property color cAccent: isDarkMode ? Theme.accent : root.theme.accent

  readonly property color cSoftBtn: (!hasTheme || isDarkMode) ? Qt.rgba(1,1,1,0.04) : root.theme.subtleFill
  readonly property color cSoftBtnHover: (!hasTheme || isDarkMode) ? Qt.rgba(1,1,1,0.08) : root.theme.subtleFillHover

  readonly property color cItemHoverOverlay: (!hasTheme || isDarkMode) ? Qt.rgba(1, 1, 1, 0.08) : root.theme.hoverSpotlight
  readonly property color cRipple: (!hasTheme || isDarkMode) ? Qt.rgba(1, 1, 1, 0.15) : root.theme.hoverSpotlight
  readonly property color cIconBg: (!hasTheme || isDarkMode) ? Qt.rgba(1,1,1,0.05) : root.theme.subtleFill
  readonly property color cOvershoot: (!hasTheme || isDarkMode) ? Qt.rgba(1,1,1,0.1) : root.theme.hoverSpotlight

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

  property var pollCommand: sh(
    "makoctl history 2>/dev/null | " +
    "awk 'BEGIN{c=0} /^Notification [0-9]+:/{c++; if(c>60) exit} {print}' || true"
  )

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
        var items = root.parseMakoToItems(raw)

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

  function parseMakoToItems(raw) {
    var lines = String(raw ?? "").split("\n")
    var incoming = []
    for (var i = 0; i < lines.length && incoming.length < 50; i++) {
      var line = lines[i].trim()
      var m = line.match(/^Notification\s+(\d+):\s*(.+)$/)
      if (!m) continue
      var id = Number(m[1])
      var summary = m[2] || "Notification"
      var app = "SYSTEM"

      for (var j = i + 1; j < Math.min(i + 12, lines.length); j++) {
        var l2 = lines[j].trim()
        var am = l2.match(/^App name:\s*(.+)$/)
        if (am) { app = am[1]; break }
        if (l2.startsWith("Notification ")) break
      }

      if (!root.dismissed[id]) incoming.push({ nId: id, app: app, summary: summary })
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
    det("makoctl dismiss -n " + id + " >/dev/null 2>&1 || true")
  }

  function triggerClearAll() {
    if (notifModel.count === 0) return
    wipeAnimation.start()
  }

  SequentialAnimation {
    id: wipeAnimation
    ParallelAnimation {
      NumberAnimation { target: list; property: "opacity"; to: 0; duration: 300; easing.type: Easing.InQuart }
      NumberAnimation { target: list; property: "contentY"; to: list.contentY - 40; duration: 300; easing.type: Easing.InQuart }
    }
    ScriptAction {
      script: {
        for (var i = notifModel.count - 1; i >= 0; i--) {
          root.dismissed[notifModel.get(i).nId] = true
          notifModel.remove(i)
        }
        det("makoctl dismiss -a >/dev/null 2>&1 || true")
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
        font.family: Theme.textFont
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
          font.family: Theme.textFont
          font.pixelSize: 11
          font.weight: 900
          color: root.cFgMain
        }
      }

      // Expand Button
      Rectangle {
        id: expandBtn
        visible: root.compactMode
        radius: 999
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
          font.family: Theme.iconFont
          font.pixelSize: 14
          color: root.cFgMain
          rotation: root.expanded ? 180 : 0
          Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        MouseArea {
          id: expandArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.expanded = !root.expanded
        }

        scale: expandArea.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuint } }
      }

      // Clear Button
      Rectangle {
        id: clearBtn
        visible: notifModel.count > 0
        radius: 12
        implicitHeight: 26
        implicitWidth: 56
        color: (!hasTheme || isDarkMode) ? Qt.rgba(0.9,0.5,0.5,0.10): Qt.rgba(0.5,0.1,0.1,0.10)


        Rectangle {
          anchors.fill: parent; radius: parent.radius
          color: Qt.rgba(0.9,0.5,0.5,0.15)
          opacity: clearArea.containsMouse ? 1 : 0
          visible: opacity > 0
          Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        }

        Text {
          anchors.centerIn: parent
          text: "Clear"
          font.family: Theme.textFont
          font.pixelSize: 10
          font.weight: 700
          color: (!hasTheme || isDarkMode) ? Theme.accentRed : root.theme.accentRed
        }

        MouseArea {
          id: clearArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.triggerClearAll()
        }

        scale: clearArea.pressed ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuint } }
      }
    }

    Text {
      visible: notifModel.count === 0 && (!root.compactMode || root.expanded)
      opacity: visible ? 1 : 0
      text: "No new notifications"
      font.family: Theme.textFont
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
      Behavior on Layout.preferredHeight { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
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
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: root.animationsEnabled ? 250 : 0; easing.type: Easing.OutQuad }
            NumberAnimation { property: "scale"; from: 0.8; to: 1.0; duration: root.animationsEnabled ? 250 : 0; easing.type: Easing.OutBack }
          }
        }

        remove: Transition {
          ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: 250; easing.type: Easing.OutQuad }
            NumberAnimation { property: "scale"; to: 0.5; duration: 250; easing.type: Easing.InQuad }
          }
        }

        displaced: Transition {
          NumberAnimation { properties: "x,y"; duration: 300; easing.type: Easing.OutQuint }
        }

        delegate: Item {
          id: itemContainer
          width: list.width
          height: list.itemH

          function dismiss() { root.dismissOne(index, model.nId) }

          Rectangle {
            id: bg
            anchors.fill: parent
            radius: 14
            color: root.cBgItem
            scale: pressArea.pressed ? 0.98 : 1.0
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

            Rectangle {
              anchors.fill: parent; radius: 14
              color: root.cItemHoverOverlay
              opacity: hoverArea.containsMouse ? 1 : 0
              visible: opacity > 0
              Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            }

            Lib.ClickRipple {
              id: clickRipple
              anchors.fill: parent
              color: root.cRipple
            }

            RowLayout {
              anchors.fill: parent; anchors.margins: 12; spacing: 12

              Rectangle {
                width: 32; height: 32; radius: 16
                color: root.cIconBg
                Layout.alignment: Qt.AlignVCenter
                Text { anchors.centerIn: parent; text: "󰋽"; font.family: Theme.iconFont; font.pixelSize: 14; font.weight: 900; color: root.cAccent }
              }

              ColumnLayout {
                Layout.fillWidth: true; spacing: 3; Layout.alignment: Qt.AlignVCenter
                Text { text: String(model.app).toUpperCase(); font.family: Theme.textFont; font.pixelSize: 9; font.weight: 800; color: root.cFgMuted; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: model.summary; font.family: Theme.textFont; font.pixelSize: 12; font.weight: 600; color: root.cFgMain; elide: Text.ElideRight; Layout.fillWidth: true }
              }
            }

            MouseArea { id: hoverArea; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
            MouseArea {
              id: pressArea
              anchors.fill: parent
              hoverEnabled: false
              onPressed: (mouse) => clickRipple.burst(mouse.x, mouse.y)
              onClicked: dismissTimer.start()
            }
          }

          Timer { id: dismissTimer; interval: 200; repeat: false; onTriggered: itemContainer.dismiss() }
        }
      }

      Rectangle {
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.9; height: Math.abs(list.verticalOvershoot) * 0.5
        radius: 20; color: root.cOvershoot
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
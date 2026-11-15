import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: win

    required property var theme

    readonly property int toastWidth: 380
    // window clips the shadows otherwise
    readonly property int shadowPad: 24

    // pinned while toasts are up
    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    screen: targetScreen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "snes-notifs"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.top: true
    anchors.right: true
    margins.top: 4
    margins.right: 0

    exclusiveZone: 0
    implicitWidth: toastWidth + shadowPad * 2
    implicitHeight: Math.max(1, list.contentHeight + shadowPad * 2)
    color: "transparent"
    visible: toastModel.count > 0 || lingerTimer.running

    mask: Region { item: list }

    function pickScreen() {
        var mon = Hyprland.focusedMonitor
        var name = mon ? mon.name : ""
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) { targetScreen = Quickshell.screens[i]; return }
        }
        if (Quickshell.screens.length > 0) targetScreen = Quickshell.screens[0]
    }

    function reconcile() {
        var ids = Notifs.popups.map(n => n.id)
        for (var i = toastModel.count - 1; i >= 0; i--) {
            if (ids.indexOf(toastModel.get(i).nid) < 0) toastModel.remove(i)
        }
        if (toastModel.count === 0 && ids.length > 0) pickScreen()
        for (var k = 0; k < ids.length; k++) {
            if (k >= toastModel.count || toastModel.get(k).nid !== ids[k])
                toastModel.insert(k, { nid: ids[k] })
        }
    }

    ListModel {
        id: toastModel
        onCountChanged: if (count === 0) lingerTimer.restart()
    }

    // covers the last exit animation
    Timer { id: lingerTimer; interval: 600 }

    Connections {
        target: Notifs
        function onPopupsChanged() { win.reconcile() }
    }

    ListView {
        id: list
        x: win.shadowPad
        y: win.shadowPad
        width: win.toastWidth
        height: contentHeight
        interactive: false
        spacing: 10
        model: toastModel

        displaced: Transition {
            NumberAnimation { property: "y"; duration: 260; easing.type: Easing.OutCubic }
        }

        delegate: NotifToast {
            width: list.width
            theme: win.theme
            onCloseRequested: Notifs.dismissPopup(nid)
            onExpired: Notifs.expirePopup(nid)
            ListView.onRemove: playExit()
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: win

    required property var theme

    readonly property int toastWidth: Math.round(380 * PopupStyle.toastScale)
    readonly property bool cassini: Configuration.popupStyle !== "rounded"
    // window clips the shadows otherwise
    readonly property int shadowPad: cassini ? PopupStyle.shadowPad : 44

    // pinned while toasts are up
    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    screen: targetScreen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "snes-notifs"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.top: true
    anchors.right: true
    // shadow padding hangs offscreen
    margins.top: 16 - shadowPad
    margins.right: 24 - shadowPad

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

    // New app cards go last
    function reconcile() {
        var stacks = Notifs.stacks
        var byKey = {}
        for (var s = 0; s < stacks.length; s++) byKey[stacks[s].key] = stacks[s]
        for (var i = toastModel.count - 1; i >= 0; i--) {
            var row = toastModel.get(i)
            var want = byKey[row.key]
            if (!want) { toastModel.remove(i); continue }
            if (row.nid !== want.nid) toastModel.setProperty(i, "nid", want.nid)
            if (row.more !== want.more) toastModel.setProperty(i, "more", want.more)
            delete byKey[row.key]
        }
        if (toastModel.count === 0 && stacks.length > 0) pickScreen()
        for (var k = stacks.length - 1; k >= 0; k--) {
            if (byKey[stacks[k].key]) toastModel.append({ key: stacks[k].key, nid: stacks[k].nid, more: stacks[k].more })
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
            SpringAnimation {
                property: "y"
                spring: Motion.smooth.spring
                damping: Motion.smooth.damping
                mass: Motion.smooth.mass
                epsilon: 0.25
            }
        }

        // switching rebuilds visible toasts
        delegate: win.cassini ? cassiniToast : roundedToast
    }

    Component {
        id: cassiniToast
        NotifToastCassini {
            width: list.width
            theme: win.theme
            onCloseRequested: Notifs.dismissStack(nid)
            onExpired: Notifs.expireStack(nid)
            ListView.onRemove: playExit()
        }
    }
    Component {
        id: roundedToast
        NotifToastRounded {
            width: list.width
            theme: win.theme
            onCloseRequested: Notifs.dismissStack(nid)
            onExpired: Notifs.expireStack(nid)
            ListView.onRemove: playExit()
        }
    }
}

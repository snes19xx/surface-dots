import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects
import "../lib" as Lib
import "../config.js" as Config
// Lib.Configuration singleton provides persistent settings

PanelWindow {
    id: win
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }

        // Hides window borders when the hub is open 
        function setBordersHidden(hidden) {
            Quickshell.execDetached(["hyprctl", "keyword", "general:border_size", hidden ? "0" : "1"])
        }

        // Single entry point for outside callers, so the other panels get cleared
        function showMonitors() {
            win.wallpaperMode = false
            win.settingsPanelOpen = false
            win.monitorsMode = true
        }

        function closeAll() {
            win.settingsPanelOpen = false
            win.wallpaperMode = false
            win.monitorsMode = false
            exitAnim.start()
        }

        onVisibleChanged: {
            setBordersHidden(visible)

            if (visible) {
                root.forceActiveFocus()

                // Instantly move panel off-screen before first render
                panelTranslate.y = win.topAnchored ? -panel.height : panel.height
                panel.opacity  = 0
                panelScale.xScale = 0.97
                panelScale.yScale = 0.97
                layout.opacity = 0

                enterAnim.start()
            } else {
                win.batteryCardActive = false
                win.settingsPanelOpen = false
                win.wallpaperMode = false
                win.monitorsMode = false
                }
        }
    
    property int barStrip: 2
    property bool isDarkMode: theme.isDarkMode

    Lib.ThemeEngine {
        id: theme
    }
    
// ---------------------------------------------------------------------------------------------------------------------------
    margins { top: barStrip }
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: visible
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "snes-hub"

    property string profileName: Config.PROFILE_NAME
    readonly property string _bundledProfile:
        Qt.resolvedUrl("../profile.jpg").toString().replace("file://", "")
    property string profileImage: Lib.Configuration.profileImageOverride !== ""
        ? Lib.Configuration.profileImageOverride
        : (Config.PROFILE_IMG !== "" ? Config.PROFILE_IMG : win._bundledProfile)
    property bool batteryCardActive: false
    property bool settingsPanelOpen: false
    property bool wallpaperMode: false
    property bool _wpEverOpened: false
    // Drops the wallpaper panel's per-thumbnail blur/mask layers while the panel
    // animates in/out
    property bool _wpTransitioning: false
    Timer { id: wpTransTimer; interval: 300; onTriggered: win._wpTransitioning = false }
    onWallpaperModeChanged: {
        if (win.wallpaperMode) win._wpEverOpened = true
        win._wpTransitioning = true
        wpTransTimer.restart()
    }
    property bool _settingsEverOpened: false
    onSettingsPanelOpenChanged: if (win.settingsPanelOpen) win._settingsEverOpened = true
    property bool monitorsMode: false
    property bool _monEverOpened: false
    onMonitorsModeChanged: if (win.monitorsMode) win._monEverOpened = true
    property QtObject hubTheme: theme
    // Top style drops the panel from under the bar; task style rises from the dock
    readonly property bool topAnchored: Lib.Configuration.barStyle === "top"
    property int topGap: 8
    property int rightGap: 10
    readonly property string contentMode: win.wallpaperMode ? "wallpaper"
        : win.settingsPanelOpen ? "settings"
        : win.monitorsMode ? "monitors" : "cards"
    property int panelW: win.contentMode === "wallpaper" ? 540
        : win.contentMode === "settings" ? 620
        : win.contentMode === "monitors" ? 560
        : win.topAnchored ? 320 : 520
// ---------------------------------------------------------------------------------------------------------------------------
        Item {
            id: root
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: closeAll()
            Keys.onPressed: (event) => {
                // Press 'S' to toggle settings panel
                if (event.key === Qt.Key_S) {
                    if (win.wallpaperMode) {
                        win.wallpaperMode = false
                    } else {
                        win.settingsPanelOpen = !win.settingsPanelOpen
                        if (win.settingsPanelOpen) win.monitorsMode = false
                    }
                    event.accepted = true
                }
                // Press 'W' to toggle wallpaper panel
                else if (event.key === Qt.Key_W) {
                    win.wallpaperMode = !win.wallpaperMode
                    if (win.wallpaperMode) {
                        win.settingsPanelOpen = false
                        win.monitorsMode = false
                    }
                    event.accepted = true
                }
                // Press 'M' to toggle the displays panel
                else if (event.key === Qt.Key_M) {
                    win.monitorsMode = !win.monitorsMode
                    if (win.monitorsMode) {
                        win.settingsPanelOpen = false
                        win.wallpaperMode = false
                    }
                    event.accepted = true
                }
                // Press 'B' to toggle battery/system stats card
                else if (event.key === Qt.Key_B) {
                    win.batteryCardActive = !win.batteryCardActive
                    event.accepted = true
                }
                // Press 'L' to switch to light theme
                else if (event.key === Qt.Key_L) {
                    if (theme.isDarkMode) theme.toggle()
                    event.accepted = true
                }
                // Press 'D' to switch to dark theme
                else if (event.key === Qt.Key_D) {
                    if (!theme.isDarkMode) theme.toggle()
                    event.accepted = true
                }
                // Press 'N' to expand/collapse notifications
                else if (event.key === Qt.Key_N) {
                    var nc = cardsColumn.item ? cardsColumn.item.notifs : null
                    // The top-style card has no manual collapse override
                    if (nc && nc.overrideCollapse !== undefined) {
                        var isCollapsed = nc.overrideCollapse || (nc.compactMode && !nc.expanded)
                        if (isCollapsed) {
                            nc.overrideCollapse = false
                            nc.expanded = true
                        } else if (nc.notifCount > 1) {
                            nc.overrideCollapse = true
                        }
                    } else if (nc) {
                        nc.expanded = !nc.expanded
                    }
                    event.accepted = true
                }
            }

        // click outside closes
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            preventStealing: true
            onPressed: closeAll()
        }

        //  SHADOW EFFECT
        //  The container starts at the panel's top edge and clips, so the blur
        //  only escapes on the left, right and bottom.
        Item {
            id: panelShadow
            z: -1

            property int spread: 30

            width: panel.width + spread * 2
            height: panel.height + spread
            clip: true
            visible: panel.visible && panel.opacity > 0
            opacity: panel.opacity

            anchors.right: parent.right
            anchors.rightMargin: win.rightGap - spread
            y: panel.y

            // mirror the panel's enter/exit transforms so the shadow moves with it
            transform: [
                Scale {
                    xScale: panelScale.xScale
                    yScale: panelScale.yScale
                    origin.x: panelShadow.width / 2
                    origin.y: win.topAnchored ? 0 : panelShadow.height - panelShadow.spread
                },
                Translate { y: panelTranslate.y }
            ]

            Item {
                x: panelShadow.spread
                y: 0
                width: panel.width
                height: panel.height

                layer.enabled: true
                layer.effect: DropShadow {
                    transparentBorder: true
                    radius: 22
                    samples: 27
                    color: "#70000000"
                    horizontalOffset: 0
                    verticalOffset: 4
                }

                Rectangle {
                    anchors.fill: parent
                    radius: panel.radius
                    color: "black"
                }
            }
        }

        Rectangle {
            id: panel
            width: win.panelW
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            readonly property int maxH: Math.round(panel.parent.height - 20)
            height: Math.min(Math.ceil(layout.implicitHeight + 24), maxH)
            radius: win.topAnchored ? 24 : 12
            color: theme.bgMain
            border.width: win.topAnchored ? 1 : 0
            border.color: theme.border
            layer.enabled: enterAnim.running || exitAnim.running

            // ANIMATION TRANSFORMS
            transform: [
                Scale {
                    id: panelScale
                    xScale: 1; yScale: 1
                    // Scale origin: bottom-centre -- panel grows up on enter, sinks on exit
                    origin.x: panel.width / 2
                    origin.y: win.topAnchored ? 0 : panel.height
                },
                Translate { id: panelTranslate }
            ]

            // -- Enter: slide up + scale to full + panel fade, then content fades in--
            ParallelAnimation {
                id: enterAnim

                // Panel slides up from below
                NumberAnimation {
                    target: panelTranslate; property: "y"
                    from: win.topAnchored ? -panel.height : panel.height; to: 0
                    duration: 320; easing.type: Easing.OutCubic
                }
                // Panel fades in
                NumberAnimation {
                    target: panel; property: "opacity"
                    from: 0; to: 1
                    duration: 280; easing.type: Easing.OutCubic
                }
                // Panel scales up from 0.97 --> 1.0
                NumberAnimation {
                    target: panelScale; property: "xScale"
                    from: 0.97; to: 1.0
                    duration: 320; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: panelScale; property: "yScale"
                    from: 0.97; to: 1.0
                    duration: 320; easing.type: Easing.OutCubic
                }
                // Content fades in after a short delay so it shows inside the panel
                SequentialAnimation {
                    PauseAnimation { duration: 70 }
                    NumberAnimation {
                        target: layout; property: "opacity"
                        from: 0; to: 1
                        duration: 230; easing.type: Easing.OutCubic
                    }
                }
            }

            // -- Exit: content disappears first, then panel sinks and fades --
            ParallelAnimation {
                id: exitAnim
                onFinished: win.visible = false

                // Content fades out quickly -- leaves a momentary empty shell
                NumberAnimation {
                    target: layout; property: "opacity"
                    from: 1; to: 0
                    duration: 140; easing.type: Easing.OutCubic
                }
                // Panel nudges down slightly
                NumberAnimation {
                    target: panelTranslate; property: "y"
                    from: 0; to: win.topAnchored ? -20 : 20
                    duration: 260; easing.type: Easing.OutCubic
                }
                // Panel fades out
                NumberAnimation {
                    target: panel; property: "opacity"
                    from: 1; to: 0
                    duration: 250; easing.type: Easing.OutCubic
                }
                // Panel shrinks slightly as it disappears
                NumberAnimation {
                    target: panelScale; property: "xScale"
                    from: 1.0; to: 0.97
                    duration: 260; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: panelScale; property: "yScale"
                    from: 1.0; to: 0.97
                    duration: 260; easing.type: Easing.OutCubic
                }
            }

            anchors.right: parent.right
            anchors.rightMargin: win.rightGap
            y: win.topAnchored ? win.topGap
                                : Math.max(0, parent.height - panel.height - 10)

            // block clicks inside panel from closing
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                preventStealing: true
                onPressed: (mouse) => mouse.accepted = true
            }

            // -- CARDS ----------------------------------------------------------------------------------------------------

            ColumnLayout {
                id: layout
                anchors.fill: parent
                anchors.margins: 12
                spacing: theme.gapCard

            // HEADER (USER, SETTINGS, SS, POWER)
                Header {
                    id: header
                    theme: theme
                    Layout.fillWidth: true
                    profileName: win.profileName
                    profileImage: win.profileImage
                    active: win.visible
                    settingsOpen: win.settingsPanelOpen
                    batteryActive: win.batteryCardActive
                    monitorsOpen: win.monitorsMode
                    onCloseRequested: closeAll()
                    onBatteryToggleRequested: win.batteryCardActive = !win.batteryCardActive
                    onMonitorsRequested: {
                        win.monitorsMode = !win.monitorsMode
                        if (win.monitorsMode) {
                            win.settingsPanelOpen = false
                            win.wallpaperMode = false
                        }
                    }
                    onSettingsRequested: {
                        if (win.wallpaperMode) {
                            win.wallpaperMode = false
                        } else {
                            win.settingsPanelOpen = !win.settingsPanelOpen
                            if (win.settingsPanelOpen) win.monitorsMode = false
                        }
                    }
                }

            // CONTENT AREA (cards / settings / wallpaper)
                Item {
                    id: contentArea
                    Layout.fillWidth: true
                    readonly property real maxContentH: Math.max(160, panel.maxH - header.height - layout.spacing - 24)
                    implicitHeight: win.contentMode === "wallpaper"
                        ? (wallpaperLoader.height > 0 ? wallpaperLoader.height : cardsColumn.implicitHeight)
                        : win.contentMode === "settings"
                            ? (settingsLoader.height > 0 ? settingsLoader.height : cardsColumn.implicitHeight)
                            : win.contentMode === "monitors"
                                ? (monitorsLoader.height > 0 ? monitorsLoader.height : cardsColumn.implicitHeight)
                                : cardsColumn.implicitHeight
                    Behavior on implicitHeight { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    // Task style keeps its own two-column card set; top style uses
                    // the original top-bar cards under hub/top, which are a different
                    // design rather than a reflow of these.
                    Loader {
                        id: cardsColumn
                        width: parent.width
                        active: Lib.Configuration.ready
                        sourceComponent: win.topAnchored ? topCards : taskCards
                        opacity: win.contentMode === "cards" ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        // Stay rendered instead of visible:false
                        enabled: opacity > 0.01

                        function collapseNotifications() {
                            if (item && item.notifs) item.notifs.overrideCollapse = true
                        }
                    }

                    Component {
                        id: taskCards
                        TaskCards {
                            width: cardsColumn.width
                            theme: win.hubTheme
                            hubVisible: win.visible
                            batteryActive: win.batteryCardActive
                            onCloseRequested: closeAll()
                            onBatteryToggleRequested: win.batteryCardActive = !win.batteryCardActive
                            onBatteryDismissed: win.batteryCardActive = false
                        }
                    }

                    Component {
                        id: topCards
                        TopCards {
                            width: cardsColumn.width
                            theme: win.hubTheme
                            hubVisible: win.visible
                            batteryActive: win.batteryCardActive
                            onCloseRequested: closeAll()
                            onBatteryToggleRequested: win.batteryCardActive = !win.batteryCardActive
                            onBatteryDismissed: win.batteryCardActive = false
                        }
                    }

                    // SETTINGS LOADER
                    Loader {
                        id: settingsLoader
                        active: win._settingsEverOpened
                        width: parent.width
                        height: Math.min(item ? item.implicitHeight : 0, contentArea.maxContentH)
                        opacity: win.contentMode === "settings" ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        visible: opacity > 0.01
                        sourceComponent: settingsPanelComponent
                    }

                    Component {
                        id: settingsPanelComponent
                        SettingsPanel {
                            theme: win.hubTheme
                            width: settingsLoader.width
                            height: settingsLoader.height
                            profileImagePath: win.profileImage
                        }
                    }

                    Connections {
                        target: settingsLoader.item
                        function onWallpaperRequested() {
                            win.monitorsMode = false
                            win.wallpaperMode = true
                        }
                        function onToastRequested(msg) {
                            panel.triggerToast(msg)
                        }
                    }

                    // WALLPAPER LOADER — stays alive after first open so thumbnails stay cached
                    Loader {
                        id: wallpaperLoader
                        active: win._wpEverOpened
                        width: parent.width
                        opacity: win.contentMode === "wallpaper" ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        sourceComponent: wallpaperPanelComponent
                    }

                    Component {
                        id: wallpaperPanelComponent
                        WallpaperPanel {
                            theme: win.hubTheme
                            width: wallpaperLoader.width
                            live: !win._wpTransitioning
                            onCloseRequested: win.wallpaperMode = false
                        }
                    }

                    // DISPLAYS LOADER
                    Loader {
                        id: monitorsLoader
                        active: win._monEverOpened
                        width: parent.width
                        height: Math.min(item ? item.implicitHeight : 0, contentArea.maxContentH)
                        opacity: win.contentMode === "monitors" ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        sourceComponent: monitorsPanelComponent
                    }

                    Component {
                        id: monitorsPanelComponent
                        MonitorsPanel {
                            theme: win.hubTheme
                            width: monitorsLoader.width
                            onCloseRequested: win.monitorsMode = false
                            onToastRequested: (msg) => panel.triggerToast(msg)
                        }
                    }
                } // close content area Item
            } // close layout ColumnLayout

            // Panel-level toast
            property bool   _showToast: false
            property string _toastText: ""
            function triggerToast(msg) { _toastText = msg; _showToast = true; panelToastTimer.restart() }
            Timer { id: panelToastTimer; interval: 3500; onTriggered: panel._showToast = false }

            Rectangle {
                z: 99
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 10
                height: 26; radius: 7
                width: panelToastLabel.implicitWidth + 22
                color: Qt.rgba(theme.bgCard.r, theme.bgCard.g, theme.bgCard.b, 0.94)
                border.width: 1; border.color: theme.accent
                opacity: panel._showToast ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Text {
                    id: panelToastLabel
                    anchors.centerIn: parent
                    text: panel._toastText
                    color: theme.accent
                    font.family: "DM Mono"; font.pixelSize: 11
                }
            }
        } // close panel Rectangle
    } // close root Item
} // close PanelWindow

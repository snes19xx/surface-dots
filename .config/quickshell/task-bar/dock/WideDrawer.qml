import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import "../lib" as Lib

// App launcher and shader selector drawer.
// Completely replaces my Rofi setup.
PanelWindow {
    id: drawerWin

    // ---------- Grid item background alphas ----------
    readonly property real tileAlphaDark: 0.6        // dark mode, not hovered
    readonly property real tileAlphaDarkHover: 1.0    // dark mode, hovered
    readonly property real tileAlphaLight: 0.6        // light mode, not hovered
    readonly property real tileAlphaLightHover: 1.0   // light mode, hovered

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: shell.activeHeight > 1

    WlrLayershell.exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // ThemeEngine instance from shell.qml.
    required property var theme
    property bool isOpen: false
    property bool hasLoadedApps: false
    property string currentTab: "apps"           // "apps" | "shaders"
    property var contextApp: ({})

    // Storage paths for the pinned apps list. 
    readonly property string favStorePath: Quickshell.env("HOME") + "/.config/quickshell/.cache/favorites.json"
    readonly property string favLegacyPath: Quickshell.env("HOME") + "/.cache/quickshell/favorites.json"

    // Runtime list of favorite filenames loaded from json cache
    property var pinnedFiles: []

    // Grid geometry  
    readonly property int cols: 6
    readonly property int cellH: 90

    function toggle() { isOpen ? close() : open() }

    function open() {
        isOpen = true
        searchField.text = ""
        currentTab = "apps"
        loadFavorites()
        if (!hasLoadedApps) { hasLoadedApps = true; loadApps() }
        Qt.callLater(() => searchField.forceActiveFocus())
    }

    function close() {
        isOpen = false
        contextMenu.visible = false
        searchField.focus = false
    }

    // ---------- JSON Persistence ----------
    readonly property var favDefaults: ["firefox.desktop", "code.desktop", "photogimp.desktop", "kitty.desktop"]
    function loadFavorites() { favLoader.running = false; favLoader.running = true }

    // Reads the store, falling back to the old cache path
    Process {
        id: favLoader
        running: false
        command: ["bash", "-c",
            "cat '" + favStorePath + "' 2>/dev/null; "
            + "[ -s '" + favStorePath + "' ] || cat '" + favLegacyPath + "' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = String(text || "").trim()
                if (out.length > 0) {
                    try {
                        var parsed = JSON.parse(out)
                        if (Array.isArray(parsed)) {
                            drawerWin.pinnedFiles = parsed
                            drawerWin.saveFavorites()   // re-home a migrated list into the store
                            drawerWin.rebuild()
                            return
                        }
                    } catch(e) {
                        console.error("Failed to parse favorites.json:", e)
                    }
                }
                drawerWin.pinnedFiles = drawerWin.favDefaults
                drawerWin.rebuild()
            }
        }
    }

    function saveFavorites() {
        var jsonStr = JSON.stringify(drawerWin.pinnedFiles)
        var dir = Quickshell.env("HOME") + "/.config/quickshell/.cache"
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p '" + dir + "' && printf '%s' '" + jsonStr + "' > '" + favStorePath + ".tmp' "
            + "&& mv '" + favStorePath + ".tmp' '" + favStorePath + "'"])
    }

    function pinApp(filename) {
        if (drawerWin.pinnedFiles.length >= 6) {
            contextMenu.visible = false
            return
        }
        if (drawerWin.pinnedFiles.indexOf(filename) === -1) {
            var updated = drawerWin.pinnedFiles.slice()
            updated.push(filename)
            drawerWin.pinnedFiles = updated
            saveFavorites()
            rebuild()
        }
        contextMenu.visible = false
    }

    function unpinApp(filename) {
        var idx = drawerWin.pinnedFiles.indexOf(filename)
        if (idx >= 0) {
            var updated = drawerWin.pinnedFiles.slice()
            updated.splice(idx, 1)
            drawerWin.pinnedFiles = updated
            saveFavorites()
            rebuild()
        }
        contextMenu.visible = false
    }

    // ---------- keyboard ----------
    function toggleTab() { currentTab = (currentTab === "apps") ? "shaders" : "apps" }

    function focusGrid() {
        var g = (currentTab === "apps") ? appGrid : shaderGrid
        if (g.count > 0) {
            if (g.currentIndex < 0) g.currentIndex = 0
            g.forceActiveFocus()
        }
    }

    function focusFavorites() {
        if (favoritesModel.count > 0) {
            if (favView.currentIndex < 0) favView.currentIndex = 0
            favView.forceActiveFocus()
            return true
        }
        return false
    }

    function enterContentUp() {
        focusGrid()
    }

    // Prevents text mutations when hitting backspace/modifiers
    function typeToSearch(e) {
        if (e.text.length === 1 && e.text >= " "
            && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            searchField.forceActiveFocus()
            searchField.text += e.text
            searchField.cursorPosition = searchField.text.length
            e.accepted = true
        }
    }

    // ---------- actions ----------
    function launchApp(command, needsTerminal) {
        drawerWin.close()
        Qt.callLater(() => {
            if (needsTerminal)
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"kitty -e " + command + "\")"])
            else
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"" + command + "\")"])
        })
    }

    function blacklistApp(filename) {
        Quickshell.execDetached(["bash", "-c", "echo '" + filename + "' >> ~/.config/quickshell/.cache/blacklist.txt"])
        for (var i = 0; i < appModel.count; i++) {
            if (appModel.get(i).filename === filename) { appModel.remove(i); break }
        }
        contextMenu.visible = false
        rebuild()
    }

    function applyShader(path) {
        drawerWin.close()
        var hop = 'active=$(hyprctl workspaces -j | jq ".[] | .id"); ws=1; '
                + 'while echo "$active" | grep -q "^$ws$"; do ws=$((ws+1)); done; '
                + 'hyprctl dispatch "hl.dsp.focus({ workspace = $ws })" >/dev/null 2>&1; '
        var act = (path === "OFF")
            ? 'hyprctl reload >/dev/null 2>&1'
            : 'hyprctl eval "hl.config({ decoration = { screen_shader = \\"' + path + '\\" } })" >/dev/null 2>&1'
        Lib.Shell.det(hop + act)
    }

    // ---------- app data ----------
    Process {
        id: appLoader
        running: false
        command: [Quickshell.env("HOME") + "/.config/quickshell/task-bar/dock/applist.sh"]
        stdout: SplitParser {
            onRead: data => {
                const lines = data.split('\n')
                for (const line of lines) {
                    if (line.trim().length === 0) continue
                    const parts = line.split('|')
                    if (parts.length >= 5) {
                        appModel.append({
                            name: parts[0], icon: parts[1], cmd: parts[2],
                            needsTerminal: (parts[3] || "").trim() === "true",
                            filename: parts[4]
                        })
                    }
                }
                drawerWin.rebuild()
            }
        }
        stderr: SplitParser { onRead: data => console.error("applist:", data) }
        onExited: (code, status) => console.warn("[drawer] applist.sh exited code=" + code + " apps parsed=" + appModel.count)
    }

    ListModel { id: appModel }

    // Re-run applist.sh and repopulate appModel from scratch.
    function loadApps() {
        console.warn("[drawer] loadApps(): re-running applist.sh")
        appModel.clear()
        appLoader.running = false
        appLoader.running = true
    }

    // Trigger shared by the .desktop directory watchers below.
    function scheduleAppReload() {
        if (!hasLoadedApps) { console.warn("[drawer] dir changed but apps not loaded yet; skipping"); return }
        console.warn("[drawer] .desktop dir changed -> scheduling reload")
        appReloadTimer.restart()
    }
    Timer { id: appReloadTimer; interval: 600; onTriggered: drawerWin.loadApps() }

    // Live-watch the application directories so newly installed / removed apps show
    // up without restarting quickshell
    component AppDirWatch: FolderListModel {
        showDirs: false
        showFiles: true
        nameFilters: ["*.desktop"]
        sortField: FolderListModel.Unsorted
        property bool primed: false
        onStatusChanged: if (status === FolderListModel.Ready) { console.warn("[drawer] watch ready:", folder, "count=" + count); primed = true }
        onCountChanged: {
            console.warn("[drawer] watch countChanged:", folder, "count=" + count, "primed=" + primed)
            if (primed) drawerWin.scheduleAppReload()
        }
    }
    AppDirWatch { folder: "file://" + Quickshell.env("HOME") + "/.local/share/applications" }
    AppDirWatch { folder: "file:///usr/share/applications" }
    AppDirWatch { folder: "file:///var/lib/flatpak/exports/share/applications" }

    ListModel { id: favoritesModel }       
    ListModel { id: filteredModel }        
    ListModel { id: filteredShaderModel }

    function isPinned(filename) { return drawerWin.pinnedFiles.indexOf(filename) >= 0 }

    readonly property var shaderData: [
        { name: "Reading Mode", path: "reading_mode.glsl", icon: "reading.svg" },
        { name: "Night Light",  path: "night.glsl",        icon: "night.svg" },
        { name: "CRT Mode",     path: "crt_mode.glsl",     icon: "crt.svg" },
        { name: "Main",         path: "main.glsl",         icon: "main.svg" },
        { name: "Outdoor",      path: "outdoor.glsl",      icon: "outdoor.svg" },
        { name: "Cinema",       path: "cinema.glsl",       icon: "cinema.svg" },
        { name: "Amano",        path: "amano.glsl",        icon: "soft.svg" },
        { name: "Art Canvas",   path: "art_canvas.glsl",   icon: "canvas.svg" },
        { name: "Dither",       path: "dither.glsl",       icon: "dither.svg" },
        { name: "Fuji Acros",   path: "fuji_acros.glsl",   icon: "fuji.svg" },
        { name: "VHS",          path: "vhs.glsl",          icon: "vhs.svg" },
        { name: "Gameboy",      path: "gameboy.glsl",      icon: "gameboy.svg" },
        { name: "Silent Hill",  path: "silent_hill.glsl",  icon: "sh.svg" },
        { name: "Smart Invert", path: "smart_invert.glsl", icon: "invert.svg" },
        { name: "Greens",       path: "greens.glsl",       icon: "green.svg" },
        { name: "Turn Off All", path: "OFF",               icon: "off.svg" }
    ]

    function shaderTarget(path) {
        return path === "OFF" ? "OFF" : Quickshell.env("HOME") + "/.config/hypr/shaders/" + path
    }

    Component.onCompleted: {
        loadFavorites()
    }

    function rebuild() {
        // Guard against early engine initialization calls before ids are registered
        if (!searchField) return

        var query = searchField.text.toLowerCase().trim()
        function hit(name) { return query === "" || name.toLowerCase().includes(query) }

        favoritesModel.clear()
        for (var p = 0; p < drawerWin.pinnedFiles.length; p++) {
            for (var i = 0; i < appModel.count; i++) {
                var it = appModel.get(i)
                if (it && it.filename === drawerWin.pinnedFiles[p] && hit(it.name)) { 
                    favoritesModel.append(it)
                    break 
                }
            }
        }

        filteredModel.clear()
        for (var j = 0; j < appModel.count; j++) {
            var item = appModel.get(j)
            if (item && !drawerWin.isPinned(item.filename) && hit(item.name)) {
                filteredModel.append(item)
            }
        }

        filteredShaderModel.clear()
        for (var s = 0; s < drawerWin.shaderData.length; s++) {
            var sh = drawerWin.shaderData[s]
            if (sh && hit(sh.name)) {
                filteredShaderModel.append({ sName: sh.name, sPath: sh.path, sIcon: sh.icon })
            }
        }

        Qt.callLater(function() {
            if (appGrid) appGrid.positionViewAtBeginning()
            if (shaderGrid) shaderGrid.positionViewAtBeginning()
       })
    }

    MouseArea {
        anchors.fill: parent
        enabled: drawerWin.isOpen
        onClicked: { if (contextMenu.visible) contextMenu.visible = false; else drawerWin.close() }
        z: 0
    }

    Item {
        id: shell
        width: 860
        height: 520
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10
        anchors.bottomMargin: 50
        z: 1

        property real activeHeight: drawerWin.isOpen ? height : 0
        Behavior on activeHeight { NumberAnimation { duration: 360; easing.type: Easing.OutQuint } }

        opacity: drawerWin.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuart } }

        Item {
            anchors.fill: clipped
            z: -1
            visible: shell.activeHeight > 0
            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                radius: 26; samples: 31
                color: "#70000000"
                horizontalOffset: 0; verticalOffset: 6
            }
            Rectangle { anchors.fill: parent; radius: 16; color: "black" }
        }

        Item {
            id: clipped
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.activeHeight
            clip: true

            Rectangle {
                id: panel
                anchors.bottom: parent.bottom
                width: shell.width
                height: shell.height
                radius: 12
                color: drawerWin.theme.bgMain

                // eat away clicks inside the panel so they don't leak to window-level closer
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPressed: (mouse) => { contextMenu.visible = false; mouse.accepted = true }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    // ============ TOP SECTION (HEADER + PROFILE) ============
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        Layout.leftMargin: 6
                        Layout.rightMargin: 6

                        Text {
                            text: drawerWin.currentTab === "apps" ? "Programs" : "Shaders"
                            font.family: "Newsreader"
                            font.pixelSize: 28
                            font.weight: Font.Medium
                            color: drawerWin.theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

                        RowLayout {
                            spacing: 10
                            Item {
                                width: 32; height: 32
                                Image {
                                    id: avatarImg
                                    anchors.fill: parent
                                    source: "../profile.jpg"
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true; mipmap: true; cache: true
                                    visible: false
                                }
                                Rectangle { id: avatarMask; anchors.fill: parent; radius: width / 2; visible: false }
                                OpacityMask { anchors.fill: parent; source: avatarImg; maskSource: avatarMask }
                                Rectangle {
                                    anchors.fill: parent; radius: width / 2
                                    color: "transparent"
                                    border.width: 1.5; border.color: drawerWin.theme.accent
                                }
                            }
                            Text {
                                text: Quickshell.env("USER") || ""
                                font.family: drawerWin.theme.textFont
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: drawerWin.theme.textPrimary
                            }
                        }
                    }

                    // ============ CENTER MAIN CONTENT AREA ============
                    Item {
                        id: gridArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            visible: drawerWin.currentTab === "apps"
                            spacing: 8

                            ListView {
                                id: favView
                                Layout.fillWidth: true
                                Layout.preferredHeight: 84
                                Layout.leftMargin: 4
                                visible: favoritesModel.count > 0
                                orientation: ListView.Horizontal
                                interactive: false
                                model: favoritesModel
                                keyNavigationEnabled: true
                                highlightFollowsCurrentItem: true
                                highlightMoveDuration: 130
                                highlight: Rectangle {
                                    radius: 12
                                    color: drawerWin.theme.subtleFill
                                    border.width: 2
                                    border.color: drawerWin.theme.accent
                                    visible: favView.activeFocus
                                }
                                delegate: AppTile {
                                    width: Math.floor(gridArea.width / drawerWin.cols)
                                    height: 84
                                    flat: true
                                    showPin: false
                                    tName: model.name
                                    tIcon: model.icon
                                    tCmd: model.cmd
                                    tTerminal: model.needsTerminal
                                    tFile: model.filename
                                }
                                Keys.onReturnPressed: if (favView.currentItem) drawerWin.launchApp(favView.currentItem.tCmd, favView.currentItem.tTerminal)
                                Keys.onEnterPressed:  if (favView.currentItem) drawerWin.launchApp(favView.currentItem.tCmd, favView.currentItem.tTerminal)
                                Keys.onEscapePressed: drawerWin.close()
                                Keys.onTabPressed: { drawerWin.toggleTab(); drawerWin.focusGrid() }
                                Keys.onBacktabPressed: { drawerWin.toggleTab(); drawerWin.focusGrid() }
                                Keys.onDownPressed: drawerWin.focusGrid()
                                Keys.onUpPressed: (e) => e.accepted = true
                                Keys.onPressed: (e) => drawerWin.typeToSearch(e)
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.leftMargin: 6
                                Layout.rightMargin: 6
                                Layout.preferredHeight: 1
                                visible: favoritesModel.count > 0
                                color: drawerWin.theme.outline
                            }

                            AppGrid {
                                id: appGrid
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: filteredModel
                            }
                        }

                        ShaderGrid {
                            id: shaderGrid
                            anchors.fill: parent
                            visible: drawerWin.currentTab === "shaders"
                            model: filteredShaderModel
                        }
                    }

                    // ============ BOTTOM UTILITY DOCK ============
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        spacing: 12

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: 10
                            color: drawerWin.theme.subtleFill
                            border.width: 1
                            border.color: searchField.activeFocus ? drawerWin.theme.accent : drawerWin.theme.outline
                            Behavior on border.color { ColorAnimation { duration: 160 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 8

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Search apps and features..."
                                        font.family: drawerWin.theme.textFont
                                        font.pixelSize: 13
                                        color: drawerWin.theme.textSecondary
                                        visible: searchField.text === ""
                                    }
                                    TextInput {
                                        id: searchField
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: drawerWin.theme.textFont
                                        font.pixelSize: 13
                                        color: drawerWin.theme.textPrimary
                                        selectionColor: drawerWin.theme.accent
                                        selectedTextColor: drawerWin.theme.textOnAccent
                                        selectByMouse: true
                                        clip: true
                                        focus: true
                                        onTextChanged: drawerWin.rebuild()
                                        
                                        Keys.onEscapePressed: drawerWin.close()
                                        Keys.onTabPressed: drawerWin.toggleTab()
                                        Keys.onBacktabPressed: drawerWin.toggleTab()
                                        Keys.onUpPressed: drawerWin.enterContentUp()
                                        Keys.onLeftPressed: (e) => { if (searchField.text === "") drawerWin.enterContentUp(); else e.accepted = false }
                                        Keys.onRightPressed: (e) => { if (searchField.text === "") drawerWin.enterContentUp(); else e.accepted = false }
                                        Keys.onReturnPressed: {
                                            if (drawerWin.currentTab === "apps" && filteredModel.count > 0) {
                                                var item = filteredModel.get(0)
                                                drawerWin.launchApp(item.cmd, item.needsTerminal)
                                            } else if (drawerWin.currentTab === "shaders" && filteredShaderModel.count > 0) {
                                                var sh = filteredShaderModel.get(0)
                                                drawerWin.applyShader(drawerWin.shaderTarget(sh.sPath))
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 190
                            Layout.preferredHeight: 40
                            radius: 10
                            color: drawerWin.theme.subtleFill
                            border.width: 1
                            border.color: drawerWin.theme.outline

                            Rectangle {
                                id: segIndicator
                                width: parent.width / 2 - 4
                                height: parent.height - 8
                                y: 4
                                x: drawerWin.currentTab === "apps" ? 4 : parent.width / 2 + 0
                                radius: 7
                                color: drawerWin.theme.accent
                                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                            }

                            Row {
                                anchors.fill: parent
                                TabButton2 { tabId: "apps"; label: "Apps" }
                                TabButton2 { tabId: "shaders"; label: "Shaders" }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- DYNAMIC CONTEXT MENU (PIN/UNPIN CONTROLS) ----------
    Rectangle {
        id: contextMenu
        parent: panel
        visible: false
        width: 160
        height: 112
        radius: 8
        z: 999
        color: drawerWin.theme.bgCard
        border.color: drawerWin.theme.outline
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 2
            
            Rectangle {
                width: parent.width; height: 33; radius: 5
                color: ctxOpen.containsMouse ? drawerWin.theme.bgItemHover : "transparent"
                Text { anchors.centerIn: parent; text: "Open App"; color: drawerWin.theme.textPrimary; font.family: drawerWin.theme.textFont; font.pixelSize: 12 }
                MouseArea {
                    id: ctxOpen; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { drawerWin.launchApp(drawerWin.contextApp.cmd, drawerWin.contextApp.needsTerminal); contextMenu.visible = false }
                }
            }

            Rectangle {
                id: pinButtonWrapper
                width: parent.width; height: 33; radius: 5
                
                readonly property bool isCurrentlyPinned: drawerWin.isPinned(drawerWin.contextApp.filename)
                readonly property bool isAtLimit: drawerWin.pinnedFiles.length >= 6
                readonly property bool isGreyedOut: !isCurrentlyPinned && isAtLimit

                color: (ctxFav.containsMouse && !isGreyedOut) ? drawerWin.theme.bgItemHover : "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: pinButtonWrapper.isCurrentlyPinned ? "Unpin from Top" : "Pin to Top"
                    color: pinButtonWrapper.isGreyedOut 
                        ? Qt.rgba(drawerWin.theme.textSecondary.r, drawerWin.theme.textSecondary.g, drawerWin.theme.textSecondary.b, 0.4)
                        : drawerWin.theme.textPrimary
                    font.family: drawerWin.theme.textFont
                    font.pixelSize: 12
                }
                MouseArea {
                    id: ctxFav; anchors.fill: parent; hoverEnabled: true; 
                    cursorShape: pinButtonWrapper.isGreyedOut ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (pinButtonWrapper.isCurrentlyPinned) {
                            drawerWin.unpinApp(drawerWin.contextApp.filename)
                        } else if (!pinButtonWrapper.isAtLimit) {
                            drawerWin.pinApp(drawerWin.contextApp.filename)
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 33; radius: 5
                color: ctxHide.containsMouse ? Qt.rgba(0.8, 0.25, 0.25, 0.18) : "transparent"
                Text { anchors.centerIn: parent; text: "Hide App"; color: drawerWin.theme.accentRed; font.family: drawerWin.theme.textFont; font.pixelSize: 12 }
                MouseArea {
                    id: ctxHide; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: drawerWin.blacklistApp(drawerWin.contextApp.filename)
                }
            }
        }
    }

    // ======================= COMPONENTS =======================

    component TabButton2: Item {
        id: tb
        property string tabId: ""
        property string label: ""
        readonly property bool current: drawerWin.currentTab === tabId
        width: parent.width / 2
        height: parent.height

        Text {
            anchors.centerIn: parent
            text: tb.label
            font.family: drawerWin.theme.textFont
            font.pixelSize: 13
            font.weight: tb.current ? Font.DemiBold : Font.Medium
            color: tb.current ? drawerWin.theme.textOnAccent : drawerWin.theme.textSecondary
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: drawerWin.currentTab = tb.tabId
        }
    }

    component AppTile: Item {
        id: tile
        property string tName: ""
        property string tIcon: ""
        property string tCmd: ""
        property bool tTerminal: false
        property string tFile: ""
        property bool showPin: true
        property bool flat: false 

        MouseArea {
            id: am
            anchors.fill: parent
            anchors.margins: 4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (m) => {
                if (m.button === Qt.RightButton) {
                    drawerWin.contextApp = { cmd: tile.tCmd, needsTerminal: tile.tTerminal, filename: tile.tFile }
                    var gp = mapToItem(panel, m.x, m.y)
                    contextMenu.x = Math.min(gp.x + 6, panel.width - contextMenu.width - 8)
                    contextMenu.y = Math.min(gp.y + 6, panel.height - contextMenu.height - 8)
                    contextMenu.visible = true
                } else {
                    drawerWin.launchApp(tile.tCmd, tile.tTerminal)
                }
            }

            Rectangle {
                id: card
                anchors.fill: parent
                radius: 12
                color: tile.flat
                    ? (am.containsMouse ? drawerWin.theme.subtleFillHover : "transparent")
                    : (drawerWin.theme.isDarkMode
                        ? (am.containsMouse
                            ? drawerWin.withAlpha(drawerWin.theme.bgItemHover, drawerWin.tileAlphaDarkHover)
                            : drawerWin.withAlpha(drawerWin.theme.bgCard, drawerWin.tileAlphaDark))
                        : (am.containsMouse
                            ? drawerWin.withAlpha(Qt.darker(drawerWin.theme.bgCard, 1.12), drawerWin.tileAlphaLightHover)
                            : drawerWin.withAlpha(drawerWin.theme.bgCard, drawerWin.tileAlphaLight)))
                Behavior on color { ColorAnimation { duration: 160 } }

                scale: am.pressed ? 0.93 : (am.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
                y: am.pressed ? 2 : (am.containsMouse ? -3 : 0)
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Text {
                    visible: tile.showPin && drawerWin.isPinned(tile.tFile)
                    anchors.top: parent.top; anchors.right: parent.right
                    anchors.topMargin: 8; anchors.rightMargin: 9
                    text: "★"
                    font.family: drawerWin.theme.textFont
                    font.pixelSize: 10
                    color: drawerWin.theme.accent
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 9
                    Item {
                        width: drawerWin.theme.isDarkMode ? 58 : 48
                        height: drawerWin.theme.isDarkMode ? 58 : 48
                        anchors.horizontalCenter: parent.horizontalCenter
                        Image {
                            id: appImg
                            anchors.fill: parent
                            source: {
                                var p = String(tile.tIcon).trim()
                                return p.indexOf("/") >= 0 ? "file://" + p : "image://icon/" + p
                            }
                            fillMode: Image.PreserveAspectFit
                            smooth: true; mipmap: true; cache: true; asynchronous: false
                            visible: drawerWin.theme.isDarkMode
                            property bool errored: false
                            onStatusChanged: { if (status === Image.Error && !errored) { errored = true; source = "image://icon/application-x-executable" } }
                        }
                        ColorOverlay {
                            anchors.fill: appImg
                            source: appImg
                            color: "#22000000"
                            visible: !drawerWin.theme.isDarkMode
                        }
                    }
                    Text {
                        width: tile.width - 24
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.tName
                        color: drawerWin.theme.textPrimary
                        font.family: drawerWin.theme.textFont
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }
        }
    }

    component AppGrid: GridView {
        id: ag
        cellWidth: Math.floor(width / drawerWin.cols)
        cellHeight: drawerWin.cellH
        clip: true
        topMargin: 12
        bottomMargin: 8
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 600

        keyNavigationEnabled: true
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 130
        highlight: Rectangle {
            radius: 12
            color: drawerWin.theme.subtleFill
            border.width: 2
            border.color: drawerWin.theme.accent
            visible: ag.activeFocus
        }
        Keys.onPressed: (e) => drawerWin.typeToSearch(e)
        Keys.onReturnPressed: if (ag.currentItem) drawerWin.launchApp(ag.currentItem.tCmd, ag.currentItem.tTerminal)
        Keys.onEnterPressed:  if (ag.currentItem) drawerWin.launchApp(ag.currentItem.tCmd, ag.currentItem.tTerminal)
        Keys.onEscapePressed: drawerWin.close()
        Keys.onTabPressed: { drawerWin.toggleTab(); drawerWin.focusGrid() }
        Keys.onBacktabPressed: { drawerWin.toggleTab(); drawerWin.focusGrid() }
        
        Keys.onUpPressed: (e) => {
            if (ag.currentIndex < drawerWin.cols) {
                if (!drawerWin.focusFavorites()) searchField.forceActiveFocus()
                e.accepted = true
            } else e.accepted = false
        }
        Keys.onDownPressed: (e) => {
            if (ag.currentIndex >= ag.count - drawerWin.cols) {
                searchField.forceActiveFocus()
                e.accepted = true
            } else e.accepted = false
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (e) => {
                snapAnim.stop()
                var maxY = Math.max(-ag.topMargin, ag.contentHeight - ag.height + ag.bottomMargin)
                var base = agAnim.running ? agAnim.to : ag.contentY
                var step = Math.abs(e.angleDelta.y) * 1.1 + 24
                var ny = Math.max(-ag.topMargin, Math.min(base + (e.angleDelta.y > 0 ? -step : step), maxY))
                agAnim.to = ny; agAnim.restart(); e.accepted = true
            }
        }

        function snapToRow() {
            var maxY = Math.max(-ag.topMargin, ag.contentHeight - ag.height + ag.bottomMargin)
            var snapped = Math.round((ag.contentY + ag.topMargin) / ag.cellHeight) * ag.cellHeight - ag.topMargin
            snapped = Math.max(-ag.topMargin, Math.min(snapped, maxY))
            if (Math.abs(snapped - ag.contentY) > 0.5) { snapAnim.to = snapped; snapAnim.restart() }
        }
        NumberAnimation {
            id: agAnim; target: ag; property: "contentY"; duration: 480; easing.type: Easing.OutExpo
            onFinished: ag.snapToRow()
        }
        NumberAnimation { id: snapAnim; target: ag; property: "contentY"; duration: 160; easing.type: Easing.OutCubic }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 5; radius: 3
                color: drawerWin.theme.textSecondary
                opacity: parent.active ? 0.5 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }

        delegate: AppTile {
            width: ag.cellWidth
            height: ag.cellHeight
            tName: model.name
            tIcon: model.icon
            tCmd: model.cmd
            tTerminal: model.needsTerminal
            tFile: model.filename
        }
    }

    component ShaderGrid: GridView {
        id: sg
        cellWidth: Math.floor(width / drawerWin.cols)
        cellHeight: drawerWin.cellH
        clip: true
        topMargin: 12
        bottomMargin: 8
        boundsBehavior: Flickable.StopAtBounds
        snapMode: GridView.SnapToRow

        keyNavigationEnabled: true
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 130
        highlight: Rectangle {
            radius: 12
            color: drawerWin.theme.subtleFill
            border.width: 2
            border.color: drawerWin.theme.accent
            visible: sg.activeFocus
        }
        function activateCurrent() {
            var m = filteredShaderModel.get(sg.currentIndex)
            if (m) drawerWin.applyShader(drawerWin.shaderTarget(m.sPath))
        }
        Keys.onPressed: (e) => drawerWin.typeToSearch(e)
        Keys.onReturnPressed: sg.activateCurrent()
        Keys.onEnterPressed:  sg.activateCurrent()
        Keys.onEscapePressed: drawerWin.close()
        Keys.onTabPressed: { drawerWin.toggleTab(); drawerWin.focusGrid() }
        Keys.onBacktabPressed: { drawerWin.toggleTab(); drawerWin.focusGrid() }
        Keys.onUpPressed: (e) => e.accepted = false
        Keys.onDownPressed: (e) => {
            if (sg.currentIndex >= sg.count - drawerWin.cols) {
                searchField.forceActiveFocus()
                e.accepted = true
            } else e.accepted = false
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 5; radius: 3
                color: drawerWin.theme.textSecondary
                opacity: parent.active ? 0.5 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }

        delegate: Item {
            width: sg.cellWidth
            height: sg.cellHeight

            MouseArea {
                id: sm
                anchors.fill: parent
                anchors.margins: 4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: drawerWin.applyShader(drawerWin.shaderTarget(model.sPath))

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: drawerWin.theme.isDarkMode
                        ? (sm.containsMouse ? drawerWin.theme.subtleFill : "transparent")
                        : (sm.containsMouse ? Qt.darker(drawerWin.theme.bgCard, 1.12) : drawerWin.theme.bgCard)
                    Behavior on color { ColorAnimation { duration: 160 } }

                    scale: sm.pressed ? 0.93 : (sm.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
                    y: sm.pressed ? 2 : (sm.containsMouse ? -3 : 0)
                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 9
                        Item {
                            width: drawerWin.theme.isDarkMode ? 56 : 46
                            height: drawerWin.theme.isDarkMode ? 56 : 46
                            anchors.horizontalCenter: parent.horizontalCenter
                            Image {
                                id: shImg
                                anchors.fill: parent
                                source: "shader-icons/light/" + model.sIcon
                                fillMode: Image.PreserveAspectFit
                                smooth: true; mipmap: true; cache: true
                                sourceSize: Qt.size(96, 96)
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: shImg
                                source: shImg
                                color: sm.containsMouse ? drawerWin.theme.accent : drawerWin.theme.textPrimary
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                        }
                        Text {
                            width: sg.cellWidth - 24
                            horizontalAlignment: Text.AlignHCenter
                            text: model.sName
                            color: drawerWin.theme.textPrimary
                            font.family: drawerWin.theme.textFont
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }
            }
        }
    }
}
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects
import "../theme.js" as Theme      // will  consolidate to theme engine soon!            

PanelWindow {
    id: drawerWin

    //  WINDOW CONFIG 
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    visible: drawerContainer.activeHeight > 1

    WlrLayershell.exclusiveZone: -1 
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property bool isOpen: false
    property bool isDarkMode: true 
    property bool hasLoadedApps: false
    property var contextApp: ({})

    //  BACKGROUND CLICK (Close) 
    MouseArea {
        anchors.fill: parent
        enabled: drawerWin.isOpen
        hoverEnabled: true
        onClicked: {
            if (contextMenu.visible) contextMenu.visible = false
            else drawerWin.close()
        }
        z: 0
    }

    function toggle() {
        if (isOpen) close()
        else open()
    }

    function open() {
        isOpen = true
        searchField.text = ""
        searchField.forceActiveFocus()
        if (!hasLoadedApps) {
            hasLoadedApps = true
            appLoader.running = true
        }
    }

    function close() {
        isOpen = false
        contextMenu.visible = false
        searchField.focus = false
    }

    //  ACTIONS 
    function launchApp(command, needsTerminal) {
    drawerWin.close()
    Qt.callLater(() => {
        if (needsTerminal) {
            Quickshell.execDetached([
                "hyprctl", "dispatch",
                "hl.dsp.exec_cmd(\"kitty -e " + command + "\")"
            ])
        } else {
            Quickshell.execDetached([
                "hyprctl", "dispatch",
                "hl.dsp.exec_cmd(\"" + command + "\")"
            ])
        }
    })
}

    function blacklistApp(filename) {
        Quickshell.execDetached(["bash", "-c", "echo '" + filename + "' >> ~/.config/quickshell/.cache/blacklist.txt"])
        for (var i = 0; i < appModel.count; i++) {
            if (appModel.get(i).filename === filename) {
                appModel.remove(i)
                break
            }
        }
        contextMenu.visible = false
        filterApps()
    }

    //  APP LOADER 
    Process {
        id: appLoader
        running: false
        command: [Quickshell.env("HOME") + "/.config/quickshell/task-bar/dock/applist.sh"]
        
        stdout: SplitParser {
            onRead: data => {
                console.log("Script output received, length:", data.length)
                const lines = data.split('\n')
                console.log("Number of lines:", lines.length)
                for (const line of lines) {
                    if (line.trim().length === 0) continue
                    const parts = line.split('|')
                    if (parts.length >= 5) {
                        appModel.append({
                            name: parts[0],
                            icon: parts[1],
                            cmd: parts[2],
                            needsTerminal: (parts[3] || "").trim() === "true",
                            filename: parts[4]
                        })
                    }
                }
                console.log("Apps loaded:", appModel.count)
                filterApps()
            }
        }
        
        stderr: SplitParser {
            onRead: data => {
                console.error("Script error:", data)
            }
        }
        
        onExited: (code) => {
            console.log("Script exited with code:", code)
            if (code !== 0) {
                console.error("Script failed!")
            }
        }
    }

    ListModel { id: appModel }
    ListModel { id: filteredModel }

    function filterApps() {
        filteredModel.clear()
        var query = searchField.text.toLowerCase().trim()
        for(var i=0; i<appModel.count; i++) {
            var item = appModel.get(i)
            if (query === "" || item.name.toLowerCase().includes(query)) {
                filteredModel.append(item)
            }
        }
    }

    //  DRAWER CONTAINER 
    Item {
        id: drawerContainer
        width: 720
        height: 550
        
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 55 
        z: 1

        property real activeHeight: isOpen ? height : 0
        
        Behavior on activeHeight { 
            NumberAnimation { duration: 350; easing.type: Easing.OutQuart } 
        }
        
        //  SHADOW EFFECT 
        Item {
            anchors.fill: clippedContent
            z: -1 // Place behind the drawer
            visible: parent.activeHeight > 0

            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                radius: 20          
                samples: 25         
                color: "#60000000"  
                horizontalOffset: 0
                verticalOffset: 0
            }

            Rectangle {
                anchors.fill: parent
                radius: 16          
                color: "black"      
            }
        }

        Item {
            id: clippedContent 
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.activeHeight
            clip: true

            Rectangle {
                anchors.bottom: parent.bottom
                width: drawerContainer.width
                height: drawerContainer.height
                radius: 16
                color: drawerWin.isDarkMode ? '#141719' : "#F0ECE6"
                //border.width: 1
                //border.color: drawerWin.isDarkMode ? "#25FFFFFF" : "#40000000"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    // SEARCH
                    Rectangle {
                        Layout.fillWidth: false
                        Layout.preferredWidth: 500
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignCenter
                        radius: 12
                        color: drawerWin.isDarkMode ? "#25FFFFFF" : "#20000000"
                        
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 15
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Type to search..."
                            font.pixelSize: 15
                            color: drawerWin.isDarkMode ? '#d5c9b2' : '#333b26'
                            visible: searchField.text === ""
                        }

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 15
                            
                            color: drawerWin.isDarkMode ? '#d5c9b2' : '#333b26'
                            selectionColor: "#a7c080"
                            selectedTextColor: "#282828"
                            
                            selectByMouse: true
                            onTextChanged: drawerWin.filterApps()
                            
                            Keys.onEscapePressed: drawerWin.close()
                            

                            Keys.onReturnPressed: {
                                if (filteredModel.count > 0) {
                                    var item = filteredModel.get(0)
                                    launchApp(item.cmd, item.needsTerminal)
                                }
                            }
                        }
                    }

                    // GRID
                    GridView {
                        id: appGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        cellWidth: 100
                        cellHeight: 120
                        topMargin: 10
                        leftMargin: 35
                        rightMargin: 20
                        clip: true
                        model: filteredModel
                        focus: true
                        keyNavigationEnabled: false
                        
                    flickDeceleration: 10
                    maximumFlickVelocity: 5500
                    boundsBehavior: Flickable.DragAndOvershootBounds
                        
                        ScrollBar.vertical: ScrollBar {
                            id: scrollBar
                            policy: ScrollBar.AsNeeded
                            
                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: scrollBar.pressed ? "#60FFFFFF" : "#40FFFFFF"
                                opacity: scrollBar.active ? 1.0 : 0.0
                                
                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }
                            }
                        }

                        delegate: Item {
                            width: appGrid.cellWidth
                            height: appGrid.cellHeight

                            MouseArea {
                                id: delegateMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        drawerWin.contextApp = {
                                            cmd: model.cmd,
                                            needsTerminal: model.needsTerminal,
                                            filename: model.filename
                                        }
                                        var globalPos = mapToItem(drawerWin.contentItem, mouse.x, mouse.y)
                                        contextMenu.x = globalPos.x + 10
                                        contextMenu.y = globalPos.y + 10
                                        contextMenu.visible = true
                                    } else {
                                        launchApp(model.cmd, model.needsTerminal)
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: 12
                                    color: delegateMouse.containsMouse ? "#25FFFFFF" : "transparent"
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    
                                    // ICON
                                    Item {
                                        width: 56
                                        height: 56
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        
                                        Image {
                                            id: dIcon
                                            anchors.fill: parent
                                            source: {
                                                var iconPath = model.icon.trim()
                                                
                                                // If it's a full path, use it directly
                                                if (iconPath.indexOf("/") >= 0) {
                                                    return "file://" + iconPath
                                                }
                                                
                                                // Otherwise use icon theme provider
                                                return "image://icon/" + iconPath
                                            }
                                            
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            mipmap: true
                                            cache: true
                                            asynchronous: false  // Disable async to prevent icon flickering
                                            
                                            visible: drawerWin.isDarkMode
                                            
                                            property bool errorOccurred: false
                                            
                                            onStatusChanged: {
                                                if (status === Image.Error && !errorOccurred) {
                                                    errorOccurred = true
                                                    source = "image://icon/application-x-executable"
                                                } else if (status === Image.Ready) {
                                                    errorOccurred = false
                                                }
                                            }
                                        }
                                        
                                        ColorOverlay {
                                            anchors.fill: dIcon
                                            source: dIcon
                                            color: "#33000000"
                                            visible: !drawerWin.isDarkMode
                                        }
                                    }

                                    // LABEL
                                    Text {
                                        text: model.name
                                        width: appGrid.cellWidth - 10 
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        color: drawerWin.isDarkMode ? "#fffcf4" : "#282828"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    //  CONTEXT MENU 
    Rectangle {
        id: contextMenu
        visible: false
        width: 140
        height: 82
        radius: 8
        z: 999 
        
        color: "#282828"
        border.color: "#444444"
        border.width: 1
        
        Column {
            anchors.fill: parent
            anchors.margins: 1
            
            Rectangle {
                width: parent.width
                height: 40
                radius: 6
                color: btnOpenMouse.containsMouse ? "#383838" : "transparent"
                Text { anchors.centerIn: parent; text: "Open App"; color: "white"; font.pixelSize: 13 }
                MouseArea {
                    id: btnOpenMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        launchApp(drawerWin.contextApp.cmd, drawerWin.contextApp.needsTerminal)
                        contextMenu.visible = false
                    }
                }
            }
            
            Rectangle { 
                width: parent.width - 10
                height: 1
                color: "#444444"
                anchors.horizontalCenter: parent.horizontalCenter 
            }
            
            Rectangle {
                width: parent.width
                height: 40
                radius: 6
                color: btnHideMouse.containsMouse ? "#4a1b1b" : "transparent"
                Text { anchors.centerIn: parent; text: "Hide App"; color: "#ff8888"; font.pixelSize: 13 }
                MouseArea {
                    id: btnHideMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: blacklistApp(drawerWin.contextApp.filename)
                }
            }
        }
    }
}

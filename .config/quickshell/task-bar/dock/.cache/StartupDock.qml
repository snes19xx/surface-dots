import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland 
import Qt5Compat.GraphicalEffects 
import "../theme.js" as Theme
import "../lib" as Lib

PanelWindow {
    id: dockWin
    
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    
    Drawer {
    id: appDrawer
    isDarkMode: dockWin.isDarkMode
}

    anchors { bottom: true; left: true; right: true }
    height: 50
    margins { bottom: -14 }
    color: "transparent"
    
    signal launchApp()
    signal toggleHub()
    
    property bool isDarkMode: true
    readonly property string _themeModePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"
    
    // Smart hide mechanism - future implementation ready
    property bool smartHideEnabled: false  // Set to true to enable smart hiding
    property var launchedApps: []  // Track apps launched from dock
    property bool shouldHide: false  // Hide when apps are running
    
    FileView {
        path: dockWin._themeModePath
        watchChanges: true
        preload: true
        onLoaded: { 
            var m = String(text() || "").trim().toLowerCase()
            dockWin.isDarkMode = (m !== "light") 
        }
    }
    
    Lib.ThemeEngine { 
        id: theme
        isDarkMode: dockWin.isDarkMode 
    }
    /*
    // Process monitor for smart hide (checks every x seconds depending on resourc use balance)
    Timer {
        id: appMonitor
        interval: 3000000 //for now (testing only)
        running: smartHideEnabled && launchedApps.length > 0
        repeat: true
        onTriggered: {
            // Check if any launched apps are still running
            var stillRunning = false
            for (var i = 0; i < launchedApps.length; i++) {
                // Future: implement actual process checking
                // For now, this is a placeholder
                // You would use: pidof, pgrep, or Hyprland IPC
            }
            
            if (!stillRunning) {
                // All apps closed, show dock
                dockWin.shouldHide = false
                dockWin.launchedApps = []
            }
        }
    }
    */
    // Function to launch app with tracking
    function launchAppTracked(command, appName) {
        if (smartHideEnabled) {
            launchedApps.push(appName)
            shouldHide = true
        }
        Quickshell.execDetached(command)
    }
    
    // Main dock container
    Item {
        id: dockContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: dockContent.width
        height: dockContent.height
        
        // Only hide if smart hide is enabled AND should hide
        opacity: (smartHideEnabled && shouldHide) ? 0.0 : 1.0
        visible: opacity > 0
        
        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.InOutQuart }
        }
        

       // Main dock pill - clean with clipping for sharp bottom
Item {
    id: dockContent
    height: 56
    width: mainLayout.implicitWidth + 35
    clip: true  // Cuts off anything outside bounds
    
    // Main rounded rectangle
    Rectangle {
        id: dockPill
        anchors.fill: parent
        anchors.bottomMargin: -12  // Push rounded bottom outside clip area
        radius: 12
        color: theme.isDarkMode ? '#00000000' : '#00949689'
    }
            
            
            
            // Mouse area ONLY for the dock pill
            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true
                onPressed: mouse.accepted = false
            }
            
            
            RowLayout {
                id: mainLayout
                anchors.verticalCenterOffset: 5 //top padding
                anchors.centerIn: parent
                spacing: -5
                
                // LAUNCHER
                Item {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    
                    DockButton {
                        anchors.centerIn: parent
                        iconPath: "../lib/arch.svg"
                        tooltipText: "Applications"
                        onClicked: appDrawer.toggle()
                    }
                }
                
                // Separator
                Rectangle { 
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 32
                    color: theme.isDarkMode ? "#25FFFFFF" : "#25000000"
                }
                
                // APPS
                Row {
                    spacing: -10
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    
                    DockAppIcon {
                        iconName: "firefox"
                        appName: "Firefox"
                        onClicked: dockWin.launchAppTracked(["firefox"], "firefox")
                    }
                    
                    
                    DockAppIcon {
                        iconName: "code"
                        appName: "VS Code"
                        onClicked: dockWin.launchAppTracked(["code"], "code")
                    }
                    
                    DockAppIcon {
                        iconName: "spotify"
                        appName: "Spotify"
                        onClicked: dockWin.launchAppTracked(["spotify"], "spotify")
                    }
                    
                    DockAppIcon {
                        iconName: "kitty"
                        appName: "Terminal"
                        onClicked: dockWin.launchAppTracked(["kitty"], "kitty")
                    }
                }
                
                
                  //DATE SEGMENT COMMENTED OUT BECAUSE WE WILL USE DATE TIME FROM BAR
                // Separator
                Rectangle { 
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 32
                    color: theme.isDarkMode ? "#25FFFFFF" : "#25000000"
                }

                // TIME/DATE SEGMENT  
                Item {
                    Layout.preferredWidth: timeSegment.width
                    Layout.preferredHeight: 48
                    
                    MouseArea {
                        id: timeSegment
                        width: timeContent.width + 17
                        height: parent.height
                        hoverEnabled: true
                        
                        onClicked: dockWin.toggleHub()
                        
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: parent.containsMouse ? (theme.isDarkMode ? "#18FFFFFF" : "#18000000") : "transparent"
                            
                            Behavior on color {
                                ColorAnimation { duration: 200; easing.type: Easing.OutQuart }
                            }
                            
                            scale: parent.pressed ? 0.96 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation { duration: 100; easing.type: Easing.OutQuart }
                            }
                            
                            Column {
                                id: timeContent
                                anchors.centerIn: parent
                                spacing: 0
                                
                                Text {
                                    id: timeText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Qt.formatDateTime(new Date(), "h:mm AP")
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: theme.textPrimary
                                }
                                
                                Text {
                                    id: dateText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Qt.formatDateTime(new Date(), "yyyy, MMM d")
                                    font.pixelSize: 9
                                    color: theme.textSecondary
                                    opacity: 0.7
                                }
                            }
                            
                            Timer {
                                interval: 1000
                                running: true
                                repeat: true
                                onTriggered: {
                                    timeText.text = Qt.formatDateTime(new Date(), "h:mm AP")
                                    dateText.text = Qt.formatDateTime(new Date(), "yyyy, MMM d")
                                }
                            }
                        }
                    }  
                }  
            }
        }
    }
    
    // ===== COMPONENTS =====
    
    component DockButton: MouseArea {
        id: btn
        property string iconPath: ""
        property string tooltipText: ""
        
        width: 42
        height: 42
        hoverEnabled: true
        
        Rectangle {
            id: btnBg
            anchors.fill: parent
            radius: 10
            color: parent.containsMouse ? (theme.isDarkMode ? "#18FFFFFF" : "#18000000") : "transparent"
            
            Behavior on color {
                ColorAnimation { duration: 200; easing.type: Easing.OutQuart }
            }
            
            scale: parent.pressed ? 0.92 : (parent.containsMouse ? 1.08 : 1.0)
            
            Behavior on scale {
                NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }
            
            Image {
                id: launcherIcon
                anchors.centerIn: parent
                width: 24
                height: 24
                source: btn.iconPath
                sourceSize: Qt.size(128, 128)
                smooth: true
                antialiasing: true
                mipmap: true
                visible: theme.isDarkMode
            }

            ColorOverlay {
                anchors.fill: launcherIcon
                source: launcherIcon
                color: '#5b000000' 
                visible: !theme.isDarkMode
            }
        }
        
        // Tooltip
        Rectangle {
            id: tooltip
            visible: parent.containsMouse && tooltipText !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 12
            
            width: tooltipLabel.implicitWidth + 16
            height: 26
            radius: 6
            color: theme.isDarkMode ? "#F01a1a1a" : "#F0f5f5f5"
            
            opacity: parent.containsMouse ? 1.0 : 0.0
            scale: parent.containsMouse ? 1.0 : 0.9
            
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
            }
            
            Behavior on scale {
                NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }
            
            transform: Translate {
                y: parent.containsMouse ? 0 : 4
                Behavior on y {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
                }
            }
            
            Text {
                id: tooltipLabel
                anchors.centerIn: parent
                text: btn.tooltipText
                color: theme.textPrimary
                font.pixelSize: 10
                font.weight: Font.Medium
            }
        }
    }
    
    component DockAppIcon: MouseArea {
        id: appIcon
        property string iconName: ""
        property string appName: ""
        property bool isActive: false
        
        width: 46
        height: 46
        hoverEnabled: true
        
        Rectangle {
            id: iconBg
            anchors.fill: parent
            radius: 10
            color: parent.containsMouse ? (theme.isDarkMode ? "#18FFFFFF" : "#18000000") : "transparent"
            
            Behavior on color {
                ColorAnimation { duration: 200; easing.type: Easing.OutQuart }
            }
            
            scale: parent.pressed ? 0.88 : (parent.containsMouse ? 1.12 : 1.0)
            
            Behavior on scale {
                NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }
            
            // High-res icon - NO layer effects
            Image {
                id: appIconImg
                anchors.centerIn: parent
                width: 24
                height: 24
                source: "image://icon/" + appIcon.iconName
                sourceSize: Qt.size(128, 128)
                smooth: true
                antialiasing: true
                mipmap: true
                cache: true
                visible: theme.isDarkMode
            }

            ColorOverlay {
                anchors.fill: appIconImg
                source: appIconImg
                color: '#25000000' // Subtler tint for colorful app icons
                visible: !theme.isDarkMode
            }
            
            // Active indicator
            Rectangle {
                visible: appIcon.isActive
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                width: 4
                height: 4
                radius: 2
                color: theme.isDarkMode ? "#FFFFFF" : "#000000"
                opacity: 0.8
            }
        }
        
        // Tooltip
        Rectangle {
            visible: parent.containsMouse && appName !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 12
            
            width: appNameLabel.implicitWidth + 16
            height: 26
            radius: 6
            color: theme.isDarkMode ? "#F01a1a1a" : "#F0f5f5f5"
            
            opacity: parent.containsMouse ? 1.0 : 0.0
            scale: parent.containsMouse ? 1.0 : 0.9
            
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
            }
            
            Behavior on scale {
                NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }
            
            transform: Translate {
                y: parent.containsMouse ? 0 : 4
                Behavior on y {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
                }
            }
            
            Text {
                id: appNameLabel
                anchors.centerIn: parent
                text: appIcon.appName
                color: theme.textPrimary
                font.pixelSize: 10
                font.weight: Font.Medium
            }
        }
    }
}

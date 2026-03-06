import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import "lib" as Lib
import "dock" as Dock
import "desktop" as Desktop
import "hub" as SystemHub

ShellRoot {
    Variants {
        model: Quickshell.screens
        Scope {
            id: v
            property var modelData
            
            Lib.ThemeEngine {
                id: screenTheme
            }
            
            // Screen Border
            Desktop.ScreenBorder {
                id: border
                screen: v.modelData
                visible: true
                theme: screenTheme
                forceAlwaysVisible: false  // <-- Change this to make borders always visible
            }
            
            // Taskbar
            Desktop.Taskbar {
                id: taskbar
                screen: v.modelData
                
                onHasWindowsChanged: {
                    border.setTopSidesVisible(!hasWindows)
                }
            }
            
            // The Hub Window
            SystemHub.HubWindow {
                id: hubWindow
                screen: v.modelData
                visible: false 
            }

            Lib.BrightnessOSD {
                id: brightnessOsd
                theme: screenTheme
                screen: v.modelData
            }
            Lib.VolumeOSD {
                theme: screenTheme
                screen: v.modelData
            }
            Lib.ThemeOSD {
                theme: screenTheme
                screen: v.modelData
            }
            
            // App Drawer (Dock Mode)
            Dock.Drawer {
                id: appDrawer
                isDarkMode: screenTheme.isDarkMode 
            }
            
            // Helper function to toggle the hub and manage focus
            function toggleHub() {
                hubWindow.visible = !hubWindow.visible
                if (hubWindow.visible) hubWindow.forceActiveFocus()
            }

            //  Global Shortcut listener for Hyprland bindings
            GlobalShortcut {
                name: "hubToggle"
                description: "Toggle hub"
                onPressed: toggleHub()
            }
            
            // Signal Connections
            Connections {
                target: taskbar
                
                // Launcher Click (Dock vs Workspace)
                function onLauncherClicked() {
                    if (taskbar.isDockMode) {
                        appDrawer.toggle()
                    } else {
                        Quickshell.execDetached(["bash", "-c", 
                            "pkill -x rofi || " + (screenTheme.isDarkMode ? 
                            "~/.config/rofi/wide.sh" : 
                            "~/.config/rofi/wide_light.sh")])
                    }
                }
                
                // Clock Click --> Toggle Hub
                function onRequestHubToggle() {
                    toggleHub()
                }
            }
        }
    }
}
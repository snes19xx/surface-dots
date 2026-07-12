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

            // Wide App Drawer (Workspace Mode) — rofi replacement
            Dock.WideDrawer {
                id: wideDrawer
                theme: screenTheme
            }
            
            // Helper function to toggle the hub and manage focus
            function toggleHub() {
                if (hubWindow.visible) {
                    // Route through closeAll() so the exit animation plays before hiding
                    hubWindow.closeAll()
                } else {
                    // HubWindow.onVisibleChanged grabs keyboard focus on its inner
                    // Item; PanelWindow itself has no forceActiveFocus().
                    hubWindow.visible = true
                }
            }

            //  Global Shortcut listener for Hyprland bindings
            GlobalShortcut {
                name: "hubToggle"
                description: "Toggle hub"
                onPressed: toggleHub()
            }

            // Toggle the wide app drawer (bind SUPER+R in Hyprland)
            GlobalShortcut {
                name: "drawerToggle"
                description: "Toggle app drawer"
                onPressed: wideDrawer.toggle()
            }
            
            // Signal Connections
            Connections {
                target: taskbar
                
                // Launcher Click (Dock vs Workspace)
                function onLauncherClicked() {
                    if (taskbar.isDockMode) {
                        appDrawer.toggle()
                    } else {
                        wideDrawer.toggle()
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
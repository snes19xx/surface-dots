import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import "lib" as Lib
import "bar" as Bar
import "hub" as Hub

ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: v
            property var modelData

            // ----Theme engine shared by all per-screen components-----------------------------------------------
            property bool _isDarkMode: true
            readonly property string _themeModePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"

            FileView {
                id: themeModeFile
                path:         v._themeModePath
                watchChanges: true
                preload:      true
                onLoaded:      v._isDarkMode = (String(text() || "").trim().toLowerCase() !== "light")
                onTextChanged: v._isDarkMode = (String(text() || "").trim().toLowerCase() !== "light")
                onFileChanged: reload()
                onLoadFailed:  v._isDarkMode = true
            }
            // -----------------------------------------------------------------------------------------------------

            Lib.ThemeEngine {
                id: screenTheme
                isDarkMode: v._isDarkMode
            }

            Hub.HubWindow {
                id: hub
                screen: v.modelData
                visible: false
            }

            Bar.Bar {
                id: bar
                screen: v.modelData
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

            function toggleHub() {
                hub.visible = !hub.visible
                if (hub.visible) hub.forceActiveFocus()
            }

            Connections {
                target: bar
                function onRequestHubToggle() {
                    toggleHub()
                }
            }

            GlobalShortcut {
                name: "hubToggle"
                description: "Toggle hub"
                onPressed: toggleHub()
            }
        }
    }
}

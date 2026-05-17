import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

//---------------------------------------------------------------------------------------------------------------------------
    // CONFIGURATION

    
    // Path to the theme sitcher shell script
    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/task-bar/utils/theme-mode.sh"
    
    // Path to the state file (Must match what is inside the shell script!)
    readonly property string statePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"

    // The Output Property
    property bool isDarkMode: true
    
    // WATCHER for changes made by the theme script

    property bool _isToggling: false
    FileView {
        id: watcher
        path: root.statePath
        watchChanges: true
        preload: true
        onFileChanged: reload()
        
        function updateTheme() {
            // Skip update if in the middle of a manual toggle
            if (root._isToggling) {
                console.log("[ThemeEngine] Skipping update (toggle in progress)")
                return
            }
            
            // get the file content
            var content = String(text() || "").trim().toLowerCase()
            console.log("[ThemeEngine] File content:", content)
            
            // Update theme state based on the content
            root.isDarkMode = (content !== "light")
            
            console.log("[ThemeEngine] isDarkMode set to:", root.isDarkMode)
        }
        
        onTextChanged: updateTheme()
        onLoaded: updateTheme()
    }
    
    // Timer to reset the toggle flag
    Timer {
        id: toggleTimer
        interval: 500
        onTriggered: root._isToggling = false
    }

    // TOGGLE: Updates immediately and triggers system change
    function toggle() {
        var next = root.isDarkMode ? "light" : "dark"
        console.log("[ThemeEngine] Toggling to:", next)
        
        root._isToggling = true
        
        // Update qs state immediatel
        root.isDarkMode = (next === "dark")
        console.log("[ThemeEngine] isDarkMode immediately set to:", root.isDarkMode)
        
        // update system theme
        Quickshell.execDetached(["bash", root.scriptPath, next])
        
        // Reset flag
        toggleTimer.restart()
    }
//---------------------------------------------------------------------------------------------------------------------------
    // THEME VALUES (Colors)
    
    // Surfaces
    readonly property color bgMain: isDarkMode ? '#141719' : '#F0ECE6'
    readonly property color bgCard: isDarkMode ? "#1e2326" : '#E3DED6'
    readonly property color bgItem: isDarkMode ? "#2d353b" : Qt.rgba(0, 0, 0, 0.05)
    readonly property color bgItemHover: isDarkMode ? "#374145" : Qt.rgba(0, 0, 0, 0.08)
    readonly property color bgWidget: isDarkMode ? "#1e2326" : "#E3DED6"

    // Text
    readonly property color textPrimary: isDarkMode ? '#dde5dfc5' : '#252E33'
    readonly property color textSecondary: isDarkMode ? "#9da9a0" : "#546670"
    readonly property color textOnAccent: isDarkMode ? "#232a2e" : "#F0ECE6"
    readonly property color textOnAccent2: isDarkMode ? '#b0e5dfc5' : '#262420'

    // Accents
    readonly property color accent: isDarkMode ? "#99a7c080" : "#4A6B70"
    readonly property color accentBlue: "#7AA1A6"
    readonly property color accentRed: isDarkMode ? "#e67e80" : '#c74042'
    readonly property color accentSlider: isDarkMode ? "#83C092" : "#4F6B5B"
    readonly property color accentSlider2: isDarkMode ? "#f1af97" : '#d39984'
    

    // Misc
    readonly property color border: isDarkMode ? "#70a7c080" : "#40A65046"
    readonly property color outline: isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.10)
    readonly property color subtleFill: isDarkMode ? Qt.rgba(1,1,1,0.05) : Qt.rgba(0,0,0,0.05)
    readonly property color subtleFillHover: isDarkMode ? Qt.rgba(1,1,1,0.15) : Qt.rgba(0,0,0,0.10)
    readonly property color hoverSpotlight: isDarkMode ? Qt.rgba(1,1,1,0.14) : Qt.rgba(0,0,0,0.10)

    // Sizing
    readonly property int radiusOuter: 12
    readonly property int radiusInner: 16
    readonly property int padCard: 12
    readonly property int gapCard: 10
    readonly property int btnH: 54
    readonly property int sliderH: 24

    // Fonts
    readonly property string textFont: "Manrope"
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    // Weather
    readonly property color weatherIcon: isDarkMode ? "#9da9a0" : "#3c4841"
}
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope { // <--- CHANGED from QtObject to Scope
    id: root

    // --- FILE I/O ---
    property string configPath: Quickshell.env("HOME") + "/.config/quickshell/settings.json"
    
    // --- STATE PROPERTIES ---
    // Bar / Dock
    property bool barForceWorkspaceMode: false
    property bool barShowBattery: true
    property bool barShowTray: true
    property int barHeight: 50
    property int iconSize: 24

    // Desktop
    property bool showScreenBorders: true
    property string desktopMode: "snes" // "snes" or "preview"
    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    // Hub
    property int maxEvents: 1
    property bool useCustomColors: false
    property color customAccent: "#7AA1A6"
    property color customBg: "#141719"

    // Shaders
    property string currentShader: "none" // "none", "reading", "crt", "main"

    // --- PERSISTENCE ---
    function save() {
        var data = {
            barForceWorkspaceMode: root.barForceWorkspaceMode,
            barShowBattery: root.barShowBattery,
            barShowTray: root.barShowTray,
            barHeight: root.barHeight,
            iconSize: root.iconSize,
            showScreenBorders: root.showScreenBorders,
            desktopMode: root.desktopMode,
            maxEvents: root.maxEvents,
            useCustomColors: root.useCustomColors,
            customAccent: String(root.customAccent),
            customBg: String(root.customBg),
            currentShader: root.currentShader
        }
        configFile.text = JSON.stringify(data, null, 4)
    }

    function load() {
        try {
            var content = configFile.text
            if (!content) return
            var data = JSON.parse(content)
            
            if (data.barForceWorkspaceMode !== undefined) root.barForceWorkspaceMode = data.barForceWorkspaceMode
            if (data.barShowBattery !== undefined) root.barShowBattery = data.barShowBattery
            if (data.barShowTray !== undefined) root.barShowTray = data.barShowTray
            if (data.barHeight !== undefined) root.barHeight = data.barHeight
            if (data.iconSize !== undefined) root.iconSize = data.iconSize
            if (data.showScreenBorders !== undefined) root.showScreenBorders = data.showScreenBorders
            if (data.desktopMode !== undefined) root.desktopMode = data.desktopMode
            if (data.maxEvents !== undefined) root.maxEvents = data.maxEvents
            if (data.useCustomColors !== undefined) root.useCustomColors = data.useCustomColors
            if (data.customAccent !== undefined) root.customAccent = data.customAccent
            if (data.customBg !== undefined) root.customBg = data.customBg
            if (data.currentShader !== undefined) root.currentShader = data.currentShader
        } catch (e) {
            console.log("Error loading settings:", e)
        }
    }

    // This was causing the error because QtObject can't hold children
    FileView {
        id: configFile
        path: root.configPath
        preload: true
        onLoaded: root.load()
    }
}
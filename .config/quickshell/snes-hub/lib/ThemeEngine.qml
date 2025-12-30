import QtQuick
import "../theme.js" as Theme // Dark-mode

QtObject {
    id: root
    property bool isDarkMode: true
    
    // 1) Surfaces
    readonly property color bgMain: isDarkMode ? "#141719" : "#a6b0a0"

    // Card + item surfaces 
    readonly property color bgCard: isDarkMode ? Theme.bgCard : "#edc5c6b0"
    readonly property color bgItem: isDarkMode ? Theme.bgItem : Qt.rgba(0, 0, 0, 0.05)
    readonly property color bgWidget: isDarkMode ? Theme.bgItem : Qt.rgba(0, 0, 0, 0.05)

    // 2) Text
    readonly property color textPrimary: isDarkMode ? Theme.fgMain : "#3c4841"
    readonly property color textSecondary: isDarkMode ? Theme.fgMuted : "#232a23"
    readonly property color textOnAccent: isDarkMode ? Theme.fgOnAccent : '#f0f2d4'

    // 3) Accents
    readonly property color accent: isDarkMode ? Theme.accent : '#3c4841'
    readonly property color accentSlider: isDarkMode ? "#83C092" : "#273018"

    // 4) Lines, hovers, misc
    readonly property color border: isDarkMode ? "#70a7c080" : '#b9566a35'

    // General outlines used by small controls (avatar ring, tiny pills, etc.)
    readonly property color outline: isDarkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)

    // Subtle fills for small buttons
    readonly property color subtleFill: isDarkMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color subtleFillHover: isDarkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color accentRed: isDarkMode ? Theme.accentRed : "#7a2a2a"


    // Hover spotlight 
    readonly property color hoverSpotlight: isDarkMode ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.10)
}

import QtQuick

QtObject {
    id: root
    property bool isDarkMode: true

    // Sizing & Fonts 
    readonly property int    radiusOuter: 24
    readonly property int    radiusInner: 16
    readonly property int    padCard:     12
    readonly property int    gapCard:     10
    readonly property int    btnH:        54
    readonly property int    sliderH:     24
    readonly property string textFont:    "Manrope"
    readonly property string iconFont:    "JetBrainsMono Nerd Font"

    // 1) Surfaces 
    readonly property color bgPanel:     isDarkMode ? Qt.rgba(20/255, 23/255, 25/255, 0.88)
                                                    : Qt.rgba(237/255, 197/255, 198/255, 0.69)
    readonly property color bgMain:      isDarkMode ? "#141719"  : "#a6b0a0"
    readonly property color bgCard:      isDarkMode ? "#1e2326"  : "#edc5c6b0"
    readonly property color bgItem:      isDarkMode ? "#2d353b"  : Qt.rgba(0, 0, 0, 0.05)
    readonly property color bgItemHover: isDarkMode ? "#374145"  : Qt.rgba(0, 0, 0, 0.08)
    readonly property color bgWidget:    isDarkMode ? "#2d353b"  : Qt.rgba(0, 0, 0, 0.05)
    readonly property color bgOSD:       isDarkMode ? '#f9515451': '#f9c5c6b0'

    // 2) Text 
    readonly property color textPrimary:   isDarkMode ? "#d3c6aa" : "#3c4841"
    readonly property color textSecondary: isDarkMode ? "#9da9a0" : "#232a23"
    readonly property color textOnAccent:  isDarkMode ? "#232a2e" : "#f0f2d4"
    readonly property color textOSD:       isDarkMode ? '#a7b3aa' : '#5f7b5f'

    // 3) Accents 
    readonly property color accent:        isDarkMode ? "#a7c080" : "#3c4841"
    readonly property color accentSlider:  isDarkMode ? "#83C092" : "#273018"
    readonly property color accentBlue:    "#7AA1A6"
    readonly property color accentRed:     isDarkMode ? "#e67e80" : "#7a2a2a"
    readonly property color accentSlider2: isDarkMode ? "#f1af97" : "#d39984"

    // 4) Lines, hovers, misc 
    readonly property color border:          isDarkMode ? "#70a7c080" : "#b9566a35"
    readonly property color outline:         isDarkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color subtleFill:      isDarkMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color subtleFillHover: isDarkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color hoverSpotlight:  isDarkMode ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.10)

    // 5) Weather
    readonly property color weatherColor: isDarkMode ? "#9da9a0" : "#3c4841"
}

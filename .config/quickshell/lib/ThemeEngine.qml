import QtQuick

QtObject {
    id: root

    // Follows the shared state by default; assign to pin an instance to one mode
    property bool isDarkMode: ThemeState.isDarkMode
    function toggle() { ThemeState.toggle() }

    // Surfaces
    function _elevate(delta) {
        var h = bgMain.hsvHue < 0 ? 0 : bgMain.hsvHue
        var v = bgMain.hsvValue + (isDarkMode ? delta : -delta)
        return Qt.hsva(h, bgMain.hsvSaturation, Math.max(0, Math.min(1, v)), bgMain.a)
    }

    readonly property color bgMain: Configuration.useCustomBg
        ? (isDarkMode ? Configuration.customBgDark : Configuration.customBgLight)
        : (isDarkMode ? "#141719" : "#F0ECE6")
    readonly property color bgCard: Configuration.useCustomBg
        ? _elevate(0.051)
        : (isDarkMode ? "#1e2326" : "#E3DED6")
    readonly property color bgItem: Configuration.useCustomBg
        ? _elevate(isDarkMode ? 0.133 : 0.095)
        : (isDarkMode ? "#2d353b" : Qt.rgba(0, 0, 0, 0.05))
    readonly property color bgItemHover: Configuration.useCustomBg
        ? _elevate(isDarkMode ? 0.173 : 0.122)
        : (isDarkMode ? "#374145" : Qt.rgba(0, 0, 0, 0.08))
    readonly property color bgWidget: bgCard

    // Text
    readonly property color textPrimary:   isDarkMode ? "#dde5dfc5" : "#252E33"
    readonly property color textSecondary: isDarkMode ? "#9da9a0"   : "#546670"
    readonly property color textOnAccent:  isDarkMode ? "#232a2e"   : "#F0ECE6"

    // Accents
    readonly property color customAccent:
        isDarkMode ? Configuration.customAccentDark : Configuration.customAccentLight
    readonly property color accent: Configuration.useCustomAccent
        ? customAccent
        : (isDarkMode ? "#99a7c080" : "#4A6B70")
    readonly property color accentBlue: Configuration.useCustomAccent
        ? customAccent
        : "#7AA1A6"
    readonly property color accentRed:     isDarkMode ? "#e67e80" : "#c74042"
    readonly property color accentSlider:  isDarkMode ? "#83C092" : "#4F6B5B"
    readonly property color accentSlider2: isDarkMode ? "#f1af97" : "#d39984"

    // Lines and hovers
    readonly property color border:          isDarkMode ? "#70a7c080"          : "#40A65046"
    readonly property color outline:         isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.10)
    readonly property color subtleFill:      isDarkMode ? Qt.rgba(1,1,1,0.05) : Qt.rgba(0,0,0,0.05)
    readonly property color subtleFillHover: isDarkMode ? Qt.rgba(1,1,1,0.15) : Qt.rgba(0,0,0,0.10)
    readonly property color hoverSpotlight:  isDarkMode ? Qt.rgba(1,1,1,0.14) : Qt.rgba(0,0,0,0.10)

    // Sizing
    readonly property int radiusOuter: 12
    readonly property int radiusInner: 16
    readonly property int padCard:     12
    readonly property int gapCard:     10
    readonly property int btnH:        54
    readonly property int sliderH:     24

    // Used by the top-style calendar card
    readonly property color weatherColor: isDarkMode ? "#9da9a0" : "#3c4841"

    readonly property string textFont: "Manrope"
    readonly property string iconFont: "JetBrainsMono Nerd Font"
}

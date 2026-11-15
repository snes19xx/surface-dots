import QtQuick

QtObject {
    id: root

    // Follows the shared state by default; assign to pin an instance to one mode
    property bool isDarkMode: ThemeState.isDarkMode
    function toggle() { ThemeState.toggle() }

    // Surfaces
    function _elevate(delta) {
        var b = _bgMainTarget
        var h = b.hsvHue < 0 ? 0 : b.hsvHue
        var v = b.hsvValue + (isDarkMode ? delta : -delta)
        return Qt.hsva(h, b.hsvSaturation, Math.max(0, Math.min(1, v)), b.a)
    }

    // wallpaper colour if there is one, otherwise the old one
    readonly property bool wp: Configuration.useWallpaperColors && PaletteService.ready
    function _w(role, fallback) {
        var c = wp ? PaletteService.role(role, isDarkMode) : ""
        return c !== "" ? c : fallback
    }

    // the _ copies do the fade, the public names further down just point at them.
    // _elevate reads the target, otherwise the other surfaces chase the fade every frame
    readonly property color _bgMainTarget: _w("surface", Configuration.useCustomBg
        ? (isDarkMode ? Configuration.customBgDark : Configuration.customBgLight)
        : (isDarkMode ? "#141719" : "#F0ECE6"))
    property color _bgMain: _bgMainTarget
    property color _bgCard: _w("surface_container", Configuration.useCustomBg
        ? _elevate(0.051)
        : (isDarkMode ? "#1e2326" : "#E3DED6"))
    property color _bgItem: _w("surface_container_high", Configuration.useCustomBg
        ? _elevate(isDarkMode ? 0.133 : 0.095)
        : (isDarkMode ? "#2d353b" : Qt.rgba(0, 0, 0, 0.05)))
    property color _bgItemHover: _w("surface_container_highest", Configuration.useCustomBg
        ? _elevate(isDarkMode ? 0.173 : 0.122)
        : (isDarkMode ? "#374145" : Qt.rgba(0, 0, 0, 0.08)))
    property color _textPrimary:   _w("on_surface", isDarkMode ? "#dde5dfc5" : "#252E33")
    property color _textSecondary: _w("on_surface_variant", isDarkMode ? "#9da9a0" : "#546670")
    property color _textOnAccent:  _w("on_primary", isDarkMode ? "#232a2e" : "#F0ECE6")
    readonly property color _accentTarget: _w("primary", Configuration.useCustomAccent
        ? customAccent
        : (isDarkMode ? "#99a7c080" : "#4A6B70"))
    property color _accent: _accentTarget
    property color _accentBlue: _w("primary", Configuration.useCustomAccent
        ? customAccent
        : "#7AA1A6")
    property color _accentRed:     _w("error", isDarkMode ? "#e67e80" : "#c74042")
    property color _accentSlider:  _w("tertiary", isDarkMode ? "#83C092" : "#4F6B5B")
    property color _accentSlider2: _w("secondary", isDarkMode ? "#f1af97" : "#d39984")
    property color _outline: _w("outline_variant", isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.10))
    property color _barAccent: _w("primary", Configuration.taskbarAccent)

    Behavior on _bgMain        { ColorAnimation { duration: 300 } }
    Behavior on _bgCard        { ColorAnimation { duration: 300 } }
    Behavior on _bgItem        { ColorAnimation { duration: 300 } }
    Behavior on _bgItemHover   { ColorAnimation { duration: 300 } }
    Behavior on _textPrimary   { ColorAnimation { duration: 300 } }
    Behavior on _textSecondary { ColorAnimation { duration: 300 } }
    Behavior on _textOnAccent  { ColorAnimation { duration: 300 } }
    Behavior on _accent        { ColorAnimation { duration: 300 } }
    Behavior on _accentBlue    { ColorAnimation { duration: 300 } }
    Behavior on _accentRed     { ColorAnimation { duration: 300 } }
    Behavior on _accentSlider  { ColorAnimation { duration: 300 } }
    Behavior on _accentSlider2 { ColorAnimation { duration: 300 } }
    Behavior on _outline       { ColorAnimation { duration: 300 } }
    Behavior on _barAccent     { ColorAnimation { duration: 300 } }

    // for the colour pickers, otherwise they read a colour halfway through the fade
    readonly property color bgMainTarget:  _bgMainTarget
    readonly property color accentTarget:  _accentTarget

    readonly property color bgMain:        _bgMain
    readonly property color bgCard:        _bgCard
    readonly property color bgItem:        _bgItem
    readonly property color bgItemHover:   _bgItemHover
    readonly property color bgWidget: bgCard

    // Text
    readonly property color textPrimary:   _textPrimary
    readonly property color textSecondary: _textSecondary
    readonly property color textOnAccent:  _textOnAccent

    // Accents
    readonly property color customAccent:
        isDarkMode ? Configuration.customAccentDark : Configuration.customAccentLight
    readonly property color accent:        _accent
    readonly property color accentBlue:    _accentBlue
    readonly property color accentRed:     _accentRed
    readonly property color accentSlider:  _accentSlider
    readonly property color accentSlider2: _accentSlider2
    // the bars use this instead of Configuration.taskbarAccent
    readonly property color barAccent:     _barAccent

    // Lines and hovers
    readonly property color border:          isDarkMode ? "#70a7c080"          : "#40A65046"
    readonly property color outline:         _outline
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

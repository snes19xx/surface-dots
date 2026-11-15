pragma Singleton
import QtQuick

// Cassini-style popup tokens, coloured from the passed theme. toast* and osd* names belong to one surface.
QtObject {
    // no pills or circles
    readonly property int radiusCard: 6
    readonly property int radiusInner: 3

    readonly property string serif: "Newsreader"

    // sans fonts follow theme.textFont
    function label(theme) {
        return Qt.font({ family: theme.textFont, pixelSize: 11, letterSpacing: 1.2, weight: Font.DemiBold })
    }
    readonly property font title: Qt.font({ family: serif, pixelSize: 16, weight: Font.Medium, letterSpacing: 0 })
    function body(theme) {
        return Qt.font({ family: theme.textFont, pixelSize: 13, weight: Font.Medium })
    }
    function detail(theme) {
        return Qt.font({ family: theme.textFont, pixelSize: 11, weight: Font.Medium })
    }
    function action(theme) {
        return Qt.font({ family: theme.textFont, pixelSize: 12, weight: Font.DemiBold })
    }
    // Manrope's own leading is ~1.37
    readonly property real bodyLine: 1.0
    readonly property real detailOpacity: 0.85

    // same as Cassini's border
    function hairline(theme) { return theme.isDarkMode ? 0.5 : 1 }
    // one device pixel, stays crisp
    readonly property int rule: 1

    // same as Cassini's shadow
    readonly property int shadowBlurMax: 64
    readonly property real shadowBlur: Math.min(1, 16 * 1.7 / 64)
    readonly property int shadowOffset: 8
    function shadowColor(theme) { return Qt.rgba(0, 0, 0, theme.isDarkMode ? 0.55 : 0.30) }
    // window clips the shadow otherwise
    readonly property int shadowPad: 52

    // opaque, or shadow shows through
    function surface(theme) {
        return Qt.tint(theme.isDarkMode ? "#000000" : "#ffffff", theme.bgMain)
    }
    function solid(theme, c) { return Qt.tint(surface(theme), c) }
    function frame(theme, hot, color) { return hot ? solid(theme, color) : theme.outline }

    readonly property int toastPadX: 14
    readonly property int toastPadY: 12
    readonly property int toastIconSize: 18
    readonly property int toastImageSize: 44
    readonly property int toastButtonHeight: 26
    readonly property int toastButtonPadX: 12

    readonly property int osdWidth: 316
    readonly property int osdPadX: 16
    readonly property int osdPadY: 14
    readonly property int osdIconSize: 20

    readonly property font osdValue: Qt.font({ family: serif, pixelSize: 26, weight: Font.Normal })
    readonly property font osdValueWord: Qt.font({ family: serif, pixelSize: 20, weight: Font.Normal })
    function osdUnit(theme) {
        return Qt.font({ family: theme.textFont, pixelSize: 11, weight: Font.Medium })
    }
    function osdNumeral(theme) {
        return Qt.font({ family: theme.textFont, pixelSize: 10, weight: Font.Medium })
    }
    readonly property real osdUnitGap: 2

    readonly property int osdRulerHeight: 30
    readonly property int osdBaseY: 12
    readonly property int osdTickMajor: 8
    readonly property int osdTickMinor: 4
    readonly property int osdMarkerWidth: 7
    readonly property int osdMarkerHeight: 6
    readonly property int osdLevelLine: 2
    // muted dims line and marker
    readonly property real osdDimOpacity: 0.6
    function osdTick(theme) { return Qt.alpha(theme.textSecondary, 0.55) }
}

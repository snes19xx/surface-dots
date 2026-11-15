pragma Singleton
import QtQuick

// Cassini-style tokens for toasts and OSDs. Colours always come from the passed theme.
QtObject {
    // no pills or circles
    readonly property int radiusCard: 6
    readonly property int radiusInner: 3

    // serif for headlines only
    readonly property string serif: "Newsreader"
    readonly property string sans: "Manrope"

    readonly property font label: Qt.font({ family: sans, pixelSize: 11, letterSpacing: 1.2, weight: Font.DemiBold })
    readonly property font title: Qt.font({ family: serif, pixelSize: 16, weight: Font.Medium, letterSpacing: 0 })
    readonly property font value: Qt.font({ family: serif, pixelSize: 26, weight: Font.Normal })
    readonly property font valueWord: Qt.font({ family: serif, pixelSize: 20, weight: Font.Normal })
    readonly property font unit: Qt.font({ family: sans, pixelSize: 11, weight: Font.Medium })
    readonly property font body: Qt.font({ family: sans, pixelSize: 13, weight: Font.Medium })
    readonly property font detail: Qt.font({ family: sans, pixelSize: 11, weight: Font.Medium })
    readonly property font numeral: Qt.font({ family: sans, pixelSize: 10, weight: Font.Medium })
    readonly property font action: Qt.font({ family: sans, pixelSize: 12, weight: Font.DemiBold })
    readonly property real bodyLine: 1.4
    readonly property real detailOpacity: 0.85
    readonly property real unitGap: 2

    // same as Cassini's border
    function hairline(theme) { return theme.isDarkMode ? 0.5 : 1 }

    // same as Cassini's shadow
    readonly property int shadowBlurMax: 64
    readonly property real shadowBlur: Math.min(1, 16 * 1.7 / 64)
    readonly property int shadowOffset: 8
    function shadowColor(theme) { return Qt.rgba(0, 0, 0, theme.isDarkMode ? 0.55 : 0.30) }

    // opaque, or shadow shows through
    function surface(theme) {
        return Qt.tint(theme.isDarkMode ? "#000000" : "#ffffff", theme.bgMain)
    }
    function solid(theme, c) { return Qt.tint(surface(theme), c) }
    function frame(theme, hot, color) { return hot ? solid(theme, color) : theme.outline }
    function tick(theme) { return Qt.alpha(theme.textSecondary, 0.55) }
}

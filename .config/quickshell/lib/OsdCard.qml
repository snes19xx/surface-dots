import QtQuick

// Picks the Cassini or Rounded card and forwards its interface. Size follows the active card, so window masks do too.
Item {
    id: root

    required property var theme

    property bool shown: false
    property int fadeInMs: 160
    property int fadeOutMs: 320
    property real slideY: 22
    property string label: ""
    property string value: ""
    property string secondary: ""
    property color accentColor: theme.accent
    property string glyph: ""
    property url iconSource: ""

    property bool showLevel: false
    property real level: 0
    property bool dimLevel: false
    property bool dragging: false
    property bool iconClickable: false

    signal levelPressed(real frac)
    signal levelMoved(real frac)
    signal levelReleased()
    signal levelWheeled(int delta)
    signal iconClicked()

    readonly property bool cassini: Configuration.popupStyle !== "rounded"

    function pulse() { if (loader.item) loader.item.pulse() }
    function swap() { if (loader.item) loader.item.swap() }

    width: loader.item ? loader.item.width : 0
    height: loader.item ? loader.item.height : 0

    Loader {
        id: loader
        sourceComponent: root.cassini ? cassiniCard : roundedCard
    }

    Component { id: cassiniCard; OsdCardCassini { theme: root.theme } }
    Component { id: roundedCard; OsdCardRounded { theme: root.theme } }

    Binding { target: loader.item; property: "shown"; value: root.shown }
    Binding { target: loader.item; property: "fadeInMs"; value: root.fadeInMs }
    Binding { target: loader.item; property: "fadeOutMs"; value: root.fadeOutMs }
    Binding { target: loader.item; property: "slideY"; value: root.slideY }
    Binding { target: loader.item; property: "label"; value: root.label }
    Binding { target: loader.item; property: "value"; value: root.value }
    Binding { target: loader.item; property: "secondary"; value: root.secondary }
    Binding { target: loader.item; property: "accentColor"; value: root.accentColor }
    Binding { target: loader.item; property: "glyph"; value: root.glyph }
    Binding { target: loader.item; property: "iconSource"; value: root.iconSource }
    Binding { target: loader.item; property: "showLevel"; value: root.showLevel }
    Binding { target: loader.item; property: "level"; value: root.level }
    Binding { target: loader.item; property: "dimLevel"; value: root.dimLevel }
    Binding { target: loader.item; property: "dragging"; value: root.dragging }
    Binding { target: loader.item; property: "iconClickable"; value: root.iconClickable }

    Connections {
        target: loader.item
        function onLevelPressed(frac) { root.levelPressed(frac) }
        function onLevelMoved(frac) { root.levelMoved(frac) }
        function onLevelReleased() { root.levelReleased() }
        function onLevelWheeled(delta) { root.levelWheeled(delta) }
        function onIconClicked() { root.iconClicked() }
    }
}

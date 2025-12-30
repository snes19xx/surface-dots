import QtQuick 2.15

Row {
    id: dotsRoot
    property int dotCount: 0
    property color dotColor: "#D3C6AA"
    spacing: 12

    Repeater {
        model: dotsRoot.dotCount
        delegate: Rectangle {
            width: 10
            height: 10
            radius: 5
            color: dotsRoot.dotColor
            opacity: 0.95
        }
    }
}

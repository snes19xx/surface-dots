////////////////
// [Stellarium SDDM theme by @snes19xx]
//
// PowerButtons.qml -- 5 of 8 files
// Contains Power button components based on nerdfont glyphs
//
////////////////
import QtQuick 2.15
import QtQuick.Layouts 1.15

Row {
    id: triad
    spacing: 10

    component PowerBtn: Rectangle {
        property string kind: "power"
        property string tooltipText: ""
        signal triggered()

        width: 42; height: 42 
        radius: 6
        color: hov.containsMouse ? Qt.rgba(0.53, 0.69, 0.54, 0.06) : "transparent"
        border.color: hov.containsMouse ? Qt.rgba(0.53, 0.69, 0.54, 0.5) : root.hairline
        border.width: 1
        Behavior on color        { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }


        Text {
            id: iconText
            anchors.centerIn: parent
            font.family: root.fontMono
            font.pixelSize: 22
            renderType: Text.NativeRendering
            color: hov.containsMouse ? root.accent : root.colInkSoft
            text: {
                if (kind === "power") return "\u23fb"
                if (kind === "restart") return "\uead2"
                if (kind === "sleep") return "󰽥"
                return ""
            }
        }

        MouseArea {
            id: hov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.triggered()
        }
    }

    PowerBtn {
        kind: "sleep"; tooltipText: "Sleep"
        onTriggered: { if (typeof sddm !== "undefined") sddm.suspend() }
    }
    PowerBtn {
        kind: "restart"; tooltipText: "Restart"
        onTriggered: { if (typeof sddm !== "undefined") sddm.reboot() }
    }
    PowerBtn {
        kind: "power"; tooltipText: "Power off"
        onTriggered: { if (typeof sddm !== "undefined") sddm.powerOff() }
    }
}

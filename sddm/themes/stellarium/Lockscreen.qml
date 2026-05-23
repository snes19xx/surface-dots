////////////////
// [Stellarium SDDM theme by @snes19xx]
//
// Lockscreen.qml -- 2 of 8 files
// This is the lockscreen view. It contains the clock, date, and a "press any key" footer.
//
////////////////

import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: lock

    // Inputs
    property date now: new Date()
    signal advance()

    readonly property string fSerif:  root.fontSerif
    readonly property string fItalic: root.fontItalic
    readonly property string fMono:   root.fontMono

    readonly property real padV: Math.max(36, Math.min(72, lock.height * 0.05))
    readonly property real padH: Math.max(36, Math.min(84, lock.width  * 0.05))

    MouseArea {
        anchors.fill: parent
        onClicked: lock.advance()
    }

    // Centered title block 
    Item {
        id: titleBlock
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40 
        width: parent.width - lock.padH * 2
        height: childrenRect.height

        // The clock]] HH : MM, minutes
        Row {
            id: clockRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: lock.width * 0.005
            property real clockPx: Math.max(129, Math.min(209, lock.width * 0.187))

            Text {
                renderType: Text.NativeRendering
                id: hhText
                font.family: lock.fSerif
                font.pixelSize: clockRow.clockPx
                font.weight: Font.Normal
                font.letterSpacing: -clockRow.clockPx * 0.05
                color: root.colInk
                lineHeight: 0.86
                text: Qt.formatTime(lock.now, "HH")
            }
            // :
            Text {
                renderType: Text.NativeRendering
                anchors.baseline: hhText.baseline
                font.family: lock.fSerif
                font.pixelSize: clockRow.clockPx
                font.weight: Font.Light
                color: root.colInkFaint
                lineHeight: 0.86
                text: ":"
            }
            Text {
                renderType: Text.NativeRendering
                anchors.baseline: hhText.baseline
                font.family: lock.fItalic
                font.pixelSize: clockRow.clockPx
                font.italic: true
                font.weight: Font.Light
                color: root.accent
                lineHeight: 0.86
                text: Qt.formatTime(lock.now, "mm")
            }
        }

        // The date 
        Text {
            id: dateText
            renderType: Text.NativeRendering
            anchors.top: clockRow.bottom
            anchors.topMargin: Math.max(22, Math.min(36, lock.height * 0.026))
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: lock.fItalic
            font.italic: true
            font.pixelSize: Math.max(20, Math.min(39, lock.width * 0.0268))
            font.weight: Font.Normal
            color: root.colInkSoft
            horizontalAlignment: Text.AlignHCenter
            // "Saturday, 23 May 2026"
            text: Qt.formatDate(lock.now, "dddd, d MMMM yyyy")
        }
    }

    // Footer
    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: lock.padH
        anchors.rightMargin: lock.padH
        anchors.bottomMargin: lock.padV
        height: 48 

        // Prompt 
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Rectangle {
                width: 18; height: 1
                color: root.accentDeep
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
                text: "press any key, click, or swipe to continue"
                font.family: lock.fItalic
                font.italic: true
                font.pixelSize: 25 
                color: root.colInkSoft
            }
            // Blinking
            Rectangle {
                id: caret
                width: 12; height: 22 
                color: root.accent
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 2
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 1; duration: 0 }
                    PauseAnimation { duration: 580 }
                    NumberAnimation { to: 0; duration: 0 }
                    PauseAnimation { duration: 470 }
                }
            }
        }

        // Powerbuttons
        PowerButtons {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}


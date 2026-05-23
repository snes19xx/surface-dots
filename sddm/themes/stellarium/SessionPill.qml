////////////////
// [Stellarium SDDM theme by @snes19xx]
//
// SessionPill.qml -- 6 of 8 files
// A pill-shaped component for selecting the active session
//
////////////////

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: 100
    height: 35

    property int sessionIndex: (typeof sessionModel !== "undefined") ? sessionModel.lastIndex : 0
    property var fallbackSessions: ["Hyprland", "Plasma"]
    property string currentLabel: {
        if (typeof sessionModel !== "undefined" && sessionModel.count > 0) {
            var idx = sessionModel.index(sessionIndex, 0);
            return sessionModel.data(idx, Qt.DisplayRole) || sessionModel.data(idx, 257) || "Unknown"
        }
        return fallbackSessions[sessionIndex] || "Hyprland"
    }

    signal sessionChanged(int idx)

    Button {
        id: pillBtn
        anchors.centerIn: parent
        padding: 8
        leftPadding: 16; rightPadding: 16
        
        background: Rectangle {
            radius: 4
            color: pillBtn.hovered ? Qt.rgba(236/255, 230/255, 214/255, 0.08) : Qt.rgba(236/255, 230/255, 214/255, 0.05)
            border.color: pillBtn.hovered ? "#87b08a" : Qt.rgba(236/255, 230/255, 214/255, 0.42)
            border.width: 1
        }

        contentItem: Row {
            anchors.centerIn: parent
            spacing: 4
            
            Repeater {
                model: (typeof sessionModel !== "undefined") ? sessionModel.count : root.fallbackSessions.length
                delegate: Rectangle {
                    width: 5; height: 5; radius: 2.5
                    color: index === root.sessionIndex ? "#87b08a" : "#5a5648"
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        onClicked: popup.opened ? popup.close() : popup.open()
    }

    Popup {
        id: popup
        y: -height - 10
        x: (root.width - width) / 2
        width: 240
        padding: 6
        
        background: Rectangle {
            color: Qt.rgba(14/255, 16/255, 18/255, 0.96)
            border.color: Qt.rgba(236/255, 230/255, 214/255, 0.42)
            border.width: 1
            // A blur effect requires QtGraphicalEffects on a ShaderEffectSource.
            // As a fallback, this dark translucent color works well.
        }

        contentItem: ListView {
            id: listView
            implicitHeight: contentHeight
            model: typeof sessionModel !== "undefined" ? sessionModel : root.fallbackSessions
            interactive: false // disable scrolling if few items

            delegate: ItemDelegate {
                width: listView.width
                height: 36
                padding: 10
                leftPadding: 14; rightPadding: 14

                property bool isSelected: index === root.sessionIndex

                background: Rectangle {
                    color: isSelected ? Qt.rgba(135/255, 176/255, 138/255, 0.10) : (hovered ? Qt.rgba(236/255, 230/255, 214/255, 0.04) : "transparent")
                }

                contentItem: Row {
                    spacing: 10
                    Rectangle {
                        width: 5; height: 5; radius: 2.5
                        color: isSelected ? "#87b08a" : "#5a5648" // accent : inkWhisper
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        renderType: Text.NativeRendering
                        text: {
                            if (typeof modelData !== "undefined") return modelData
                            if (typeof name !== "undefined") return name
                            return "Unknown Session"
                        }
                        font.family: root.parent && root.parent.fontMono ? root.parent.fontMono : "JetBrains Mono"
                        font.pixelSize: 11
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.54
                        color: isSelected ? "#87b08a" : "#c8c1b2" // accent : inkSoft
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                onClicked: {
                    root.sessionIndex = index
                    root.sessionChanged(index)
                    popup.close()
                }
            }
        }
    }
}

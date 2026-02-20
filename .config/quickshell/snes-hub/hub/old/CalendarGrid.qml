import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme

Item {
    id: root
    property QtObject theme: null
    readonly property bool themed: theme !== null
    readonly property bool isDark: !themed || (theme.isDarkMode === undefined ? true : theme.isDarkMode)
    property date when: new Date()
    property var cells: []

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    readonly property color _fgOnAccent: (themed && theme.textOnAccent !== undefined) ? theme.textOnAccent : Theme.fgOnAccent
    readonly property color _accent: (themed && theme.accent !== undefined) ? theme.accent : Theme.accent

    readonly property color _headColor: isDark
        ? Qt.rgba(0.62, 0.66, 0.63, 0.8)
        : ((themed && theme.textSecondary !== undefined) ? Qt.rgba(theme.textSecondary.r, theme.textSecondary.g, theme.textSecondary.b, 0.85)
                                                        : Qt.rgba(0, 0, 0, 0.45))

    readonly property color _dayColor: isDark
        ? Qt.rgba(0.62, 0.66, 0.63, 0.9)
        : ((themed && theme.textSecondary !== undefined) ? Qt.rgba(theme.textSecondary.r, theme.textSecondary.g, theme.textSecondary.b, 0.95)
                                                        : Qt.rgba(0, 0, 0, 0.55))

    function rebuild() {
        var d = root.when
        var y = d.getFullYear()
        var m = d.getMonth()
        var today = d.getDate()

        var firstDay = new Date(y, m, 1).getDay()
        var daysInMonth = new Date(y, m + 1, 0).getDate()

        var out = []
        var heads = ["S", "M", "T", "W", "T", "F", "S"]

        for (var i = 0; i < 7; i++) out.push({ kind: "head", t: heads[i] })
        for (i = 0; i < firstDay; i++) out.push({ kind: "blank", t: "" })
        for (i = 1; i <= daysInMonth; i++) out.push({ kind: "day", t: String(i), today: (i === today) })

        root.cells = out
    }

    Component.onCompleted: rebuild()
    onWhenChanged: rebuild()

    GridLayout {
        id: grid
        columns: 7
        rowSpacing: 3
        columnSpacing: 3

        Repeater {
            model: root.cells.length
            delegate: Item {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                property var cell: root.cells[index]

                Text {
                    anchors.centerIn: parent
                    text: cell.t
                    font.family: Theme.textFont
                    font.pixelSize: (cell.kind === "head") ? 9 : 8
                    font.weight: (cell.kind === "head") ? 300 : (cell.today ? 800 : 400)

                    color: (cell.kind === "head")
                        ? root._headColor
                        : (cell.today ? root._fgOnAccent : root._dayColor)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    visible: cell.today === true
                    color: root._accent
                    z: -1
                }
            }
        }
    }
}

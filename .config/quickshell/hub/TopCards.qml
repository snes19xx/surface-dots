import QtQuick
import QtQuick.Layouts
import "top" as Top

// Card set for the top bar: single column, in the order the original top-bar
// hub used. These are that hub's own cards, not the task-bar ones reflowed.
ColumnLayout {
    id: root

    required property QtObject theme
    property bool hubVisible: false
    property bool batteryActive: false

    signal closeRequested()
    signal batteryToggleRequested()
    signal batteryDismissed()

    property alias notifs: notifsCard

    spacing: theme.gapCard

    Top.ButtonsSlidersCard {
        id: buttons
        Layout.fillWidth: true
        active: root.hubVisible
        theme: root.theme
        onCloseRequested: root.closeRequested()
        onBatteryToggleRequested: root.batteryToggleRequested()
    }

    Top.BatteryHealthCard {
        id: battery
        Layout.fillWidth: true
        active: root.batteryActive
        theme: root.theme
        onActiveChanged: if (!active && !root.hubVisible) root.batteryDismissed()
    }

    Top.MediaCard {
        id: media
        Layout.fillWidth: true
        onCloseRequested: root.closeRequested()
    }

    Top.CalendarWeatherCard {
        Layout.fillWidth: true
        active: root.hubVisible
        theme: root.theme
        onCloseRequested: root.closeRequested()
    }

    Top.NotificationsCard {
        id: notifsCard
        Layout.fillWidth: true
        active: root.hubVisible
        compactMode: media.visible || battery.visible
        dndActive: buttons.dnd
        theme: root.theme
    }
}

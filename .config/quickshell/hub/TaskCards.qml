import QtQuick
import QtQuick.Layouts

// Card set for the taskbar: wider panel, calendar and buttons paired across two
// columns, agenda in its own card.
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

    MediaCard {
        id: media
        Layout.fillWidth: true
        theme: root.theme
        onCloseRequested: root.closeRequested()
        radius: 10
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 250
        spacing: root.theme.gapCard

        CalendarWeatherCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            active: root.hubVisible
            theme: root.theme
            onCloseRequested: root.closeRequested()
            radius: 10
        }

        ButtonsSlidersCard {
            id: buttons
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            active: root.hubVisible
            theme: root.theme
            onCloseRequested: root.closeRequested()
            onBatteryToggleRequested: root.batteryToggleRequested()
            radius: 10
        }
    }

    BatteryHealthCard {
        id: battery
        Layout.fillWidth: true
        theme: root.theme
        active: root.batteryActive
        onActiveChanged: if (!active && !root.hubVisible) root.batteryDismissed()
        radius: 10
    }

    Events {
        Layout.fillWidth: true
        active: root.hubVisible
        theme: root.theme
        onCloseRequested: root.closeRequested()
        radius: 10
    }

    NotificationsCard {
        id: notifsCard
        Layout.fillWidth: true
        active: root.hubVisible
        compactMode: media.visible || battery.visible
        dndActive: buttons.dnd
        theme: root.theme
        radius: 10
    }
}

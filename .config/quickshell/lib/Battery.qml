pragma Singleton
import QtQuick
import Quickshell.Services.UPower

QtObject {
    id: root

    readonly property var dev: UPower.displayDevice

    readonly property bool present: dev !== null && dev.isPresent
    readonly property int percent: present ? Math.round(dev.percentage * 100) : 0
    readonly property int state: dev ? dev.state : UPowerDeviceState.Unknown
    // "Fully charged" not the enum's "Fully Charged"
    readonly property string stateText: {
        const s = UPowerDeviceState.toString(state)
        return s.charAt(0) + s.slice(1).toLowerCase()
    }
    readonly property bool charging:
        state === UPowerDeviceState.Charging || state === UPowerDeviceState.FullyCharged
    readonly property bool discharging: state === UPowerDeviceState.Discharging
    readonly property bool plugged: !UPower.onBattery
    readonly property real timeToEmpty: dev ? dev.timeToEmpty : 0
    readonly property real timeToFull: dev ? dev.timeToFull : 0
    readonly property real energyRate: dev ? dev.changeRate : 0
    // health is from actual battery,the display device has none
    readonly property var cell: {
        const list = UPower.devices.values
        for (let i = 0; i < list.length; i++)
            if (list[i].isLaptopBattery) return list[i]
        return null
    }
    readonly property bool healthSupported: cell !== null && cell.healthSupported
    readonly property real healthPercent: healthSupported ? cell.healthPercentage : 0

    // "4.4 hours" like upower prints
    function formatDuration(sec) {
        if (!(sec > 0)) return ""
        if (sec < 3600) return Math.round(sec / 60) + " minutes"
        return (sec / 3600).toFixed(1) + " hours"
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../lib" as Lib
import "../theme.js" as Theme

Lib.Card {
  id: root
  signal closeRequested()
  signal batteryToggleRequested()
  property bool active: true

  property bool autoMode: true
  Component.onCompleted: {
        if (root.autoMode) {
            det("sudo auto-cpufreq --force=reset")
        }
    }

  function sh(cmd) { return ["bash","-lc", cmd] }
  function det(cmd) { Quickshell.execDetached(sh(cmd)) }

  // --- WIFI ---
  Lib.CommandPoll {
    id: wifiOn
    running: root.active && root.visible
    interval: 2500
    command: sh("nmcli -t -f WIFI g 2>/dev/null | head -n1 || true")
    parse: function(o) { return String(o).trim() === "enabled" }
  }

  Lib.CommandPoll {
    id: wifiSSID
    running: root.active && root.visible
    interval: 5000
    command: sh("nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}' || true")
    parse: function(o) {
      var s = String(o).trim() || "WiFi"
      return s.length > 9 ? s.slice(0, 9) : s
    }
  }

  function toggleWifi() {
    var next = !Boolean(wifiOn.value)
    det("nmcli radio wifi " + (next ? "on" : "off"))
  }

  // --- BLUETOOTH ---
  Lib.CommandPoll {
    id: btOn
    running: root.active && root.visible
    interval: 3000
    command: sh("bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/{print $2; exit}' || true")
    parse: function(o) { return String(o).trim() === "yes" }
  }

  Lib.CommandPoll {
    id: btDev
    running: root.active && root.visible
    interval: 3500
    command: sh("bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d' ' -f3- || true")
    parse: function(o) {
      var d = String(o).trim()
      if (d.length > 0) return d.length > 9 ? d.slice(0, 9) : d
      if (btOn.value === false) return "Off"
      return "On"
    }
  }

  function toggleBt() {
    var next = !Boolean(btOn.value)
    det("bluetoothctl power " + (next ? "on" : "off"))
  }

  // --- VOLUME / BRIGHTNESS ---
  Lib.CommandPoll {
    id: volPoll
    running: root.active && root.visible
    interval: 1200
    // Get volume number only
    command: sh("pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -Po '\\d+(?=%)' | head -n1")
    parse: function(o) {
      var n = parseInt(String(o).trim())
      return isFinite(n) ? n : 0
    }
    onUpdated: if (!volS.pressed) volS.value = value
  }

  Lib.CommandPoll {
    id: briPoll
    running: root.active && root.visible
    interval: 1500
    command: sh("brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '% ' || true")
    parse: function(o) {
      var n = Number(String(o).trim())
      return isFinite(n) ? n : 50
    }
    onUpdated: if (!briS.pressed) briS.value = value
  }

// --- CPU GOVERNOR (AUTO-CPUFREQ) ---
  property string cpuGov: "powersave"
  property bool _isChanging: false

  Lib.CommandPoll {
    id: perfPoll
    running: root.active && root.visible && !root._isChanging
    interval: 30000
    command: sh("cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'powersave'")
    parse: function(o) { return String(o).trim() }
    onUpdated: root.cpuGov = value
  }

  Timer {
    id: pollLockout
    interval: 5000
    onTriggered: root._isChanging = false
  }

  function togglePerf() {
    root._isChanging = true
    pollLockout.restart()

    if (root.autoMode) {
      // Auto -> Force Performance
      root.autoMode = false
      root.cpuGov = "performance"
      det("sudo auto-cpufreq --force=performance")
    } else if (root.cpuGov === "performance") {
      // Performance -> Force Powersave
      root.cpuGov = "powersave"
      det("sudo auto-cpufreq --force=powersave")
    } else {
      // Powersave -> Auto (Reset)
      root.autoMode = true
      det("sudo auto-cpufreq --force=reset")
    }
  }

  function getPerfIcon() {
    if (root.autoMode) return "cpu_auto.svg"
    return (root.cpuGov === "performance") ? "cpu_max.svg" : "cpu_powersave.svg"
  }

  function getPerfLabel() {
    if (root.autoMode) return "Auto"
    return (root.cpuGov === "performance") ? "Max" : "Powersave"
  }

  function getPerfColor() {
    if (root.autoMode) {
      return (root.theme && root.theme.isDarkMode !== undefined && !root.theme.isDarkMode)
        ? '#283314' // Hardcoded colors for now
        : (Theme.accent || "#a7c080") // 
    }
    return (root.cpuGov === "performance") ? Theme.accentRed : (root.theme ? root.theme.textPrimary : Theme.fgMain)
  }

  // --- DND ---
  property bool dnd: false

  Lib.CommandPoll {
    id: dndPoll
    running: root.active && root.visible
    interval: 4000
    command: sh("makoctl mode 2>/dev/null || true")
    parse: function(o) { return String(o).includes("do-not-disturb") }
    onUpdated: root.dnd = value
  }

  function toggleDnd() {
    var next = !root.dnd
    root.dnd = next
    det("makoctl mode " + (next ? "-a" : "-r") + " do-not-disturb")
  }

  // --- UI ---
  ColumnLayout {
    spacing: 12
    width: parent.width

    RowLayout {
      spacing: 12
      Layout.fillWidth: true

      Lib.ExpressiveButton {
        theme: root.theme
        icon: wifiOn.value ? "wifi_connected.svg" : "wifi_off.svg"
        label: String(wifiSSID.value || "WiFi")
        active: Boolean(wifiOn.value)
        onClicked: toggleWifi()
        onRightClicked: {
            root.closeRequested()
            det("quickshell -p ~/.config/quickshell/snes-hub/lib/WifiMenu.qml")
        }
        //fixX: -10  (no need for this since I am using svgs as icons)
      }

      Lib.ExpressiveButton {
        theme: root.theme
        icon: !btOn.value ? "bt_off.svg" : (String(btDev.value) !== "On" ? "bt_connected.svg" : "bt_on.svg")
        label: String(btDev.value || "Off")
        active: Boolean(btOn.value)
        onClicked: toggleBt()
        onRightClicked: {
            root.closeRequested()
            det("blueman-manager >/dev/null 2>&1 &")
        }
        //fixX: -5
      }

      Lib.ExpressiveButton {
        theme: root.theme
        icon: root.getPerfIcon()
        label: root.getPerfLabel()
        active: (root.cpuGov === "performance" && !root.autoMode)
        customIconColor: root.getPerfColor()
        hasCustomColor: true
        onClicked: root.togglePerf()
        onRightClicked: root.batteryToggleRequested()
        //fixX: -2
      }

      Lib.ExpressiveButton {
        theme: root.theme
        icon: root.dnd ? "silent.svg" : "notify.svg"
        label: root.dnd ? "Silent" : "Notify"
        active: root.dnd
        onClicked: toggleDnd()
        //fixX: -3
      }
    }

  ColumnLayout {
    spacing: 8
    Layout.fillWidth: true

      Lib.ExpressiveSlider {
        theme: root.theme
        id: briS
        // Logic: 0-39 | 40-74 | 75-100
        icon: {
             if (value < 40) return "bness_less40.svg"
             if (value < 75) return "bness_40to75.svg"
             return "bnessmax.svg"
        }
        from: 0; to: 100
        value: 50
        Layout.fillWidth: true
        accentColor: (root.theme && root.theme.isDarkMode !== undefined && !root.theme.isDarkMode)
            ? root.theme.accentSlider
            : "#83C092"
        onUserChanged: det("brightnessctl set " + Math.round(value) + "%")
      }

      Lib.ExpressiveSlider {
        theme: root.theme
        id: volS
        // Logic: Muted/0 -> mute | Headphones -> headphones | <50 -> 50m | >50 -> 50p
        icon: {
            if (value === 0) return "mute.svg"
            if (volPoll.value.isHeadphones) return "vol_headphones.svg"
            return (value > 50) ? "vol_50p.svg" : "vol_50m.svg"
        }
        from: 0; to: 100
        value: 0
        Layout.fillWidth: true
        accentColor: (root.theme && root.theme.isDarkMode !== undefined && !root.theme.isDarkMode)
            ? root.theme.accentSlider
            : "#83C092"
        onUserChanged: det("pactl set-sink-volume @DEFAULT_SINK@ " + Math.round(value) + "%")
      } 
    }
    
  }
}

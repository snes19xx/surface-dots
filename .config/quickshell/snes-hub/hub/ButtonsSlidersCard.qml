import QtQuick
import QtQuick.Layouts
import Quickshell
import "../lib" as Lib
import "../theme.js" as Theme

Lib.Card {
  id: root
  signal closeRequested()
  property bool active: true

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

  // --- SURFACE PROFILE ---
  property string localPerfState: "balanced"

  Lib.CommandPoll {
    id: perfPoll
    running: root.active && root.visible
    interval: 5000
    command: sh("sudo surface profile get 2>/dev/null || echo 'balanced'")
    parse: function(o) {
      var val = String(o).trim().toLowerCase()
      root.localPerfState = val
      return val
    }
  }

  function cyclePerf() {
    var current = root.localPerfState
    var next = "balanced"
    if (current.includes("low")) next = "balanced"
    else if (current === "balanced") next = "balanced-performance"
    else if (current.includes("balanced-performance")) next = "performance"
    else if (current.includes("performance")) next = "low-power"
    root.localPerfState = next
    det("sudo surface profile set " + next)
  }

  function getPerfIcon() {
    var s = root.localPerfState
    if (s.includes("low")) return ""
    if (s === "balanced") return "󰾅"
    if (s.includes("balanced-performance")) return ""
    if (s.includes("performance")) return ""
    return "󰾅"
  }

  function getPerfLabel() {
    var s = root.localPerfState
    if (s.includes("low")) return "Saver"
    if (s === "balanced") return "Normal"
    if (s.includes("balanced-performance")) return "Optim."
    if (s.includes("performance")) return "Perf"
    return "Normal"
  }

  function isPerfActive() {
    var s = root.localPerfState
    return (s.includes("low") || s === "balanced")
  }

  function getPerfColor() {
    var s = root.localPerfState
    if (s.includes("balanced-performance")) return "#dbbc7f"
    if (s.includes("performance")) return Theme.accentRed
    return (root.theme ? root.theme.textPrimary : Theme.fgMain)
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
        icon: "󰤨"
        label: String(wifiSSID.value || "WiFi")
        active: Boolean(wifiOn.value)
        onClicked: toggleWifi()
        onRightClicked: {
            root.closeRequested()
            // det("nm-connection-editor >/dev/null 2>&1 &")
            det("/home/snes/.config/rofi/wifi/wifi.sh")
        }
        fixX: -10
      }

      Lib.ExpressiveButton {
        theme: root.theme
        icon: "󰂯"
        label: String(btDev.value || "Off")
        active: Boolean(btOn.value)
        onClicked: toggleBt()
        onRightClicked: {
            root.closeRequested()
            det("blueman-manager >/dev/null 2>&1 &")
        }
        fixX: -5
      }

      Lib.ExpressiveButton {
        theme: root.theme
        icon: root.getPerfIcon()
        label: root.getPerfLabel()
        active: root.isPerfActive()
        customIconColor: root.getPerfColor()
        hasCustomColor: !root.isPerfActive()
        onClicked: root.cyclePerf()
        fixX: -2
      }

      Lib.ExpressiveButton {
        theme: root.theme
        icon: root.dnd ? "󰂛" : "󰂚"
        label: root.dnd ? "Silent" : "Notify"
        active: root.dnd
        onClicked: toggleDnd()
        fixX: -3
      }
    }

  ColumnLayout {
    spacing: 8
    Layout.fillWidth: true

      Lib.ExpressiveSlider {
        theme: root.theme
        id: briS
        icon: "󰃟"
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
        icon: "󰕾"
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
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
  property bool dnd: false
  
  Component.onCompleted: { if (root.autoMode) det("sudo auto-cpufreq --force=reset") }
  function sh(cmd) { return ["bash","-lc", cmd] }
  function det(cmd) { Quickshell.execDetached(sh(cmd)) }

  // --------------------------------------------------------------------------------------------------------------
  Lib.CommandPoll {
    id: wifiOn;
    running: root.active && root.visible; interval: 2500
    command: sh("nmcli -t -f WIFI g 2>/dev/null | head -n1 || true")
    parse: function(o) { return String(o).trim() === "enabled" }
  }

  Lib.CommandPoll {
    id: wifiSSID;
    running: root.active && root.visible; interval: 5000
    command: sh("nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}' || true")
    parse: function(o) { var s = String(o).trim() ||
    "WiFi"; return s.length > 9 ? s.slice(0, 9) : s }
  }

  function toggleWifi() { det("nmcli radio wifi " + (!Boolean(wifiOn.value) ? "on" : "off")) }
  // --------------------------------------------------------------------------------------------------------------
  // BLUETOOTH 
  property bool _optBt: false       
  property bool _toggling: false    
  Timer { id: optTimer; interval: 3500; onTriggered: root._toggling = false }

  // BT ON
  Lib.CommandPoll {
    id: btOn;
    running: root.active && root.visible; interval: 3000
    command: sh("rfkill list bluetooth")
    parse: function(o) { return String(o).includes("Soft blocked: no") }
    onUpdated: if (!root._toggling) root._optBt = value 
  }

  // BT Device ID
  Lib.CommandPoll {
    id: btDev;
    running: root.active && root.visible; interval: 3500
    command: sh("pactl list cards 2>/dev/null | grep -A 20 'bluez_card' | grep 'device.description' | head -n1 | cut -d'=' -f2 | tr -d '\"'")
    parse: function(o) {
      var d = String(o).trim();
      if (d.length > 0) return d.length > 9 ? d.slice(0, 9) : d
      // Fallback: Use the strict btOn value.
      return btOn.value ? "On" : "Off" 
    }
  }
  
  // BT on/off
  function toggleBt() { 
      root._toggling = true;
      root._optBt = !btOn.value;
      optTimer.restart();
      // 'rfkill unblock' forces the kernel to wake it up.
      det("rfkill " + (root._optBt ? "unblock" : "block") + " bluetooth") 
  }
  // --------------------------------------------------------------------------------------------------------------
  // Volume
  Lib.CommandPoll {
    id: volPoll;
    running: root.active && root.visible; interval: 1200
    command: sh("pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -Po '\\d+(?=%)' | head -n1")
    parse: function(o) { var n = parseInt(String(o).trim());
    return isFinite(n) ? n : 0 }
    onUpdated: if (!volS.pressed) volS.value = value
  }
  // --------------------------------------------------------------------------------------------------------------
  // Brightness
  Lib.CommandPoll {
    id: briPoll;
    running: root.active && root.visible; interval: 1500
    command: sh("brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '% ' || true")
    parse: function(o) { var n = Number(String(o).trim());
    return isFinite(n) ? n : 50 }
    onUpdated: if (!briS.pressed) briS.value = value
  }
  // --------------------------------------------------------------------------------------------------------------
  // Performance modes
  property string cpuGov: "powersave"
  property bool _isChanging: false
  Lib.CommandPoll {
    id: perfPoll;
    running: root.active && root.visible && !root._isChanging; interval: 30000
    command: sh("cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'powersave'")
    parse: function(o) { return String(o).trim() }
    onUpdated: root.cpuGov = value
  }
  Timer { id: pollLockout;
  interval: 5000; onTriggered: root._isChanging = false }
  
  function togglePerf() {
    root._isChanging = true;
    pollLockout.restart()
    if (root.autoMode) { root.autoMode = false; root.cpuGov = "performance";
    det("sudo auto-cpufreq --force=performance") }
    else if (root.cpuGov === "performance") { root.cpuGov = "powersave";
    det("sudo auto-cpufreq --force=powersave") }
    else { root.autoMode = true;
    det("sudo auto-cpufreq --force=reset") }
  }
  function getPerfIcon() { return root.autoMode ?
  "cpu_auto.svg" : (root.cpuGov === "performance" ? "cpu_max.svg" : "cpu_powersave.svg") }
  function getPerfLabel() { return root.autoMode ?
  "Auto" : (root.cpuGov === "performance" ? "Max" : "Powersave") }
  function getPerfColor() {
    if (root.autoMode) return (root.theme && !root.theme.isDarkMode) ?
    '#283314' : (Theme.accent || "#a7c080")
    return (root.cpuGov === "performance") ?
    Theme.accentRed : (root.theme ? root.theme.textPrimary : Theme.fgMain)
  }
  // --------------------------------------------------------------------------------------------------------------
  // DND
  Lib.CommandPoll {
    id: dndPoll;
    running: root.active && root.visible; interval: 4000
    command: sh("makoctl mode 2>/dev/null || true")
    parse: function(o) { return String(o).includes("do-not-disturb") }
    onUpdated: root.dnd = value
  }
  function toggleDnd() { var next = !root.dnd;
  root.dnd = next; det("makoctl mode " + (next ? "-a" : "-r") + " do-not-disturb") }

  // -------------------------------------------------------------------
  // UI LAYOUT
  // -------------------------------------------------------------------
  RowLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 12

    // LEFT: Column of 4 Buttons
    ColumnLayout {
      Layout.fillHeight: true
      Layout.preferredWidth: 1 
      spacing: 8 

      component FitButton: Lib.ExpressiveButton {
          Layout.fillWidth: true
          Layout.fillHeight: true
          theme: root.theme
      }

      // 1. Wifi
      FitButton {
        icon: wifiOn.value ?
        "wifi_connected.svg" : "wifi_off.svg"
        label: String(wifiSSID.value || "WiFi")
        active: Boolean(wifiOn.value)
        onClicked: toggleWifi()
        onRightClicked: { root.closeRequested();
        det("quickshell -p ~/.config/quickshell/task-bar/lib/WifiMenu.qml") }
      }

      // 2. Bluetooth 
      FitButton {
        property bool showActive: root._toggling ? root._optBt : Boolean(btOn.value)
        
        icon: !showActive ?
        "bt_off.svg" : (String(btDev.value) !== "On" ? "bt_connected.svg" : "bt_on.svg")
        
        label: root._toggling ? 
            (root._optBt ? "On" : "Off") : 
            String(btDev.value || "Off")
            
        active: showActive
        
        onClicked: toggleBt()
        onRightClicked: { root.closeRequested();
        det("blueman-manager >/dev/null 2>&1 &") }
      }

      // 3. Performance
      FitButton {
        icon: root.getPerfIcon()
        label: root.getPerfLabel()
        active: (root.cpuGov === "performance" && !root.autoMode)
        customIconColor: root.getPerfColor()
        hasCustomColor: true
        onClicked: root.togglePerf()
        onRightClicked: root.batteryToggleRequested()
      }

  
      // 4. DND
      FitButton {
        icon: root.dnd ?
        "silent.svg" : "notify.svg"
        label: root.dnd ?
        "Silent" : "Notify"
        active: root.dnd
        onClicked: toggleDnd()
      }
    }

    // RIGHT: Sliders
    RowLayout {
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        spacing: 12

        // Brightness
        Item {
            Layout.fillHeight: true; Layout.fillWidth: true
            Lib.ExpressiveSlider {
                id: briS
                width: parent.height;
                height: parent.width
                anchors.centerIn: parent;
                rotation: -90
                theme: root.theme
                icon: { if (value < 40) return "bness_less40.svg";
                if (value < 75) return "bness_40to75.svg"; return "bnessmax.svg" }
                from: 0;
                to: 100; value: 50
                accentColor: (root.theme && !root.theme.isDarkMode) ?
                root.theme.accentSlider : "#83C092"
                onUserChanged: det("brightnessctl set " + Math.round(value) + "%")
            }
        }

        // Volume
        Item {
            Layout.fillHeight: true;
            Layout.fillWidth: true
            Lib.ExpressiveSlider {
                id: volS
                width: parent.height;
                height: parent.width
                anchors.centerIn: parent;
                rotation: -90
                theme: root.theme
                icon: { if (value === 0) return "mute.svg";
                if (volPoll.value.isHeadphones) return "vol_headphones.svg"; return (value > 50) ? "vol_50p.svg" : "vol_50m.svg" }
                from: 0;
                to: 100; value: 0
                accentColor: (root.theme && !root.theme.isDarkMode) ?
                root.theme.accentSlider : "#83C092"
                onUserChanged: det("pactl set-sink-volume @DEFAULT_SINK@ " + Math.round(value) + "%")
            } 
        }
    }
  }
}
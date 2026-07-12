import QtQuick
import Quickshell
import Quickshell.Io

FocusScope {
    id: ctrl

    property bool isDarkMode: true
    property string style: "life"

    // Accent overrides resolved by PowerMenu.qml (empty string = use skin default).
    // Livingthings reads `livingAccent`; Cassini reads `cassiniSelBg`.
    property string livingAccent: ""
    property string cassiniSelBg: ""

    // Sizes 
    width: style === "cassini" ? 600 : 400
    height: style === "cassini" ? 315 : 300

    focus: true
    activeFocusOnTab: true
    Keys.enabled: true
    Keys.priority: Keys.BeforeItem

    property real intro: 0
    property bool closing: false
    opacity: intro


    // Navigation / confirm 
    property int currentIndex: 0
    property int confirmIndex: 1
    property string pendingCmd: ""
    property string pendingLabel: ""

    property var buttonsModel: [
        { label: "Lock",     icon: "", cmd: "lock" },
        { label: "Suspend",  icon: "", cmd: "suspend" },
        { label: "Logout",   icon: "", cmd: "logout" },
        { label: "Reboot",   icon: "", cmd: "reboot" },
        { label: "Shutdown", icon: "", cmd: "shutdown" }
    ]

    // System info for the header
    property string userName: "user"
    property string uptime: "..."

    Process {
        id: sysInfo
        command: ["bash", "-c", "whoami; uptime -p | sed 's/up //'"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                const d = data.trim()
                if (d === "") return
 
                if (/^\d/.test(d)) ctrl.uptime = d
                else ctrl.userName = d
            }
        }
    }

    // Entrance: ease in.
    NumberAnimation {
        id: introAnim
        target: ctrl;
        property: "intro"
        from: 0; to: 1; duration: 220;
        easing.type: Easing.OutCubic
        running: true
        onFinished: ctrl.forceActiveFocus()
    }

    // Exit: reverse
    NumberAnimation {
        id: outroAnim
        property var pendingAction: null
        target: ctrl;
        property: "intro"
        from: ctrl.intro; to: 0; duration: 180;
        easing.type: Easing.OutCubic
        onFinished: {
            if (outroAnim.pendingAction) outroAnim.pendingAction()
            Qt.quit()
        }
    }

    // Begin the close animation
    function close(action) {
        if (closing) return
        closing = true
        outroAnim.pendingAction = action || null
        introAnim.stop()
        outroAnim.from = ctrl.intro
        outroAnim.start()
    }

    Component.onCompleted: {
        loadStyle()
        forceActiveFocus()
        Qt.callLater(() => forceActiveFocus())
    }

    onStyleChanged: loadStyle()
    function loadStyle() {
        styleLoader.setSource(
            style === "cassini" ? "Cassini.qml" : "Livingthings.qml",
            { "ctrl": ctrl })
    }

    // --- Main ------------------------------------------------------------

    function move(delta) {
        const count = buttonsModel.length
        let next = currentIndex + delta
        if (next < 0) next = count - 1
        if (next >= count) next = 0
        currentIndex = next
  
    }

    function initiateAction(cmd, label) {
        pendingCmd = cmd
        pendingLabel = label
        confirmIndex = 1
        forceActiveFocus()
    }

    function cancel() {
        pendingCmd = ""
        confirmIndex = 1
        forceActiveFocus()
    }

    function backdropClicked() {
     
        if (pendingCmd !== "") cancel()
        else close()
    }

    function getConfirmText() {
        if (pendingCmd === "shutdown") return "Power Off?"
        if (pendingCmd === "reboot") return "Reboot System?"
        if (pendingCmd === "logout") return "Log Out?"
        if (pendingCmd === "lock") return "Lock Screen?"
        if (pendingCmd === "suspend") return "Suspend?"
        return "Are you sure?"
    }

    function isDestructive() {
        return (pendingCmd === "shutdown" || pendingCmd === "reboot")
    }

    function run(cmd) {
        close(function() {
            if (cmd === "lock") Quickshell.execDetached(["hyprlock"])
            if (cmd === "suspend") Quickshell.execDetached(["systemctl", "suspend"])
            if (cmd === "logout") Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"])
            if (cmd === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
            if (cmd === "shutdown") Quickshell.execDetached(["systemctl", "poweroff"])
        })
    }

  
    Keys.onPressed: (e) => {
        const isActivate = (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)

        if (e.key === Qt.Key_Escape) {
            backdropClicked()
            e.accepted = true
            return
        }

        // Confirm mode
      
        if (pendingCmd !== "") {
            if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Tab) {
                confirmIndex = (confirmIndex === 0) ? 1 : 0
                e.accepted = true
                return
            }
            if (isActivate) {
                if (confirmIndex === 1) run(pendingCmd)
                else cancel()
 
                e.accepted = true
                return
            }
            e.accepted = true
            return
        }

        // Selection mode
        if (e.key === Qt.Key_Left || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier))) {
            move(-1); e.accepted = true; return
        }
        if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) {
            move(1); e.accepted = true; return
        }
        if (e.key === Qt.Key_Up)   { move(-1); e.accepted = true; return }
        if (e.key === Qt.Key_Down) { move(1); e.accepted = true; return }

        if (isActivate) {
            initiateAction(buttonsModel[currentIndex].cmd, buttonsModel[currentIndex].label)
            e.accepted = true
            return
        }
    }

    // --- Skin -------------------------------------------------------------

    Loader {
        id: styleLoader
        anchors.fill: parent
    }
}
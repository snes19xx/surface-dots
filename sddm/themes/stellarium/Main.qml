////////////////
// [Stellarium SDDM theme by @snes19xx]
//
// Main.qml -- 1 of 8 files
// This is the main entry point for the theme. It sets up the wallpaper, fonts,
// and shared state, and hosts the Lockscreen and Login components which do the heavy lifting of rendering the UI.
//
////////////////

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#07090b"

    // Palette 
    readonly property color colInk:        "#ece6d6"
    readonly property color colInkSoft:    "#c8c1b2"
    readonly property color colInkFaint:   "#8d8676"
    readonly property color colInkWhisper: "#5a5648"
    readonly property color colWrong:      "#d99089"

    property color accentDeep: (typeof config !== "undefined" && config.accent)
                                  ? config.accent : "#61886a"
    property color accent:     (typeof config !== "undefined" && config.accent)
                                  ? config.accent : "#87b08a"

    readonly property color hairline:       Qt.rgba(0.93, 0.90, 0.84, 0.18)
    readonly property color hairlineStrong: Qt.rgba(0.93, 0.90, 0.84, 0.42)
    readonly property color cardBg:         Qt.rgba(0.055, 0.063, 0.071, 0.62)

    // View state 
    // "lock" | "login"
    property string currentView: "lock"
    // "idle" | "typing" | "auth" | "ok" | "wrong"
    property string authState: "idle"
    property string statusMessage: ""

    // Fonts 
    // Drop your .ttf/.otf into fonts/: names below are the family names Qt
    // reads from the file. If the load fails Qt falls back to system serif.
    FontLoader { id: serifLoader;  source: "fonts/EBGaramond-Regular.ttf" }
    FontLoader { id: italicLoader; source: "fonts/Newsreader-Italic.ttf" }
    FontLoader { id: monoLoader;   source: "fonts/JetBrainsMono-Regular.ttf" }

    readonly property string fontSerif:  serifLoader.name  || "EB Garamond"
    readonly property string fontItalic: italicLoader.name || "Newsreader"
    readonly property string fontMono:   monoLoader.name   || "JetBrains Mono"

    // Wallpaper (configurable from theme.conf) 
    property string wallpaperPath: (typeof config !== "undefined" && config.background)
                                       ? config.background : "wall-earth.jpg"

    Image {
        id: wallpaper
        anchors.fill: parent
        source: root.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        transform: Scale {
            id: wallScale
            origin.x: wallpaper.width / 2
            origin.y: wallpaper.height / 2
            xScale: root.currentView === "login" ? 1.06 : 1.0
            yScale: root.currentView === "login" ? 1.06 : 1.0
            Behavior on xScale { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
            Behavior on yScale { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
            GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.15) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
        }
    }

    // Extra dim layer on the login view instead of blur for aesthetics
    Rectangle {
        id: loginDim
        anchors.fill: parent
        color: "#000000"
        opacity: root.currentView === "login" ? 0.35 : 0.0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    }

    // Clock 
    property date now: new Date()
    Timer {
        id: clockTimer
        interval: 1000 - (new Date().getMilliseconds())
        running: true
        repeat: true
        onTriggered: {
            root.now = new Date()
            interval = 1000 - (new Date().getMilliseconds())
        }
    }

    // Page stack 
    Item {
        id: stage
        anchors.fill: parent

        Lockscreen {
            id: lockPage
            width: parent.width
            height: parent.height
            enabled: root.currentView === "lock"
            now: root.now
            y: root.currentView === "login" ? -parent.height * 0.12 : 0
            opacity: root.currentView === "login" ? 0 : 1
            Behavior on y       { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

            onAdvance: root.currentView = "login"
        }

        Login {
            id: loginPage
            width: parent.width
            height: parent.height
            enabled: root.currentView === "login"
            now: root.now
            currentView: root.currentView
            authState: root.authState
            statusMessage: root.statusMessage
            userName: (typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : "snes"
            y: root.currentView === "login" ? 0 : parent.height
            opacity: root.currentView === "login" ? 1 : 0
            Behavior on y       { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

            onRequestBack: {
                root.authState = "idle"
                root.statusMessage = ""
                root.currentView = "lock"
            }
            onAuthStateRequest: function(s) { root.authState = s }
            onLoginAttempt: function(user, pass, sessionIndex) {
                root.authState = "auth"
                root.statusMessage = ""
                if (typeof sddm !== "undefined") {
                    sddm.login(user, pass, sessionIndex)
                } else {
                    // Dev fallback so the theme is testable outside SDDM
                    delayedTimer.kind = (pass === "snes") ? "ok" : "wrong"
                    delayedTimer.restart()
                }
            }
        }
    }

    // TESTING ONLY
    Timer {
        id: delayedTimer
        property string kind: ""
        interval: 700; repeat: false
        onTriggered: {
            if (kind === "ok") {
                root.authState = "ok"
            } else {
                root.authState = "wrong"
                resetTimer.restart()
            }
        }
    }
    Timer {
        id: resetTimer
        interval: 900; repeat: false
        onTriggered: { root.authState = "idle"; root.statusMessage = ""; loginPage.clearPassword() }
    }

    // SDDM signal hooks 
    Connections {
        target: (typeof sddm !== "undefined") ? sddm : null
        function onLoginSucceeded() { 
            root.authState = "ok" 
            root.statusMessage = ""
        }
        function onLoginFailed() {
            root.authState = "wrong"
            if (root.statusMessage === "") root.statusMessage = "incorrect — try again"
            resetTimer.restart()
        }
        function onInformationMessage(message) {
            root.statusMessage = message
        }
        function onErrorMessage(message) {
            root.statusMessage = message
            root.authState = "wrong"
            resetTimer.restart()
        }
    }

    // Global key handling 
    focus: true
    Keys.onPressed: (event) => {
        if (root.currentView === "lock") {
            // Anything printable or Enter/Space/Down advances
            if (event.key === Qt.Key_Tab) return
            if ((event.text && event.text.length === 1) ||
                event.key === Qt.Key_Return || event.key === Qt.Key_Enter ||
                event.key === Qt.Key_Space  || event.key === Qt.Key_Down) {
                root.currentView = "login"
                event.accepted = true
            }
        } else if (root.currentView === "login") {
            if (event.key === Qt.Key_Escape) {
                root.authState = "idle"
                loginPage.clearPassword()
                root.currentView = "lock"
                root.forceActiveFocus()
                event.accepted = true
            }
        }
    }

    onCurrentViewChanged: {
        if (currentView === "lock") {
            root.forceActiveFocus()
        }
    }

    // Click anywhere on the lockscreen also advances
    MouseArea {
        anchors.fill: parent
        enabled: root.currentView === "lock"
        z: 0  // behind the Lockscreen item which has its own interactive areas
        onClicked: root.currentView = "login"
    }

    Component.onCompleted: forceActiveFocus()
}

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Window 2.15
import Qt5Compat.GraphicalEffects 6.0 
import SddmComponents 2.0
import "."
// import QtGraphicalEffects 1.0 [only for  sddm-greeter --test-mode --theme /directory]


Item {
    id: root
    width: Screen.width
    height: Screen.height
    focus: true


    // 1. STATE & CONFIG

    property bool authOpen: false
    property bool sessionOpen: false
    
    // 1.1 Status message from the system ("Authentication failure")
    property string statusMessage: ""

    property int currentSessionIndex: 0
    property var now: new Date()
    
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: root.now = new Date()
    }

    readonly property real blurRadius: isNaN(Number(config.blurRadius)) ? 60 : Number(config.blurRadius)
    readonly property real sleepDim: isNaN(Number(config.sleepDim)) ? 0.55 : Number(config.sleepDim)
    readonly property real authDim:  isNaN(Number(config.authDim))  ? 0.50 : Number(config.authDim)

    readonly property color cSurface:     "#232A2E"
    readonly property color cSurfaceVar:  "#2D353B"
    readonly property color cPrimary:     "#A7C080"
    readonly property color cOnPrimary:   "#232A2E"
    readonly property color cText:        "#D3C6AA"
    readonly property color cMuted:       "#859289"
    readonly property color cError:       "#E67E80" 


    // 2. CONNECTIONS 

    Connections {
        target: sddm
        
        function onLoginFailed() {
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
            
            // 2.1 Trigger Visuals
            authCard.loginFailed = true 
            shakeAnimation.start()
            failResetTimer.restart()
            
            // 2.2 If PAM didn't send a specific text error, default to this:
            if (root.statusMessage === "") root.statusMessage = "Login Failed";
        }
        
        function onLoginSucceeded() {
            authCard.loginFailed = false
            root.statusMessage = "" 
        }

        // 2.3 Listeners.
        function onInformationMessage(message) { root.statusMessage = message }
        function onErrorMessage(message) { root.statusMessage = message }
    }

    Timer {
        id: failResetTimer
        interval: 900; repeat: false
        onTriggered: authCard.loginFailed = false
    }


    // 3. HELPERS

    QQC2.ComboBox {
        id: sessionSelector
        visible: false
        model: sessionModel
        textRole: "name"
        currentIndex: root.currentSessionIndex
    }

    QQC2.ComboBox {
        id: userSelector
        visible: false
        model: userModel
        textRole: "name"
        currentIndex: (userModel.lastIndex !== undefined && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
    }

    function toFileUrl(p) {
        if (!p) return "";
        var s = String(p).trim();
        if (s.indexOf("file://") === 0) return s;
        if (s.indexOf("/") === 0) return "file://" + s;
        return s;
    }

    function username() { return userSelector.currentText || ""; }

    function avatarCandidate(i) {
        var u = username();
        if (i === 0) return toFileUrl("/usr/share/sddm/faces/" + u + ".face.icon");
        if (i === 1) return toFileUrl("/var/lib/AccountsService/icons/" + u);
        return "";
    }

    function wake() {
        if (!root.authOpen) {
            root.authOpen = true;
            root.sessionOpen = false;
            focusTimer.restart();
        }
    }

    function sleep() {
        root.authOpen = false;
        root.sessionOpen = false;
        passwordInput.text = "";
        root.statusMessage = ""; 
        wakeKeyCatcher.forceActiveFocus();
    }

    function attemptLogin() {
        if (passwordInput.text.length === 0) return;
        
        root.statusMessage = "" // Clear previous messages
        
        var sessionIdx = sessionSelector.currentIndex;
        if (sessionIdx < 0) sessionIdx = (root.currentSessionIndex >= 0) ? root.currentSessionIndex : 0;
        var uname = userSelector.currentText;
        
        sddm.login(uname, passwordInput.text, sessionIdx);
    }

    Component.onCompleted: {
        if (sessionModel.lastIndex !== undefined && sessionModel.lastIndex >= 0) {
            root.currentSessionIndex = sessionModel.lastIndex;
        }
        sleep();
    }


    // 4. EVENT HANDLERS
    TextInput {
        id: wakeKeyCatcher
        width: 1; height: 1; opacity: 0
        focus: !root.authOpen
        Keys.onPressed: function(e) { wake(); e.accepted = true; }
    }

    Timer {
        id: focusTimer
        interval: 100; running: false; repeat: false
        onTriggered: passwordInput.forceActiveFocus()
    }


    // 5.VISUALS

    Image {
        id: background
        anchors.fill: parent
        z: 0
        fillMode: Image.PreserveAspectCrop
        source: config.background
        onStatusChanged: {
            if (status === Image.Error && source !== config.defaultBackground) {
                source = config.defaultBackground;
            }
        }
    }

    FastBlur {
        anchors.fill: parent
        radius: root.authOpen ? root.blurRadius : 0
        source: background
        z: 1
        opacity: root.authOpen ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Behavior on radius  { NumberAnimation { duration: 300 } }
    }

    Rectangle {
        anchors.fill: parent
        z: 2
        color: "black"
        opacity: root.authOpen ? root.authDim : root.sleepDim
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    MouseArea {
        anchors.fill: parent
        z: 3
        enabled: !root.authOpen
        onClicked: wake()
    }

    // 6. CLOCK

    Text {
        z: 4
        anchors.left: parent.left; anchors.top: parent.top
        anchors.leftMargin: 60; anchors.topMargin: 60
        text: Qt.formatDate(root.now, "dddd, MMMM d")
        color: Qt.rgba(211/255, 198/255, 170/255, 0.62)
        font.pixelSize: 28
        font.weight: Font.Normal
        opacity: root.authOpen ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Column {
        z: 4
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.authOpen ? -300 : -50
        scale: root.authOpen ? 0.8 : 1.0
        opacity: root.authOpen ? 0.0 : 1.0
        spacing: -87

        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }
        Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 300 } }

        Text {
            text: Qt.formatTime(root.now, "hh")
            color: root.cPrimary
            font.family: "Inter" 
            font.pixelSize: 220; font.weight: Font.Medium
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: Qt.formatTime(root.now, "mm")
            color: root.cText
            font.family: "Inter"
            font.pixelSize: 220; font.weight:Font.Medium
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }


    // 7. POWER MENU UI 

    Rectangle {
        id: powerPill
        z: 20
        anchors.right: parent.right; anchors.top: parent.top
        anchors.rightMargin: 40; anchors.topMargin: 40
        width: 160; height: 44; radius: 22
        color: Qt.rgba(45/255, 53/255, 59/255, 0.8)
        visible: root.authOpen
        opacity: root.authOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        RowLayout {
            anchors.centerIn: parent
            spacing: 20
            MouseArea {
                width: 24; height: 24; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: sddm.suspend()
                Text { anchors.centerIn: parent; text: "󰤄"; font.pixelSize: 28; color: root.cText }
                Rectangle {
                    visible: parent.containsMouse; color: root.cSurface; border.color: root.cPrimary
                    border.width: 1; radius: 6; width: 60; height: 28; y: 35
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text { anchors.centerIn: parent; text: "Sleep"; color: root.cText; font.pixelSize: 12 }
                }
            }
            MouseArea {
                width: 24; height: 24; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: sddm.reboot()
                Text { anchors.centerIn: parent; text: "⟲"; font.pixelSize: 28; color: root.cText }
                Rectangle {
                    visible: parent.containsMouse; color: root.cSurface; border.color: root.cPrimary
                    border.width: 1; radius: 6; width: 70; height: 28; y: 35
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text { anchors.centerIn: parent; text: "Restart"; color: root.cText; font.pixelSize: 12 }
                }
            }
            MouseArea {
                width: 24; height: 24; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: sddm.powerOff()
                Text { anchors.centerIn: parent; text: "⏻"; font.pixelSize: 32; color: root.cText }
                Rectangle {
                    visible: parent.containsMouse; color: root.cSurface; border.color: root.cPrimary
                    border.width: 1; radius: 6; width: 90; height: 28; y: 35
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text { anchors.centerIn: parent; text: "Shut Down"; color: root.cText; font.pixelSize: 12 }
                }
            }
        }
    }

    // 8. AUTH CARD

    Rectangle {
        id: authCard
        z: 15
        width: 400; height: 500
        radius: 28
        color: root.cSurface

        // --- 8.1 ERROR BORDER ---
        property bool loginFailed: false
        border.width: loginFailed ? 2 : 0
        border.color: loginFailed ? root.cError : "transparent"
        Behavior on border.width { NumberAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.authOpen ? (root.height / 2) - (height / 2) : -500
        opacity: root.authOpen ? 1.0 : 0.0

        Behavior on anchors.bottomMargin { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // --- 8.2 RATTLE ANIMATION ---
        SequentialAnimation {
            id: shakeAnimation
            NumberAnimation { target: authCard; property: "anchors.horizontalCenterOffset"; from: 0; to: -16; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: authCard; property: "anchors.horizontalCenterOffset"; from: -16; to: 16; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: authCard; property: "anchors.horizontalCenterOffset"; from: 16; to: -12; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: authCard; property: "anchors.horizontalCenterOffset"; from: -12; to: 12; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: authCard; property: "anchors.horizontalCenterOffset"; from: 12; to: 0; duration: 50; easing.type: Easing.InOutQuad }
        }

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true; color: "#80000000"; radius: 30; samples: 20; verticalOffset: 10
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 40
            spacing: 24

            Item {
                Layout.alignment: Qt.AlignHCenter
                width: 160; height: 160
                Rectangle {
                    id: avatarCircle
                    anchors.fill: parent
                    radius: 80; color: "transparent"
                    property int tryIndex: 0; property bool ok: false
                    Image {
                        anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                        source: avatarCandidate(avatarCircle.tryIndex)
                        layer.enabled: true
                        layer.effect: OpacityMask { maskSource: Rectangle { width: 160; height: 160; radius: 80 } }
                        onStatusChanged: {
                            if (status === Image.Ready) avatarCircle.ok = true;
                            else if (status === Image.Error && avatarCircle.tryIndex < 2) {
                                avatarCircle.tryIndex += 1; source = avatarCandidate(avatarCircle.tryIndex);
                            }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent; radius: 80; color: root.cSurfaceVar; visible: !avatarCircle.ok
                        Text { anchors.centerIn: parent; text: (username().length ? username()[0].toUpperCase() : "?"); color: root.cText; font.pixelSize: 64 }
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter; spacing: 8
                Text { text: userSelector.currentText; color: root.cText; font.pixelSize: 22; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter; implicitWidth: sessionLabel.contentWidth + 24; implicitHeight: 26; radius: 8; color: root.cSurfaceVar
                    Text { id: sessionLabel; anchors.centerIn: parent; text: sessionSelector.currentText; color: root.cMuted; font.pixelSize: 12 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.sessionOpen = !root.sessionOpen; if (root.sessionOpen) sessionList.forceActiveFocus() }
                    }
                }
            }

            // 8.3 PASSWORD INPUT AND STATUS MESSAGE
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                // 8.3.1 INPUT BOX
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: 28
                    color: root.cSurfaceVar
                    clip: true

                    Item {
                        anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 60
                        PixelDots {
                            anchors.centerIn: parent; dotCount: passwordInput.text.length
                            dotColor: root.cText; animColor: root.cPrimary
                        }
                        TextInput {
                            id: passwordInput
                            anchors.fill: parent; verticalAlignment: TextInput.AlignVCenter
                            color: "transparent"; cursorVisible: false; cursorDelegate: Item {}
                            echoMode: TextInput.Password; font.pixelSize: 16; focus: true
                            
                            onAccepted: attemptLogin()
                            Keys.onEscapePressed: root.sleep()
                            Keys.onPressed: { if (event.key === Qt.Key_Down && root.sessionOpen) sessionList.forceActiveFocus() }
                        }
                        Text {
                            anchors.centerIn: parent; text: "Enter Password"; color: root.cMuted
                            visible: passwordInput.text.length === 0; font.pixelSize: 16
                        }
                    }

                    Rectangle {
                        width: 48; height: 48; radius: 24
                        color: root.cPrimary
                        
                        anchors.right: parent.right; anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent; text: "→"; 
                            color: root.cOnPrimary
                            font.pixelSize: 24
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: attemptLogin()
                        }
                    }
                }
                
                // 8.4 ERROR STATUS TEXT
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.statusMessage
                    color: root.cError
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    visible: root.statusMessage.length > 0
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }
        }

        // 9. SESSION SELECTOR LIST

        Rectangle {
            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 40; height: root.sessionOpen ? 220 : 0
            radius: 16; color: root.cSurfaceVar; clip: true; visible: height > 0
            Behavior on height { NumberAnimation { duration: 200 } }
            
            ListView {
                id: sessionList; anchors.fill: parent; anchors.margins: 10
                model: sessionModel; focus: false; keyNavigationEnabled: true
                
                highlight: Rectangle { 
                    color: Qt.rgba(1,1,1,0.1)
                    radius: 8 
                }
                highlightMoveDuration: 0

                delegate: Item {
                    width: parent.width; height: 40
                    Rectangle {
                        anchors.fill: parent; radius: 8
                        property bool isHovered: mouseArea.containsMouse; property bool isSelected: ListView.isCurrentItem
                        color: (isHovered || isSelected) ? Qt.rgba(1,1,1,0.05) : "transparent"
                        Text { anchors.centerIn: parent; text: name; color: root.cText; font.pixelSize: 14 }
                        MouseArea {
                            id: mouseArea; anchors.fill: parent; hoverEnabled: true
                            onClicked: { sessionList.currentIndex = index; root.currentSessionIndex = index; sessionSelector.currentIndex = index; root.sessionOpen = false; passwordInput.forceActiveFocus() }
                        }
                    }
                }
                Keys.onReturnPressed: { root.currentSessionIndex = currentIndex; sessionSelector.currentIndex = currentIndex; root.sessionOpen = false; passwordInput.forceActiveFocus() }
                Keys.onEscapePressed: { root.sessionOpen = false; passwordInput.forceActiveFocus() }
            }
        }
    }

    Text {
        z: 4; anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 40
        text: "Press any key to unlock"; color: root.cMuted
        opacity: root.authOpen ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
}
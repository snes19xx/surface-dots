////////////////
// [Stellarium SDDM theme by @snes19xx]
//
// Main.qml -- 3 of 8 files
// This is the login view. It contains the username, password field, session selector, 
// and login button, as well as the header with the return button and status emblem. 
//
////////////////

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: loginRoot

    property string userName: "snes"
    property date now
    property string currentView: "lock"
    property string authState: "idle"
    property string statusMessage: ""

    property string passwordText: pwField.text
    property alias sessionIndex: sessionSelector.sessionIndex
    property bool fprintAttempt: false

    signal requestBack()
    signal authStateRequest(string state)
    signal loginAttempt(string user, string pass, int sessionIndex)

    function clearPassword() {
        pwField.text = ""
    }

    readonly property string fSerif:  root.fontSerif
    readonly property string fItalic: root.fontItalic
    readonly property string fMono:   root.fontMono

readonly property var shapeKeys: [
    "star","crescent","saturn","sun","ring",
    "sparkle","nova","planet"
    ,"halo"
]

    // Automatically focus and start fingerprint when transitioning to login view
    onCurrentViewChanged: {
        if (currentView === "login") {
            focusTimer.start()
            fprintTimer.start()
        }
    }

    Timer {
        id: focusTimer
        interval: 720
        onTriggered: pwField.forceActiveFocus()
    }

    Timer {
        id: fprintTimer
        interval: 750
        onTriggered: {
            if (loginRoot.authState === "idle") {
                loginRoot.loginAttempt(loginRoot.userName, "", sessionSelector.sessionIndex)
            }
        }
    }

    // Top Header
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Math.max(28, Math.min(56, loginRoot.height * 0.04))
        anchors.leftMargin: Math.max(36, Math.min(84, loginRoot.width * 0.05))
        anchors.rightMargin: Math.max(36, Math.min(84, loginRoot.width * 0.05))
        height: 72

        // Return button
        Button {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            background: Item {} // transparent
            contentItem: Row {
                spacing: 14
                Rectangle { width: 22; height: 1; color: root.colInkSoft; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    renderType: Text.NativeRendering
                    text: "return to lock"
                    font.family: loginRoot.fItalic
                    font.pixelSize: 25 
                    font.italic: true
                    color: root.colInkSoft
                }
            }
            onClicked: loginRoot.requestBack()
            hoverEnabled: true
            opacity: hovered ? 1 : 0.8
        }

        // Center emblem
        StatusEmblem {
            anchors.centerIn: parent
            state: loginRoot.authState
            accent: root.accent
        }
    }

    // Fingerprint recognition anim
    Item {
        id: fprintHint
        anchors.top: header.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: 36

        opacity: loginRoot.fprintAttempt && loginRoot.authState === "auth" ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

        Text {
            id: phraseText
            anchors.centerIn: parent
            renderType: Text.NativeRendering
            property int phraseIndex: 0
            property var phrases: ["Looking for you…", "Hello there…", "Just a moment…"]
            text: phrases[phraseIndex]
            font.family: loginRoot.fItalic
            font.italic: true
            font.pixelSize: Math.max(18, Math.min(25, loginRoot.width * 0.017))
            color: root.colInkSoft

            SequentialAnimation {
                id: cycleAnim
                running: fprintHint.opacity > 0
                loops: Animation.Infinite
                onRunningChanged: {
                    if (!running) {
                        phraseText.opacity = 1
                        phraseText.phraseIndex = 0
                    }
                }
                PauseAnimation   { duration: 3000 }
                NumberAnimation  { target: phraseText; property: "opacity"; to: 0; duration: 360; easing.type: Easing.OutCubic }
                ScriptAction     { script: phraseText.phraseIndex = (phraseText.phraseIndex + 1) % phraseText.phrases.length }
                NumberAnimation  { target: phraseText; property: "opacity"; to: 1; duration: 360; easing.type: Easing.InCubic }
            }
        }
    }

    // Center Card
    Item {
        id: cardContainer
        anchors.centerIn: parent
        width: Math.min(484, parent.width * 0.92)
        height: cardContent.height + 88 

        // Emulate CSS Shake animation for "wrong" state
        SequentialAnimation on x {
            id: cardShake
            running: false
            NumberAnimation { from: cardContainer.x; to: cardContainer.x - 6; duration: 80 }
            NumberAnimation { from: cardContainer.x - 6; to: cardContainer.x + 6; duration: 80 }
            NumberAnimation { from: cardContainer.x + 6; to: cardContainer.x - 4; duration: 80 }
            NumberAnimation { from: cardContainer.x - 4; to: cardContainer.x; duration: 80 }
        }

        Connections {
            target: loginRoot
            function onAuthStateChanged() {
                if (loginRoot.authState === "wrong") cardShake.start()
            }
        }

        Rectangle {
            id: cardBg
            anchors.fill: parent
            color: Qt.rgba(14/255, 16/255, 18/255, 0.62)
            border.color: root.hairlineStrong
            border.width: 1

            Canvas {
                anchors.fill: parent
                opacity: 1.0 
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var w = width;
                    var h = height;

                    ctx.strokeStyle = "rgba(236, 230, 214, 0.045)";
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    for (var x = 0; x <= w; x += 24) {
                        if (x % 120 !== 0) { ctx.moveTo(x, 0); ctx.lineTo(x, h); }
                    }
                    for (var y = 0; y <= h; y += 24) {
                        if (y % 120 !== 0) { ctx.moveTo(0, y); ctx.lineTo(w, y); }
                    }
                    ctx.stroke();

                    ctx.strokeStyle = "rgba(236, 230, 214, 0.06)";
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    for (var xM = 0; xM <= w; xM += 120) {
                        ctx.moveTo(xM, 0); ctx.lineTo(xM, h);
                    }
                    for (var yM = 0; yM <= h; yM += 120) {
                        ctx.moveTo(0, yM); ctx.lineTo(w, yM);
                    }
                    ctx.stroke();
                }
            }
        }

        Column {
            id: cardContent
            anchors.centerIn: parent
            width: parent.width - 88 

            // Avatar
            Item {
                width: parent.width; height: 106 + 24
                Avatar {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Welcome text
            Text {
                renderType: Text.NativeRendering
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.family: loginRoot.fSerif
                font.pixelSize: Math.max(31, Math.min(39, loginRoot.width * 0.026))
                color: root.colInk
                lineHeight: 1.1
                textFormat: Text.RichText
                text: "Welcome back, <i style='color:" + root.accent + "'>" + loginRoot.userName + "</i>."
                padding: 0; bottomPadding: 28
            }

            // Session Pill
            Item {
                width: parent.width; height: 35 + 31
                SessionPill {
                    id: sessionSelector
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 154 
                }
            }

            // Password Row
            Row {
                width: parent.width
                height: 48
                spacing: 15

                // Input Box Container
                Rectangle {
                    width: parent.width - 48 - 15
                    height: parent.height
                    color: "transparent"
                    border.color: "transparent"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: loginRoot.authState === "wrong" ? root.colWrong : root.colInkSoft
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    // Hidden actual text field
                    TextField {
                        id: pwField
                        anchors.fill: parent
                        color: "transparent"
                        selectionColor: "transparent"
                        selectedTextColor: "transparent"
                        background: Item {}
                        echoMode: TextInput.Normal // Allows normal selection/Ctrl+A
                        font.pixelSize: 20 // Matching shape size roughly so highlight is tall enough
                        font.family: loginRoot.fMono
                        font.letterSpacing: 2 // Approx spacing to match shapes

                        // Handle typing logic
                        Timer {
                            id: typingTimer
                            interval: 1100
                            onTriggered: {
                                if (loginRoot.authState === "typing") {
                                    loginRoot.authStateRequest("idle")
                                }
                            }
                        }

                        onTextChanged: {
                            if (loginRoot.authState !== "auth" && loginRoot.authState !== "ok") {
                                loginRoot.authStateRequest("typing")
                                typingTimer.restart()
                            }
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                submitBtn.clicked()
                                event.accepted = true
                            }
                        }
                    }

                    // Custom selection highlight behind shapes
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        property int selStart: Math.min(pwField.selectionStart, pwField.selectionEnd)
                        property int selEnd:   Math.max(pwField.selectionStart, pwField.selectionEnd)
                        property int displayStart: Math.min(selStart, 15)
                        property int displayEnd:   Math.min(selEnd, 15)
                        
                        x: displayStart * 22 
                        width: (displayEnd - displayStart) * 22
                        height: 26
                        color: Qt.rgba(135/255, 176/255, 138/255, 0.4)
                        visible: pwField.selectedText.length > 0
                    }

                    // Visual Password Shapes
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        spacing: 2

                        Text {
                            renderType: Text.NativeRendering
                            visible: pwField.text.length === 0
                            text: "passphrase"
                            font.family: loginRoot.fItalic
                            font.italic: true
                            font.pixelSize: 18
                            color: root.colInkWhisper
                            font.letterSpacing: 0.64
                        }

                        Repeater {
                            model: Math.min(pwField.text.length, 15)
                            delegate: ShapeGlyph {
                                kind: shapeKeys[(index * 5 + ((index % 4) * 3) + 1) % shapeKeys.length]
                                size: 20
                                color: root.colInk

                                scale: 1.0
                                opacity: 1.0

                                Component.onCompleted: {
                                    if (index === pwField.text.length - 1) {
                                        popInScale.start()
                                        popInOpacity.start()
                                    }
                                }

                                ScaleAnimator on scale { id: popInScale; from: 0.5; to: 1.0; duration: 240; easing.type: Easing.OutBack; running: false }
                                OpacityAnimator on opacity { id: popInOpacity; from: 0; to: 1.0; duration: 240; running: false }
                            }
                        }

                        Rectangle {
                            visible: pwField.text.length > 0
                            width: 2; height: 24
                            color: root.accent
                            anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 1; duration: 0 }
                                PauseAnimation { duration: 500 }
                                NumberAnimation { to: 0; duration: 0 }
                                PauseAnimation { duration: 500 }
                            }
                        }
                    }
                }

                // Enter Button
                Button {
                    id: submitBtn
                    width: 48; height: 48
                    padding: 0
                    enabled: pwField.text.length > 0 && loginRoot.authState !== "auth" && loginRoot.authState !== "ok"

                    background: Rectangle {
                        radius: 8
                        color: pwField.text.length > 0 ? root.accentDeep : "transparent"
                        border.color: pwField.text.length > 0 ? root.accent : root.hairlineStrong
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                    }

                    contentItem: Item {
                        Canvas {
                            id: arrowCanvas
                            anchors.centerIn: parent
                            width: 16; height: 16
                            property color strokeColor: pwField.text.length > 0 ? "#ffffff" : root.colInkFaint
                            onStrokeColorChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d"); ctx.reset();
                                ctx.strokeStyle = strokeColor;
                                ctx.lineWidth = 1.5;
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                ctx.beginPath(); ctx.moveTo(3, 8); ctx.lineTo(13, 8); ctx.stroke();
                                ctx.beginPath(); ctx.moveTo(9, 4); ctx.lineTo(13, 8); ctx.lineTo(9, 12); ctx.stroke();
                            }
                        }
                    }

                    onClicked: {
                        if (pwField.text.length === 0) return
                        typingTimer.stop()
                        loginRoot.loginAttempt(loginRoot.userName, pwField.text, sessionSelector.sessionIndex)
                    }
                }
            }

            // Sub-line status
            Text {
                renderType: Text.NativeRendering
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                lineHeight: 1.4
                font.family: loginRoot.fMono
                font.pixelSize: 11
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.76 
                topPadding: 15

                text: {
                    if (loginRoot.statusMessage !== "") {
                        var c = root.colInkSoft
                        if (loginRoot.authState === "wrong" || loginRoot.authState === "error") c = "#d99089"
                        return "<font color='" + c + "'>" + loginRoot.statusMessage.toLowerCase() + "</font>"
                    }
                    if (loginRoot.authState === "wrong") return "<font color='#d99089'>incorrect — try again</font>"
                    if (loginRoot.authState === "auth") return "<font color='" + root.accent + "'>authenticating…</font>"
                    if (loginRoot.authState === "ok") return "<font color='" + root.accent + "'>welcome · launching " + sessionSelector.currentLabel.toLowerCase() + "</font>"
                    return "" 
                }
            }
        }
    }

    // Footer
    Item {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottomMargin: Math.max(36, Math.min(84, loginRoot.width * 0.05))
        anchors.leftMargin: Math.max(36, Math.min(84, loginRoot.width * 0.05))
        anchors.rightMargin: Math.max(36, Math.min(84, loginRoot.width * 0.05))
        height: 48 

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Text {
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatTime(loginRoot.now, "HH:mm") + " · " + Qt.formatDate(loginRoot.now, "dddd, d MMMM yyyy")
                font.family: loginRoot.fItalic
                font.italic: true
                font.pixelSize: 25 
                color: root.colInkSoft
            }
            Rectangle {
                width: 12; height: 22 
                color: root.accent
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 2
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 1; duration: 0 }
                    PauseAnimation { duration: 580 }
                    NumberAnimation { to: 0; duration: 0 }
                    PauseAnimation { duration: 470 }
                }
            }
        }

        PowerButtons {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}

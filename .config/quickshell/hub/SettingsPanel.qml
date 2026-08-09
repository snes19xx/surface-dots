import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../lib" as Lib

Item {
    id: root
    property QtObject theme: null
    property string profileImagePath: ""
    signal wallpaperRequested()
    signal toastRequested(string msg)
    implicitHeight: flickable.contentHeight + 4

    function hexToHsl(hex) {
        hex = String(hex).replace(/[^0-9a-fA-F]/g, '')
        if (hex.length !== 6) return {h:0,s:50,l:50}
        var r=parseInt(hex.slice(0,2),16)/255, g=parseInt(hex.slice(2,4),16)/255, b=parseInt(hex.slice(4,6),16)/255
        var mx=Math.max(r,g,b), mn=Math.min(r,g,b), h=0, s=0, l=(mx+mn)/2
        if (mx!==mn){var d=mx-mn;s=l>0.5?d/(2-mx-mn):d/(mx+mn);if(mx===r)h=((g-b)/d+(g<b?6:0))/6;else if(mx===g)h=((b-r)/d+2)/6;else h=((r-g)/d+4)/6}
        return {h:Math.round(h*360),s:Math.round(s*100),l:Math.round(l*100)}
    }
    function hslToHex(h,s,l){s/=100;l/=100;var a=s*Math.min(l,1-l);function f(n){var k=(n+h/30)%12,c=l-a*Math.max(Math.min(k-3,9-k,1),-1),v=Math.round(255*c);return(v<16?'0':'')+v.toString(16)}return '#'+f(0)+f(8)+f(4)}
    function validHex(s){return /^#[0-9a-fA-F]{6}$/.test(String(s))}
    function hex6(c){var s=String(c);return s.length===9 ? "#"+s.slice(3) : s}
    function _h2(v){var n=Math.round(Math.max(0,Math.min(1,v))*255);return (n<16?'0':'')+n.toString(16)}
    function flatHex(fg,bg){
        var a=fg.a
        return "#"+_h2(fg.r*a+bg.r*(1-a))+_h2(fg.g*a+bg.g*(1-a))+_h2(fg.b*a+bg.b*(1-a))
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        contentHeight: grid.implicitHeight
        contentWidth: width
        clip: true
        flickDeceleration: 160; maximumFlickVelocity: 1800; boundsBehavior: Flickable.StopAtBounds
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (ev) => {
                var base=wAnim.running?wAnim.to:flickable.contentY
                var step=Math.abs(ev.angleDelta.y)*1.1+24
                var newY=Math.max(0,Math.min(base+(ev.angleDelta.y>0?-step:step),Math.max(0,flickable.contentHeight-flickable.height)))
                wAnim.to=newY; wAnim.restart(); ev.accepted=true
            }
        }
        NumberAnimation { id: wAnim; target: flickable; property: "contentY"; duration: 520; easing.type: Easing.OutExpo }

        GridLayout {
            id: grid
            width: flickable.width
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            // 1. APPEARANCE
            SCard {
                label: "Appearance"
                Layout.columnSpan: 2; Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    SLabel { text: "Theme" }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 84; height: 28; radius: 7
                        color: root.theme ? root.theme.bgItem : "#2d353b"
                        border.width: 1; border.color: root.theme ? root.theme.outline : "#333"
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 3; spacing: 3
                            Rectangle {
                                Layout.fillWidth: true; Layout.fillHeight: true; radius: 5
                                color: root.theme && root.theme.isDarkMode ? root.theme.accent : "transparent"
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Item {
                                    anchors.centerIn: parent; width: 18; height: 18
                                    Image { id: darkIcon; anchors.fill: parent; source: "../lib/darkmode.svg"; sourceSize: Qt.size(30,30); visible: false }
                                    ColorOverlay { anchors.fill: darkIcon; source: darkIcon
                                        color: root.theme && root.theme.isDarkMode ? root.theme.textOnAccent : root.theme ? root.theme.textSecondary : "#888"
                                        Behavior on color { ColorAnimation { duration: 180 } } }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true; Layout.fillHeight: true; radius: 5
                                color: root.theme && !root.theme.isDarkMode ? root.theme.accent : "transparent"
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Item {
                                    anchors.centerIn: parent; width: 18; height: 18
                                    Image { id: lightIcon; anchors.fill: parent; source: "../lib/lightmode.svg"; sourceSize: Qt.size(28,28); visible: false }
                                    ColorOverlay { anchors.fill: lightIcon; source: lightIcon
                                        color: root.theme && !root.theme.isDarkMode ? root.theme.textOnAccent : root.theme ? root.theme.textSecondary : "#888"
                                        Behavior on color { ColorAnimation { duration: 180 } } }
                                }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.theme) root.theme.toggle() }
                    }
                }
                SDivider {}
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    CPicker {
                        Layout.fillWidth: true; label: "Hub accent"
                        currentHex: root.theme ? root.flatHex(root.theme.accent, root.theme.bgMain) : "#759b61"
                        onPicked: (hex) => { Lib.Configuration.customAccent=hex; Lib.Configuration.useCustomColors=true; Lib.Configuration.save() }
                    }
                    CPicker {
                        Layout.fillWidth: true; label: "Background"
                        currentHex: root.theme ? root.hex6(root.theme.bgMain) : "#141719"
                        onPicked: (hex) => { Lib.Configuration.customBg=hex; Lib.Configuration.useCustomColors=true; Lib.Configuration.save() }
                    }
                    CPicker {
                        Layout.fillWidth: true; label: "Bar accent"
                        currentHex: String(Lib.Configuration.taskbarAccent)
                        onPicked: (hex) => { Lib.Configuration.taskbarAccent=hex; Lib.Configuration.save() }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    SBtn { label: "Reset colors"
                        onTriggered: { Lib.Configuration.useCustomColors=false; Lib.Configuration.taskbarAccent="#759b61"; Lib.Configuration.save() }
                    }
                    Item { Layout.fillWidth: true }
                    SBtn { label: " Wallpaper"; accent: true; onTriggered: root.wallpaperRequested() }
                }
            }

            //  2. WEATHER API 
            SCard {
                label: "Weather API"
                Layout.fillWidth: true; Layout.fillHeight: true

                FileView { id: weatherConf; path: Quickshell.env("HOME")+"/.config/quickshell/weather_api.conf" }
                SField { id: apiKeyField; label: "API Key (OpenWeatherMap)"; isPassword: true; text: Lib.Configuration.weatherApiKey }
                SField { Layout.fillWidth: true; id: latField; label: "Latitude"; text: Lib.Configuration.weatherLat }
                SField { Layout.fillWidth: true; id: lonField; label: "Longitude"; text: Lib.Configuration.weatherLon }
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    SBtn { label: "Save & refresh"; accent: true
                        onTriggered: {
                            Lib.Configuration.weatherApiKey=apiKeyField.text.trim()
                            Lib.Configuration.weatherLat=latField.text.trim()
                            Lib.Configuration.weatherLon=lonField.text.trim()
                            Lib.Configuration.save()
                            weatherConf.setText('API_KEY="'+apiKeyField.text.trim()+'"\nLAT="'+latField.text.trim()+'"\nLON="'+lonField.text.trim()+'"\n')
                            Quickshell.execDetached(["rm","-f",Quickshell.env("HOME")+"/.cache/quickshell/weather.json"])
                        }
                    }
                }
            }

            //  2b. POWER MENU 
            SCard {
                label: "Power Menu"
                Layout.fillWidth: true; Layout.fillHeight: true

                SLabel { text: "Style" }
                // Segmented switch: Living Things & Cassini
                Rectangle {
                    Layout.fillWidth: true; height: 34; radius: 8
                    color: root.theme ? root.theme.bgItem : "#2d353b"
                    border.width: 1; border.color: root.theme ? root.theme.outline : "#333"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 3; spacing: 3
                        Repeater {
                            model: [ { id: "life", label: "Living Things" }, { id: "cassini", label: "Cassini" } ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: Lib.Configuration.powerMenuStyle === modelData.id
                                Layout.fillWidth: true; Layout.fillHeight: true; radius: 6
                                color: active ? (root.theme ? root.theme.accent : "#759b61") : "transparent"
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Text {
                                    anchors.centerIn: parent; text: modelData.label
                                    font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 14
                                    font.weight: active ? 600 : 400
                                    color: active ? (root.theme ? root.theme.textOnAccent : "#232a2e")
                                                  : (root.theme ? root.theme.textSecondary : "#888")
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: Lib.Configuration.setPowerMenuStyle(modelData.id)
                                }
                            }
                        }
                    }
                }
                SDivider {}

                // Accent for the *selected* skin, saved separately per theme.
                // Living Things tunes its `accent`; Cassini tunes its `selBg`.
                CPicker {
                    readonly property bool _cassini: Lib.Configuration.powerMenuStyle === "cassini"
                    readonly property bool _dark: !!(root.theme && root.theme.isDarkMode)
                    label: (_cassini ? "Cassini" : "Living") + " accent · " + (_dark ? "dark" : "light")
                    currentHex: root.hex6(_cassini
                        ? (_dark ? Lib.Configuration.powerMenuCassiniDark : Lib.Configuration.powerMenuCassiniLight)
                        : (_dark ? Lib.Configuration.powerMenuLifeDark    : Lib.Configuration.powerMenuLifeLight))
                    onPicked: (hex) => Lib.Configuration.setPowerMenuColor(
                        Lib.Configuration.powerMenuStyle, _dark, hex)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    SBtn { label: "Reset accents"; onTriggered: Lib.Configuration.resetPowerMenuColors() }
                }

                Text {
                    text: "Skin & accent for the ALT+F4 power menu. Each accent is saved per light/dark theme."
                    font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 12
                    color: root.theme ? root.theme.textSecondary : "#888"; opacity: 0.7
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; Layout.topMargin: 2
                }
            }

            //  3. LAYOUT & TASKBAR
            SCard {
                label: "Layout & Taskbar"
                Layout.fillWidth: true; Layout.fillHeight: true

                SToggle { label: "Always dock mode"; checked: Lib.Configuration.taskbarForceDockMode
                    onToggled: (v)=>{Lib.Configuration.taskbarForceDockMode=v; Lib.Configuration.save()} }
                SToggle { label: "Always workspace mode"; checked: Lib.Configuration.taskbarForceWorkspaceMode
                    onToggled: (v)=>{Lib.Configuration.taskbarForceWorkspaceMode=v; Lib.Configuration.save()} }
                SDivider {}
                RowLayout {
                    Layout.fillWidth: true
                    SLabel { text: "Excl. zone" }
                    Item { Layout.fillWidth: true }
                    Text { text: Lib.Configuration.taskbarExclusiveZone+" px"
                        font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 15
                        color: root.theme ? root.theme.textSecondary : "#888" }
                }
                SSlider { from: 30; to: 80; value: Lib.Configuration.taskbarExclusiveZone
                    onMoved: (v)=>{Lib.Configuration.taskbarExclusiveZone=v; Lib.Configuration.save()} }
                SDivider {}
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    SLabel { text: "Layout" }
                    Item { Layout.fillWidth: true }
                    SBtn { label: "Taskbar"; accent: Lib.Configuration.barStyle !== "top"
                        onTriggered: { Lib.Configuration.barStyle = "task"; Lib.Configuration.save() }
                    }
                    SBtn { label: "Top bar"; accent: Lib.Configuration.barStyle === "top"
                        onTriggered: { Lib.Configuration.barStyle = "top"; Lib.Configuration.save() }
                    }
                }
                SDivider {}
                SToggle { label: "Custom taskbar BG"; checked: Lib.Configuration.taskbarCustomBg
                    onToggled: (v)=>{ Lib.Configuration.taskbarCustomBg=v; Lib.Configuration.save() }
                }
                CPicker { label: "Taskbar BG"
                    currentHex: String(Lib.Configuration.taskbarCustomBgColor)
                    onPicked: (hex)=>{ Lib.Configuration.taskbarCustomBgColor=hex; Lib.Configuration.save() }
                }
            }

            //  4. SCREEN BORDERS 
            SCard {
                label: "Screen Borders"
                Layout.fillWidth: true; Layout.fillHeight: true

                SToggle { label: "Enabled"; checked: Lib.Configuration.bordersEnabled
                    onToggled: (v)=>{
                        Lib.Configuration.bordersEnabled=v; Lib.Configuration.save()
                        if (v) root.toastRequested("adjust gaps_out in your hypr config")
                    }
                }
                SToggle { label: "Always visible"; checked: Lib.Configuration.bordersForceVisible
                    onToggled: (v)=>{ Lib.Configuration.bordersForceVisible=v; Lib.Configuration.save()
                        if (v) root.toastRequested("adjust gaps_out in your hypr config") } }
                SDivider {}
                RowLayout {
                    Layout.fillWidth: true
                    SLabel { text: "Thickness" }
                    Item { Layout.fillWidth: true }
                    Text { text: Lib.Configuration.borderThickness+" px"
                        font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 15
                        color: root.theme ? root.theme.textSecondary : "#888" }
                }
                SSlider { from: 1; to: 20; value: Lib.Configuration.borderThickness
                    onMoved: (v)=>{ Lib.Configuration.borderThickness=v; Lib.Configuration.save(); root.toastRequested("adjust gaps_out in your hypr config") } }
                SDivider {}
                SToggle { label: "Custom border color"; checked: Lib.Configuration.borderUseCustomColor
                    onToggled: (v)=>{Lib.Configuration.borderUseCustomColor=v; Lib.Configuration.save()} }
                CPicker { label: "Border color"
                    currentHex: String(Lib.Configuration.borderFrameColor)
                    onPicked: (hex)=>{Lib.Configuration.borderFrameColor=hex; Lib.Configuration.save()}
                }
            }

            //  5. PROFILE & EVENTS
            SCard {
                label: "Profile & Events"
                Layout.columnSpan: 2; Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    Rectangle {
                        width: 44; height: 44; radius: 8; clip: true
                        color: root.theme ? root.theme.bgItem : "#2d353b"
                        border.width: 1; border.color: root.theme ? root.theme.outline : "#333"
                        Image {
                            anchors.fill: parent
                            source: root.profileImagePath !== ""
                                ? (root.profileImagePath.startsWith("file://") ? root.profileImagePath : "file://"+root.profileImagePath)
                                : ""
                            fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true
                        }
                        Text { anchors.centerIn: parent; text: ""; font.family: root.theme ? root.theme.iconFont : ""; font.pixelSize: 20
                            color: root.theme ? root.theme.textSecondary : "#888"; opacity: 0.4
                            visible: root.profileImagePath === "" }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        Text { text: "Profile picture path"; font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 14
                            color: root.theme ? root.theme.textSecondary : "#888" }
                        Rectangle {
                            Layout.fillWidth: true; height: 30; radius: 7
                            color: root.theme ? root.theme.bgItem : "#2d353b"
                            border.width: 1; border.color: pfpIn.activeFocus ? (root.theme ? root.theme.accent : "#759b61") : (root.theme ? root.theme.outline : "#333")
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Text {
                                anchors { fill: parent; margins: 7 }
                                verticalAlignment: Text.AlignVCenter
                                text: "/path/to/photo.jpg"; font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 14
                                color: root.theme ? root.theme.textSecondary : "#888"; opacity: 0.45
                                visible: pfpIn.text === ""
                            }
                            TextInput {
                                id: pfpIn
                                anchors { fill: parent; margins: 7 }
                                verticalAlignment: Text.AlignVCenter
                                font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 14
                                color: root.theme ? root.theme.textPrimary : "#dde5df"; clip: true; selectByMouse: true
                                selectionColor: root.theme ? Qt.rgba(root.theme.accent.r,root.theme.accent.g,root.theme.accent.b,0.35) : "#40759b61"
                                text: Lib.Configuration.profileImageOverride
                                onEditingFinished: { Lib.Configuration.profileImageOverride=text; Lib.Configuration.save() }
                            }
                        }
                    }
                    ColumnLayout {
                        spacing: 4
                        Text { text: "Events"; font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 14
                            color: root.theme ? root.theme.textSecondary : "#888"; Layout.alignment: Qt.AlignHCenter }
                        SStepper { min: 1; max: 10; value: Lib.Configuration.maxEvents
                            onStepped: (v)=>{ Lib.Configuration.maxEvents=v; Lib.Configuration.save() }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 4; Layout.columnSpan: 2 }
        }
    }

    //  COMPONENT LIBRARY 

    component SCard: Rectangle {
        id: sc
        default property alias items: scCol.data
        property string label: ""
        Layout.fillWidth: true
        color: root.theme ? root.theme.bgCard : "#1e2326"
        radius: root.theme ? root.theme.radiusOuter : 12
        border.width: 1
        border.color: scHov.hovered
            ? Qt.rgba(root.theme ? root.theme.accent.r : 0.46, root.theme ? root.theme.accent.g : 0.61, root.theme ? root.theme.accent.b : 0.38, 0.45)
            : (root.theme ? root.theme.outline : "#333")
        implicitHeight: scCol.implicitHeight + 20
        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }
        HoverHandler { id: scHov }

        ColumnLayout {
            id: scCol
            anchors { fill: parent; margins: 10 }
            spacing: 8
            Text {
                text: sc.label
                font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 16; font.weight: 600
                color: root.theme ? root.theme.accent : "#9da9a0"
                opacity: 0.8
                Layout.bottomMargin: 2
            }
        }
    }

    component SLabel: Text {
        font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 14
        color: root.theme ? root.theme.textPrimary : "#dde5df"; Layout.fillWidth: true
    }

    component SDivider: Rectangle {
        Layout.fillWidth: true; height: 1
        color: root.theme ? root.theme.outline : "#333"; opacity: 0.5
    }

    // Toggle row 
    component SToggle: Item {
        id: tog; property string label: ""; property bool checked: false
        signal toggled(bool v)
        Layout.fillWidth: true
        implicitHeight: togRow.implicitHeight + 10

        Rectangle {
            anchors { fill: parent; leftMargin: -4; rightMargin: -4 }
            radius: 8
            color: togHov.hovered
                ? (root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.08) : "#1e2326")
                : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        HoverHandler { id: togHov; cursorShape: Qt.PointingHandCursor }

        RowLayout {
            id: togRow
            anchors { fill: parent; topMargin: 5; bottomMargin: 5 }
            spacing: 8
            Text {
                text: tog.label; font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 15
                color: root.theme ? root.theme.textPrimary : "#dde5df"; Layout.fillWidth: true
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 42; height: 24; radius: 12
                color: tog.checked ? (root.theme ? root.theme.accent : "#759b61") : (root.theme ? root.theme.subtleFill : "#2d353b")
                Behavior on color { ColorAnimation { duration: 200 } }
                border.width: 1; border.color: root.theme ? root.theme.outline : "#333"
                Rectangle {
                    x: tog.checked ? parent.width-width-3 : 3; y: 3; width: 18; height: 18; radius: 9; color: "white"
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tog.toggled(!tog.checked) }
            }
        }
    }

    component SField: ColumnLayout {
        id: sf; property string label: ""; property alias text: sfIn.text; property bool isPassword: false
        Layout.fillWidth: true; spacing: 3
        Text { text: sf.label; font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 13
            color: root.theme ? root.theme.textSecondary : "#888" }
        Rectangle {
            Layout.fillWidth: true; height: 30; radius: 7
            color: sfIn.activeFocus
                ? (root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.07) : "#2d353b")
                : sfHov.hovered ? (root.theme ? root.theme.bgItemHover : "#374145")
                : (root.theme ? root.theme.bgItem : "#2d353b")
            Behavior on color { ColorAnimation { duration: 150 } }
            border.width: 1; border.color: sfIn.activeFocus ? (root.theme ? root.theme.accent : "#759b61")
                : sfHov.hovered ? Qt.rgba(root.theme ? root.theme.accent.r : 0.46, root.theme ? root.theme.accent.g : 0.61, root.theme ? root.theme.accent.b : 0.38, 0.35)
                : (root.theme ? root.theme.outline : "#333")
            Behavior on border.color { ColorAnimation { duration: 150 } }
            HoverHandler { id: sfHov }
            TextInput {
                id: sfIn
                anchors { fill: parent; margins: 7 }
                verticalAlignment: Text.AlignVCenter
                font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 13
                color: root.theme ? root.theme.textPrimary : "#dde5df"; clip: true; selectByMouse: true
                echoMode: sf.isPassword ? TextInput.Password : TextInput.Normal
                selectionColor: root.theme ? Qt.rgba(root.theme.accent.r,root.theme.accent.g,root.theme.accent.b,0.35) : "#40759b61"
            }
        }
    }

    component SStepper: RowLayout {
        id: stp; property int value: 1; property int min: 1; property int max: 10
        signal stepped(int v)
        spacing: 4
        Rectangle {
            width: 26; height: 26; radius: 7
            color: dH.hovered ? (root.theme ? root.theme.subtleFillHover : "#374145") : (root.theme ? root.theme.subtleFill : "#2d353b")
            Behavior on color { ColorAnimation { duration: 120 } }
            border.width: 1; border.color: root.theme ? root.theme.outline : "#333"
            Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 15; color: root.theme ? root.theme.textPrimary : "#dde5df" }
            HoverHandler { id: dH; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { if(stp.value>stp.min){stp.value--;stp.stepped(stp.value)} } }
        }
        Text { text: stp.value; font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 14; font.weight: 600
            color: root.theme ? root.theme.textPrimary : "#dde5df"; width: 22; horizontalAlignment: Text.AlignHCenter }
        Rectangle {
            width: 26; height: 26; radius: 7
            color: iH.hovered ? (root.theme ? root.theme.subtleFillHover : "#374145") : (root.theme ? root.theme.subtleFill : "#2d353b")
            Behavior on color { ColorAnimation { duration: 120 } }
            border.width: 1; border.color: root.theme ? root.theme.outline : "#333"
            Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 15; color: root.theme ? root.theme.textPrimary : "#dde5df" }
            HoverHandler { id: iH; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { if(stp.value<stp.max){stp.value++;stp.stepped(stp.value)} } }
        }
    }

    component SSlider: Item {
        id: ssl; property int from: 1; property int to: 20; property int value: 7
        signal moved(int v)
        height: 28; Layout.fillWidth: true
        HoverHandler { id: slHov }
        Rectangle {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: slHov.hovered ? 7 : 5; radius: 3
            color: root.theme ? root.theme.bgItem : "#2d353b"; border.width: 1; border.color: root.theme ? root.theme.outline : "#333"
            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Rectangle {
                width: (ssl.value-ssl.from)/Math.max(1,ssl.to-ssl.from)*parent.width
                height: parent.height; radius: parent.radius
                color: root.theme ? root.theme.accent : "#759b61"
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
        Rectangle {
            x: (ssl.value-ssl.from)/Math.max(1,ssl.to-ssl.from)*(ssl.width-width)
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18; radius: 9; color: "white"
            border.width: 2
            border.color: sDrag.pressed ? (root.theme ? root.theme.accent : "#759b61")
                        : slHov.hovered ? Qt.rgba(root.theme ? root.theme.accent.r : 0.46, root.theme ? root.theme.accent.g : 0.61, root.theme ? root.theme.accent.b : 0.38, 0.6)
                        : Qt.rgba(0,0,0,0.25)
            scale: sDrag.pressed ? 1.18 : (slHov.hovered ? 1.09 : 1.0)
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            id: sDrag; anchors.fill: parent; anchors.margins: -5
            function go(mx) { var f=Math.max(0,Math.min(1,mx/ssl.width)); var v=Math.round(ssl.from+f*(ssl.to-ssl.from)); ssl.value=v; ssl.moved(v) }
            onPressed: (m)=>go(m.x); onPositionChanged: (m)=>go(m.x)
        }
    }

    component SBtn: Item {
        id: sb; property string label: ""; property bool accent: false
        signal triggered()
        implicitWidth: bTxt.implicitWidth+22; implicitHeight: 30
        scale: bMa.containsPress ? 0.91 : (bMa.containsMouse ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        Rectangle {
            anchors.fill: parent; radius: 8
            color: sb.accent
                ? (bMa.containsPress ? Qt.darker(root.theme ? root.theme.accent : "#759b61", 1.08)
                    : bMa.containsMouse ? Qt.lighter(root.theme ? root.theme.accent : "#759b61", 1.14)
                    : (root.theme ? root.theme.accent : "#759b61"))
                : (bMa.containsPress ? (root.theme ? root.theme.bgItem : "#2d353b")
                    : bMa.containsMouse ? (root.theme ? root.theme.subtleFillHover : "#374145")
                    : (root.theme ? root.theme.subtleFill : "#2d353b"))
            Behavior on color { ColorAnimation { duration: 100 } }
            border.width: 1
            border.color: sb.accent
                ? Qt.rgba(1,1,1, bMa.containsMouse ? 0.18 : 0.0)
                : (root.theme ? root.theme.outline : "#333")
            Behavior on border.color { ColorAnimation { duration: 120 } }
            Text { id: bTxt; anchors.centerIn: parent; text: sb.label
                font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 14
                color: sb.accent ? (root.theme ? root.theme.textOnAccent : "#232a2e") : (root.theme ? root.theme.textPrimary : "#dde5df") }
        }
        MouseArea { id: bMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: sb.triggered() }
    }

    // Color picker: label + swatch + hex input, click swatch to expand H/S/L
    component CPicker: ColumnLayout {
        id: cp; property string label: ""; property string currentHex: "#759b61"
        signal picked(string hex)
        Layout.fillWidth: true; spacing: 5

        property int  _h: 0; property int _s: 50; property int _l: 50
        property bool _open: false; property bool _lock: false; property bool _userEditing: false

        onCurrentHexChanged: {
            if (!_userEditing && !_lock && root.validHex(currentHex)) {
                _lock = true
                var hsl=root.hexToHsl(currentHex); _h=hsl.h; _s=hsl.s; _l=hsl.l
                hexIn.text=currentHex
                _lock = false
            }
        }
        // _userEditing guards against infinite loops when the user is typing a hex value, which triggers onCurrentHexChanged.
        Timer { id: editReset; interval: 300; onTriggered: cp._userEditing = false }
        function applyHex(hex) {
            if (_lock) return; _lock=true; _userEditing=true; editReset.restart()
            if (root.validHex(hex)) { hexIn.text=hex; var hsl=root.hexToHsl(hex); _h=hsl.h; _s=hsl.s; _l=hsl.l; cp.picked(hex) }
            _lock=false
        }
        function applyHsl() {
            if (_lock) return; _lock=true; _userEditing=true; editReset.restart()
            var hex=root.hslToHex(_h,_s,_l); hexIn.text=hex; cp.picked(hex); _lock=false
        }
        Component.onCompleted: {
            if (root.validHex(currentHex)) { var hsl=root.hexToHsl(currentHex); _h=hsl.h; _s=hsl.s; _l=hsl.l; hexIn.text=currentHex }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Text { text: cp.label; font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 14
                color: root.theme ? root.theme.textPrimary : "#dde5df"; Layout.fillWidth: true }
            Rectangle {
                width: 24; height: 24; radius: 6
                color: root.validHex(hexIn.text) ? hexIn.text : (root.theme ? root.theme.accent : "#759b61")
                border.width: 2; border.color: cp._open ? (root.theme ? root.theme.accent : "#759b61") : (root.theme ? root.theme.outline : "#333")
                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cp._open=!cp._open }
            }
            Rectangle {
                width: 82; height: 26; radius: 6
                color: root.theme ? root.theme.bgItem : "#2d353b"
                border.width: 1; border.color: hexIn.activeFocus ? (root.theme ? root.theme.accent : "#759b61") : (root.theme ? root.theme.outline : "#333")
                Behavior on border.color { ColorAnimation { duration: 150 } }
                TextInput {
                    id: hexIn
                    anchors { fill: parent; margins: 5 }
                    verticalAlignment: Text.AlignVCenter
                    font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 12; font.letterSpacing: 0.5
                    color: root.theme ? root.theme.textPrimary : "#dde5df"; clip: true; selectByMouse: true
                    selectionColor: root.theme ? Qt.rgba(root.theme.accent.r,root.theme.accent.g,root.theme.accent.b,0.35) : "#40759b61"
                    validator: RegularExpressionValidator { regularExpression: /^#?[0-9a-fA-F]{0,6}$/ }
                    onEditingFinished: { var h=text.startsWith('#')?text:'#'+text; cp.applyHex(h) }
                }
            }
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: cp._open ? sliderCol.implicitHeight + 4 : 0
            clip: true
            Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            ColumnLayout {
                id: sliderCol; width: parent.width; spacing: 5
                CSlider { label: "H"; value: cp._h/360
                    c0:"#ff0000"; c1:"#ffff00"; c2:"#00ff00"; c3:"#00ffff"; c4:"#0000ff"; c5:"#ff00ff"; c6:"#ff0000"
                    onMv: (v)=>{cp._h=Math.round(v*360); cp.applyHsl()} }
                CSlider { label: "S"; value: cp._s/100
                    c0:Qt.hsla(cp._h/360,0,cp._l/100,1); c1:Qt.hsla(cp._h/360,0.17,cp._l/100,1)
                    c2:Qt.hsla(cp._h/360,0.33,cp._l/100,1); c3:Qt.hsla(cp._h/360,0.5,cp._l/100,1)
                    c4:Qt.hsla(cp._h/360,0.67,cp._l/100,1); c5:Qt.hsla(cp._h/360,0.83,cp._l/100,1)
                    c6:Qt.hsla(cp._h/360,1,cp._l/100,1)
                    onMv: (v)=>{cp._s=Math.round(v*100); cp.applyHsl()} }
                CSlider { label: "L"; value: cp._l/100
                    c0:"#000000"; c1:Qt.hsla(cp._h/360,cp._s/100,0.17,1)
                    c2:Qt.hsla(cp._h/360,cp._s/100,0.33,1); c3:Qt.hsla(cp._h/360,cp._s/100,0.5,1)
                    c4:Qt.hsla(cp._h/360,cp._s/100,0.67,1); c5:Qt.hsla(cp._h/360,cp._s/100,0.83,1)
                    c6:"#ffffff"
                    onMv: (v)=>{cp._l=Math.round(v*100); cp.applyHsl()} }
            }
        }
    }

    component CSlider: RowLayout {
        id: cs; property string label: ""; property real value: 0.5
        property color c0:"black"; property color c1:"black"; property color c2:"gray"
        property color c3:"gray";  property color c4:"gray";  property color c5:"white"; property color c6:"white"
        signal mv(real v)
        Layout.fillWidth: true; spacing: 5
        Text { text: cs.label; font.family: root.theme ? root.theme.textFont : ""; font.pixelSize: 10
            color: root.theme ? root.theme.textSecondary : "#888"; width: 10 }
        Item {
            Layout.fillWidth: true; height: 20
            Rectangle {
                id: csTk; anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: 8; radius: 4; border.width: 1; border.color: Qt.rgba(0,0,0,0.2)
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0.000; color: cs.c0 }
                    GradientStop { position: 0.167; color: cs.c1 }
                    GradientStop { position: 0.333; color: cs.c2 }
                    GradientStop { position: 0.500; color: cs.c3 }
                    GradientStop { position: 0.667; color: cs.c4 }
                    GradientStop { position: 0.833; color: cs.c5 }
                    GradientStop { position: 1.000; color: cs.c6 }
                }
            }
            Rectangle {
                x: Math.max(0,Math.min(cs.value*(parent.width-width),parent.width-width))
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16; radius: 8; color: "white"
                border.width: 2; border.color: csDrag.pressed ? (root.theme ? root.theme.accent : "#759b61") : Qt.rgba(0,0,0,0.3)
                scale: csDrag.pressed ? 1.12 : 1.0; Behavior on scale { NumberAnimation { duration: 100 } }
            }
            MouseArea { id: csDrag; anchors.fill: parent; anchors.margins: -4
                onPressed:        (m)=>cs.mv(Math.max(0,Math.min(1,m.x/csTk.width)))
                onPositionChanged:(m)=>cs.mv(Math.max(0,Math.min(1,m.x/csTk.width)))
            }
        }
    }
}

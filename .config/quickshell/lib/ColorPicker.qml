import QtQuick
import QtQuick.Layouts

// Color picker: label + swatch + hex input, click swatch to expand H/S/L
ColumnLayout {
    id: cp
    property QtObject theme: null
    property string label: ""
    property string currentHex: "#759b61"
    signal picked(string hex)
    Layout.fillWidth: true; spacing: 5

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

    property int  _h: 0; property int _s: 50; property int _l: 50
    property bool _open: false; property bool _lock: false; property bool _userEditing: false

    onCurrentHexChanged: {
        if (!_userEditing && !_lock && validHex(currentHex)) {
            _lock = true
            var hsl=hexToHsl(currentHex); _h=hsl.h; _s=hsl.s; _l=hsl.l
            hexIn.text=currentHex
            _lock = false
        }
    }
    // _userEditing guards against infinite loops when the user is typing a hex value, which triggers onCurrentHexChanged.
    Timer { id: editReset; interval: 300; onTriggered: cp._userEditing = false }
    function applyHex(hex) {
        if (_lock) return; _lock=true; _userEditing=true; editReset.restart()
        if (validHex(hex)) { hexIn.text=hex; var hsl=hexToHsl(hex); _h=hsl.h; _s=hsl.s; _l=hsl.l; cp.picked(hex) }
        _lock=false
    }
    function applyHsl() {
        if (_lock) return; _lock=true; _userEditing=true; editReset.restart()
        var hex=hslToHex(_h,_s,_l); hexIn.text=hex; cp.picked(hex); _lock=false
    }
    Component.onCompleted: {
        if (validHex(currentHex)) { var hsl=hexToHsl(currentHex); _h=hsl.h; _s=hsl.s; _l=hsl.l; hexIn.text=currentHex }
    }

    RowLayout {
        Layout.fillWidth: true; spacing: 6
        Text { text: cp.label; font.family: cp.theme ? cp.theme.textFont : ""; font.pixelSize: 14
            color: cp.theme ? cp.theme.textPrimary : "#dde5df"; Layout.fillWidth: true }
        Rectangle {
            width: 24; height: 24; radius: 6
            color: cp.validHex(hexIn.text) ? hexIn.text : (cp.theme ? cp.theme.accent : "#759b61")
            border.width: 2; border.color: cp._open ? (cp.theme ? cp.theme.accent : "#759b61") : (cp.theme ? cp.theme.outline : "#333")
            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cp._open=!cp._open }
        }
        Rectangle {
            width: 82; height: 26; radius: 6
            color: cp.theme ? cp.theme.bgItem : "#2d353b"
            border.width: 1; border.color: hexIn.activeFocus ? (cp.theme ? cp.theme.accent : "#759b61") : (cp.theme ? cp.theme.outline : "#333")
            Behavior on border.color { ColorAnimation { duration: 150 } }
            TextInput {
                id: hexIn
                anchors { fill: parent; margins: 5 }
                verticalAlignment: Text.AlignVCenter
                font.family: cp.theme ? cp.theme.textFont : ""; font.pixelSize: 12; font.letterSpacing: 0.5
                color: cp.theme ? cp.theme.textPrimary : "#dde5df"; clip: true; selectByMouse: true
                selectionColor: cp.theme ? Qt.rgba(cp.theme.accent.r,cp.theme.accent.g,cp.theme.accent.b,0.35) : "#40759b61"
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

    component CSlider: RowLayout {
        id: cs; property string label: ""; property real value: 0.5
        property color c0:"black"; property color c1:"black"; property color c2:"gray"
        property color c3:"gray";  property color c4:"gray";  property color c5:"white"; property color c6:"white"
        signal mv(real v)
        Layout.fillWidth: true; spacing: 5
        Text { text: cs.label; font.family: cp.theme ? cp.theme.textFont : ""; font.pixelSize: 10
            color: cp.theme ? cp.theme.textSecondary : "#888"; width: 10 }
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
                border.width: 2; border.color: csDrag.pressed ? (cp.theme ? cp.theme.accent : "#759b61") : Qt.rgba(0,0,0,0.3)
                scale: csDrag.pressed ? 1.12 : 1.0; Behavior on scale { NumberAnimation { duration: 100 } }
            }
            MouseArea { id: csDrag; anchors.fill: parent; anchors.margins: -4
                onPressed:        (m)=>cs.mv(Math.max(0,Math.min(1,m.x/csTk.width)))
                onPositionChanged:(m)=>cs.mv(Math.max(0,Math.min(1,m.x/csTk.width)))
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: win
    
    // RECEIVE THEME FROM SHELL 
    required property QtObject theme
    property bool isDarkMode: theme.isDarkMode

    //  DEFINED COLORS 
    property color frameColor: isDarkMode ? '#141719' : '#F0ECE6'

    //  CONFIGURATION 
    property int thickness: 7
    property int bottomHeight: 40
    property int radius: 10
    
    // Controls for border visibility
    property bool forceAlwaysVisible: false // Testing switch (toggled from shell.qml)
    property bool showTopAndSides: true
    property real borderOpacity: (showTopAndSides || forceAlwaysVisible) ? 1.0 : 0.0
    
    // Pin to edges
    anchors { top: true; bottom: true; left: true; right: true }
    
    // Layer setup
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: 38
    mask: Region {}

    color: "transparent"

    //  FUNCTION TO CONTROL BORDERS 
    function setTopSidesVisible(visible) {
        showTopAndSides = visible
    }

    //  THE FRAME 
    // 1. Top Bar
    Rectangle {
        height: win.thickness
        anchors { top: parent.top; left: parent.left; right: parent.right }
        color: win.frameColor
        opacity: win.borderOpacity
        visible: opacity > 0
        
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
        Behavior on color { ColorAnimation { duration: 200 } } // Smooth color transition
    }
    
    // 2. Bottom Bar (TASKBAR)
    Rectangle {
        height: win.bottomHeight
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        color: win.frameColor
        
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    // 3. Left Bar
    Rectangle {
        width: win.thickness
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        anchors.topMargin: win.thickness; anchors.bottomMargin: win.bottomHeight
        color: win.frameColor
        opacity: win.borderOpacity
        visible: opacity > 0
        
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    // 4. Right Bar
    Rectangle {
        width: win.thickness
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        anchors.topMargin: win.thickness; anchors.bottomMargin: win.bottomHeight
        color: win.frameColor
        opacity: win.borderOpacity
        visible: opacity > 0
        
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    // 5. THE CORNERS
    // Top Left
    Canvas {
        width: win.radius; height: win.radius
        anchors { top: parent.top; left: parent.left }
        anchors.topMargin: win.thickness; anchors.leftMargin: win.thickness
        opacity: win.borderOpacity
        visible: opacity > 0
        
        // Watch color change to trigger repaint
        property color c: win.frameColor
        onCChanged: requestPaint()
        
        onPaint: {
            var ctx = getContext("2d")
            drawInvertedCorner(ctx, width, height, "TL")
        }
        
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
    }

    // Top Right
    Canvas {
        width: win.radius; height: win.radius
        anchors { top: parent.top; right: parent.right }
        anchors.topMargin: win.thickness; anchors.rightMargin: win.thickness
        opacity: win.borderOpacity
        visible: opacity > 0
        
        property color c: win.frameColor
        onCChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            drawInvertedCorner(ctx, width, height, "TR")
        }
        
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
    }

    // Bottom Left
    Canvas {
        width: win.radius; height: win.radius
        anchors { bottom: parent.bottom; left: parent.left }
        anchors.bottomMargin: win.bottomHeight; anchors.leftMargin: win.thickness
        opacity: win.borderOpacity
        visible: opacity > 0
        
        property color c: win.frameColor
        onCChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            drawInvertedCorner(ctx, width, height, "BL")
        }
        
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
    }

    // Bottom Right
    Canvas {
        width: win.radius; height: win.radius
        anchors { bottom: parent.bottom; right: parent.right }
        anchors.bottomMargin: win.bottomHeight; anchors.rightMargin: win.thickness
        opacity: win.borderOpacity
        visible: opacity > 0
        
        property color c: win.frameColor
        onCChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            drawInvertedCorner(ctx, width, height, "BR")
        }
        
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
    }

    function drawInvertedCorner(ctx, w, h, type) {
        ctx.reset();
        ctx.fillStyle = win.frameColor;
        ctx.beginPath();
        
        // Draw the square background
        ctx.moveTo(0,0); ctx.lineTo(w,0); ctx.lineTo(w,h); ctx.lineTo(0,h); ctx.closePath();
        
        // Cut the circle
        if (type === "TL") { 
            ctx.globalCompositeOperation = "source-over";
            ctx.beginPath(); ctx.moveTo(0,0); ctx.lineTo(w,0); 
            ctx.arc(w, h, w, 1.5*Math.PI, Math.PI, true); 
            ctx.lineTo(0,0); ctx.fill();
        } else if (type === "TR") {
            ctx.beginPath(); ctx.moveTo(w,0); ctx.lineTo(w,h); 
            ctx.arc(0, h, w, 0, 1.5*Math.PI, true); 
            ctx.lineTo(w,0); ctx.fill();
        } else if (type === "BL") {
             ctx.beginPath(); ctx.moveTo(0,h); ctx.lineTo(0,0); 
             ctx.arc(w, 0, w, Math.PI, 0.5*Math.PI, true);
             ctx.lineTo(0,h); ctx.fill();
        } else if (type === "BR") {
             ctx.beginPath(); ctx.moveTo(w,h); ctx.lineTo(0,h); 
             ctx.arc(0, 0, w, 0.5*Math.PI, 0, true);
             ctx.lineTo(w,h); ctx.fill();
        }
    }
}
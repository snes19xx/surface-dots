pragma Singleton
import QtQuick
import Quickshell

QtObject {
    function sh(cmd)  { return ["bash", "-lc", cmd] }
    function det(cmd) { Quickshell.execDetached(sh(cmd)) }

    // Warp the pointer onto its own position.
    function nudgeCursor() {
        det(`sleep 0.05; read x y <<< "$(hyprctl cursorpos | tr -d ',')"; hyprctl dispatch "hl.dsp.cursor.move({ x = $x, y = $y })"`)
    }
}

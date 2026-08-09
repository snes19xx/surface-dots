pragma Singleton
import QtQuick
import Quickshell

QtObject {
    function sh(cmd)  { return ["bash", "-lc", cmd] }
    function det(cmd) { Quickshell.execDetached(sh(cmd)) }
}

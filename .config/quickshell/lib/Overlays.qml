pragma Singleton
import QtQuick
import Quickshell

// Shared switches for overlays the shell keeps loaded. Spawning a second
// quickshell process per menu costs a full Qt and QML startup before anything
// draws, so these are in the running instance instead.
Scope {
    property bool wifiOpen: false
}

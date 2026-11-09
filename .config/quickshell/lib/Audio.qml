pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink

    // audio is only valid while the tracker holds the sink
    readonly property bool ready: sink !== null && sink.ready && sink.audio !== null
    readonly property real volume: ready ? Math.max(0, Math.min(1, sink.audio.volume)) : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    readonly property string sinkName: sink ? String(sink.description) : ""
    readonly property string bluetoothName:
        (sink && String(sink.name).indexOf("bluez_") === 0) ? String(sink.description) : ""

    function setVolume(v) {
        if (!root.ready) return
        root.sink.audio.volume = Math.max(0, Math.min(1, v))
    }

    function toggleMute() {
        if (!root.ready) return
        root.sink.audio.muted = !root.sink.audio.muted
    }

    // Moves to the new node when the default sink changes
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}

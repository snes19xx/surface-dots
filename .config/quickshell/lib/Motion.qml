pragma Singleton
import QtQuick

// Use through lib/Spring*.qml. Keep mass at 1.0, since Qt's damping 1.0 diverges below it.
QtObject {
    readonly property bool reduce: Configuration.reduceMotion

    readonly property var snappy:  ({ spring: reduce ? 19.0 : 7.0, damping: reduce ? 1.0 : 0.40, mass: 1.0, epsilon: 0.005 })
    readonly property var bouncy:  ({ spring: reduce ? 16.0 : 5.0, damping: reduce ? 1.0 : 0.20, mass: 1.0, epsilon: 0.005 })
    readonly property var smooth:  ({ spring: reduce ? 14.0 : 5.0, damping: reduce ? 1.0 : 0.55, mass: 1.0, epsilon: 0.01 })
    readonly property var gentle:  ({ spring: reduce ? 11.0 : 5.5, damping: reduce ? 1.0 : 0.75, mass: 1.0, epsilon: 0.01 })
}

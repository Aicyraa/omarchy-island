pragma ComponentBehavior: Bound

import QtQuick
import "../Theme"

QtObject {
    id: root

    property bool hovered: false
    property int enterDelay: Tokens.motion.dwellIntent
    property int exitDelay: Tokens.motion.hoverGrace
    property bool active: false

    onHoveredChanged: {
        if (root.hovered) {
            exitDelayTimer.stop()
            if (root.enterDelay <= 0)
                root.active = true
            else
                enterDelayTimer.restart()
        } else {
            enterDelayTimer.stop()
            if (root.exitDelay <= 0)
                root.active = false
            else
                exitDelayTimer.restart()
        }
    }

    readonly property Timer enterTimer: Timer {
        id: enterDelayTimer

        interval: root.enterDelay
        onTriggered: if (root.hovered) root.active = true
    }

    readonly property Timer exitTimer: Timer {
        id: exitDelayTimer

        interval: root.exitDelay
        onTriggered: if (!root.hovered) root.active = false
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import "../Theme"

Item {
    id: root

    property alias model: repeater.model
    property alias delegate: repeater.delegate

    property int current: 0
    readonly property int count: repeater.count

    property real tileWidth: Tokens.px(160)
    property real tileHeight: Tokens.px(100)
    property real centreScale: 1.25
    property real gap: Tokens.space.md
    property real reach: 3

    signal activated(int index)

    property real position: root.current
    property real wheelAccum: 0

    readonly property real firstStep: root.tileWidth * root.centreScale / 2 + root.gap + root.tileWidth / 2
    readonly property real stride: root.tileWidth + root.gap

    implicitHeight: Math.ceil(root.tileHeight * root.centreScale)
    clip: true
    activeFocusOnTab: true

    Behavior on position {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        NumberAnimation { duration: Tokens.motion.morph; easing.type: Tokens.motion.easeOut }
    }

    function offsetOf(distance: real): real {
        const away = Math.abs(distance)
        const offset = away <= 1
            ? away * root.firstStep
            : root.firstStep + (away - 1) * root.stride
        return distance < 0 ? -offset : offset
    }

    function scaleOf(distance: real): real {
        return 1 + (root.centreScale - 1) * Math.max(0, 1 - Math.abs(distance))
    }

    function goTo(index: int): void {
        if (root.count === 0)
            return
        root.current = Math.max(0, Math.min(root.count - 1, index))
    }

    function step(delta: int): void {
        root.goTo(root.current + delta)
    }

    function press(index: int): void {
        if (index === root.current)
            root.activated(index)
        else
            root.goTo(index)
    }

    function handleWheel(delta: real): void {
        root.wheelAccum += delta
        while (Math.abs(root.wheelAccum) >= 120) {
            root.step(root.wheelAccum < 0 ? 1 : -1)
            root.wheelAccum -= 120 * Math.sign(root.wheelAccum)
        }
    }

    Repeater { id: repeater }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.handleWheel(event.angleDelta.y)
    }

    WheelHandler {
        orientation: Qt.Horizontal
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.handleWheel(event.angleDelta.x)
    }

    DragHandler {
        property int fromIndex: 0

        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onActiveChanged: if (active) fromIndex = root.current
        onTranslationChanged: {
            if (active)
                root.goTo(fromIndex - Math.round(translation.x / root.stride))
        }
    }

    Keys.onLeftPressed: root.step(-1)
    Keys.onRightPressed: root.step(1)
    Keys.onReturnPressed: root.activated(root.current)
}

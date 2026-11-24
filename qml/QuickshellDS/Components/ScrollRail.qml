pragma ComponentBehavior: Bound

import QtQuick
import "../Theme"
import "../Primitives"

Item {
    id: root

    required property Flickable target
    property Item anchorWidget: root.target

    property string side: "right"          // "left" | "right"
    property real gap: Tokens.space.sm
    property real insetY: Tokens.radius.md
    property real trackWidth: Tokens.px(6)
    property real expandedWidth: Tokens.px(10)
    property real hitWidth: Tokens.px(20)
    property real minThumbHeight: Tokens.px(28)

    property string variant: "capsule"     // "hairline" | "capsule" | "gauge"
    property string revealPolicy: "auto"   // "always" | "auto" | "hover"
    property int idleTimeout: Tokens.motion.railHideDelay
    property bool showIndicator: false
    property string indicatorText: ""
    property bool pageOnTrackClick: true
    property bool overscrollStretch: true

    readonly property bool needed: root.target !== null && root.target.contentHeight > root.target.height + 1
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool dragging: dragHandler.active
    readonly property bool revealed: {
        if (!root.needed)
            return false
        if (root.revealPolicy === "always")
            return true
        if (root.revealPolicy === "hover")
            return root.hovered || root.dragging
        return root.hovered || root.dragging || root.recentlyScrolled
    }

    readonly property real maxScroll: root.target
        ? Math.max(0, root.target.contentHeight - root.target.height)
        : 0
    readonly property real progress: root.maxScroll > 0 && root.target
        ? Math.max(0, Math.min(1, root.target.contentY / root.maxScroll))
        : 0

    readonly property rect inputRect: root.needed && root.visible && root.opacity > 0
        ? Qt.rect(root.x, root.y, root.width, root.height)
        : Qt.rect(0, 0, 0, 0)

    signal dragStarted()
    signal dragEnded()
    signal jumpedTo(real ratio)

    property bool recentlyScrolled: false

    Accessible.role: Accessible.ScrollBar
    Accessible.name: qsTr("Scroll rail")

    readonly property real visualWidth: {
        if (root.variant === "hairline")
            return (root.hovered || root.dragging) ? Tokens.px(7) : Tokens.px(3)
        return (root.hovered || root.dragging) ? root.expandedWidth : root.trackWidth + Tokens.px(4)
    }

    width: Math.max(root.hitWidth, root.visualWidth)
    height: root.anchorWidget ? Math.max(0, root.anchorWidget.height - 2 * root.insetY) : 0
    y: root.anchorWidget ? root.anchorWidget.y + root.insetY : 0
    x: {
        if (!root.anchorWidget)
            return 0
        const padOffset = (root.width - root.visualWidth) / 2
        if (root.side === "left")
            return root.anchorWidget.x - root.gap - root.visualWidth - padOffset
        return root.anchorWidget.x + root.anchorWidget.width + root.gap - padOffset
    }

    visible: root.needed && opacity > 0
    opacity: {
        if (!root.needed)
            return 0
        if (root.variant === "gauge" && root.revealPolicy === "auto" && !root.revealed)
            return 0.35
        return root.revealed ? 1.0 : 0.0
    }

    Behavior on opacity {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        NumberAnimation { duration: Tokens.motion.normal; easing.type: Tokens.motion.easeOut }
    }

    Timer {
        id: hideTimer

        interval: root.idleTimeout
        repeat: false
        onTriggered: root.recentlyScrolled = false
    }

    Connections {
        target: root.target
        enabled: root.target !== null && root.revealPolicy === "auto"

        function onContentYChanged(): void {
            if (!root.needed)
                return
            root.recentlyScrolled = true
            hideTimer.restart()
        }
    }

    readonly property real trackHeight: Math.max(1, root.height)
    readonly property real rawRatio: root.target
        ? Math.max(0.02, Math.min(1, root.target.visibleArea.heightRatio))
        : 1
    readonly property real overscrollAmount: {
        if (!root.overscrollStretch || Tokens.reducedMotion || !root.target)
            return 0
        if (root.target.contentY < 0)
            return Math.min(0.25, -root.target.contentY / Math.max(1, root.height))
        if (root.target.contentY > root.maxScroll)
            return Math.min(0.25, (root.target.contentY - root.maxScroll) / Math.max(1, root.height))
        return 0
    }
    readonly property real thumbHeight: Math.max(
        Math.min(root.trackHeight, root.minThumbHeight),
        root.trackHeight * root.rawRatio * (1 - root.overscrollAmount)
    )
    readonly property real travelRange: Math.max(1, root.trackHeight - root.thumbHeight)
    readonly property real thumbY: {
        if (!root.target)
            return 0
        const denom = Math.max(0.0001, 1 - root.rawRatio)
        const ratio = Math.max(0, Math.min(1, root.target.visibleArea.yPosition / denom))
        return ratio * root.travelRange
    }

    function scrollToThumbY(localY: real): void {
        if (!root.target || root.maxScroll <= 0)
            return
        const clampedY = Math.max(0, Math.min(root.travelRange, localY))
        const ratio = clampedY / root.travelRange
        root.target.contentY = ratio * root.maxScroll
        root.jumpedTo(ratio)
    }

    Item {
        id: railBody

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.visualWidth

        transform: Translate {
            x: root.revealed ? 0 : (root.side === "left" ? Tokens.px(4) : -Tokens.px(4))

            Behavior on x {
                enabled: !Tokens.reducedMotion && !Tokens.gameMode
                NumberAnimation { duration: Tokens.motion.normal; easing.type: Tokens.motion.easeOut }
            }
        }

        Behavior on width {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
        }

        // Capsule & Gauge background track
        Surface {
            anchors.fill: parent
            visible: root.variant !== "hairline"
            role: "ground"
            sheen: root.variant === "capsule"
            radius: Tokens.radius.pill
            opacity: root.variant === "gauge" ? 0.85 : 1.0
        }

        // Hairline guide on hover/drag
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Tokens.hairlineWidth
            visible: root.variant === "hairline" && (root.hovered || root.dragging)
            color: Tokens.color.hairline
        }

        // Gauge ticks (start / mid / end)
        Repeater {
            model: root.variant === "gauge" ? [0.05, 0.5, 0.95] : []

            Rectangle {
                required property real modelData

                anchors.horizontalCenter: parent.horizontalCenter
                y: root.trackHeight * modelData
                width: Math.max(Tokens.px(2), railBody.width - Tokens.px(4))
                height: Tokens.hairlineWidth
                color: Tokens.color.borderStrong
            }
        }

        // Thumb
        Rectangle {
            id: thumb

            readonly property real inset: root.variant === "hairline" ? 0 : Tokens.px(2)

            anchors.horizontalCenter: parent.horizontalCenter
            y: root.thumbY + thumb.inset
            width: Math.max(Tokens.px(2), railBody.width - thumb.inset * 2)
            height: Math.max(Tokens.px(8), root.thumbHeight - thumb.inset * 2)
            radius: Tokens.radius.pill
            color: {
                if (root.dragging || root.hovered)
                    return Tokens.color.accent
                if (root.variant === "hairline")
                    return Qt.rgba(Tokens.color.text.r, Tokens.color.text.g, Tokens.color.text.b, 0.35)
                return Tokens.color.textMuted
            }

            Behavior on color {
                enabled: !Tokens.reducedMotion && !Tokens.gameMode
                ColorAnimation { duration: Tokens.motion.fast }
            }
        }
    }

    // Floating position badge (for gauge or showIndicator)
    Surface {
        visible: (root.showIndicator || root.variant === "gauge") && root.dragging
        role: "ground"
        sheen: false
        radius: Tokens.radius.pill
        width: indicatorLabel.implicitWidth + Tokens.space.md * 2
        height: indicatorLabel.implicitHeight + Tokens.space.xs * 2
        x: root.side === "left"
            ? railBody.x + railBody.width + Tokens.space.sm
            : railBody.x - width - Tokens.space.sm
        y: Math.max(0, Math.min(root.height - height, root.thumbY + root.thumbHeight / 2 - height / 2))

        TextLabel {
            id: indicatorLabel

            anchors.centerIn: parent
            role: "caption"
            tone: "primary"
            tabular: true
            text: root.indicatorText !== ""
                ? root.indicatorText
                : `${Math.round(root.progress * 100)}%`
        }
    }

    HoverHandler {
        id: hoverHandler

        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.needed
        onTapped: eventPoint => {
            if (!root.target)
                return
            const py = eventPoint.position.y
            if (py >= root.thumbY && py <= root.thumbY + root.thumbHeight)
                return
            if (root.pageOnTrackClick) {
                const direction = py < root.thumbY ? -1 : 1
                const nextY = root.target.contentY + direction * root.target.height * 0.85
                root.target.contentY = Math.max(0, Math.min(root.maxScroll, nextY))
                root.jumpedTo(root.maxScroll > 0 ? root.target.contentY / root.maxScroll : 0)
            } else {
                root.scrollToThumbY(py - root.thumbHeight / 2)
            }
        }
    }

    DragHandler {
        id: dragHandler

        property real startContentY: 0

        enabled: root.needed
        target: null
        xAxis.enabled: false
        yAxis.enabled: true

        onActiveChanged: {
            if (dragHandler.active) {
                startContentY = root.target ? root.target.contentY : 0
                root.dragStarted()
            } else {
                root.dragEnded()
            }
        }

        onTranslationChanged: {
            if (!dragHandler.active || !root.target || root.maxScroll <= 0)
                return
            const ratioDelta = translation.y / root.travelRange
            const nextY = startContentY + ratioDelta * root.maxScroll
            root.target.contentY = Math.max(0, Math.min(root.maxScroll, nextY))
        }
    }

    WheelHandler {
        enabled: root.needed
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (!root.target || root.maxScroll <= 0)
                return
            const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y * 0.5
            root.target.contentY = Math.max(0, Math.min(root.maxScroll, root.target.contentY - delta))
        }
    }
}

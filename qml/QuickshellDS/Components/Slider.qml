pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

Item {
    id: root

    property string style: "thin" // "thin" | "pill"
    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property int decimals: 0
    property string unit: "%"
    property string icon: ""
    property bool dimmed: false
    property bool expandable: false
    property bool showReadout: true
    property string accessibleLabel: qsTr("Slider")

    signal moved(real value)
    signal iconClicked()
    signal expandClicked()

    readonly property real span: Math.max(0.0001, root.to - root.from)
    readonly property real position: Math.max(0, Math.min(1, (root.value - root.from) / root.span))

    implicitWidth: Tokens.px(240)
    implicitHeight: root.style === "pill" ? Tokens.px(40) : Tokens.px(24)
    opacity: root.enabled ? 1.0 : 0.45
    activeFocusOnTab: root.enabled

    Accessible.role: Accessible.Slider
    Accessible.name: root.accessibleLabel

    function commitRatio(ratio: real): void {
        const clamped = Math.max(0, Math.min(1, ratio))
        let next = root.from + clamped * root.span
        if (root.stepSize > 0)
            next = root.from + Math.round((next - root.from) / root.stepSize) * root.stepSize
        next = Math.max(root.from, Math.min(root.to, next))
        root.moved(next)
    }

    function nudge(delta: int): void {
        const step = root.stepSize > 0 ? root.stepSize : root.span / 20
        const next = Math.max(root.from, Math.min(root.to, root.value + delta * step))
        root.moved(next)
    }

    FocusRing {
        active: root.activeFocus
        ringRadius: root.style === "pill" ? Tokens.radius.pill : Tokens.radius.xs
    }

    // ── PILL STYLE (CONTROL CENTRE) ─────────────────────────────────────────

    Rectangle {
        id: pillRoot

        anchors.fill: parent
        visible: root.style === "pill"
        radius: Tokens.radius.pill
        clip: true
        color: Tokens.isTranslucent(Tokens.surfaceStyle)
            ? Tokens.veilOf(Tokens.surfaceStyle)
            : Tokens.color.surfaceRaised
        border.width: Tokens.hairlineWidth
        border.color: pillHover.hovered ? Tokens.color.borderStrong : Tokens.veilBorderOf(Tokens.surfaceStyle)

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.position <= 0.001 ? 0 : Math.max(parent.height, parent.width * root.position)
            radius: parent.radius
            color: root.dimmed ? Tokens.color.surfaceActive : Tokens.color.accent
            opacity: root.dimmed ? 0.9 : 0.92

            Behavior on width {
                enabled: !Tokens.reducedMotion && !Tokens.gameMode && !pillDrag.active
                NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.space.md
            anchors.rightMargin: Tokens.space.md
            spacing: Tokens.space.sm

            Icon {
                visible: root.icon !== ""
                size: Tokens.size.iconMd
                tone: root.dimmed ? "muted" : "onAccent"
                icon: root.icon

                TapHandler {
                    enabled: root.enabled
                    onTapped: root.iconClicked()
                }
            }

            Item { Layout.fillWidth: true }

            TextLabel {
                visible: root.showReadout
                role: "sm"
                tabular: true
                tone: root.dimmed ? "muted" : "primary"
                font.weight: Font.Medium
                text: `${root.value.toFixed(root.decimals)}${root.unit}`
            }

            Icon {
                visible: root.expandable
                size: Tokens.size.iconSm
                tone: expandHover.hovered ? "primary" : "muted"
                name: "chevron-right"

                HoverHandler { id: expandHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    enabled: root.enabled && root.expandable
                    onTapped: root.expandClicked()
                }
            }
        }

        Item {
            id: pillTrackArea

            anchors.fill: parent
            anchors.rightMargin: root.expandable ? Tokens.px(32) : 0

            HoverHandler {
                id: pillHover

                enabled: root.enabled
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                enabled: root.enabled
                onTapped: eventPoint => root.commitRatio(eventPoint.position.x / Math.max(1, pillTrackArea.width))
            }

            DragHandler {
                id: pillDrag

                enabled: root.enabled
                target: null
                xAxis.enabled: true
                yAxis.enabled: false
                onCentroidChanged: {
                    if (pillDrag.active)
                        root.commitRatio(pillDrag.centroid.position.x / Math.max(1, pillTrackArea.width))
                }
            }
        }
    }

    // ── THIN STYLE (SETTINGS) ───────────────────────────────────────────────

    RowLayout {
        anchors.fill: parent
        visible: root.style === "thin"
        spacing: Tokens.space.md

        Item {
            id: thinTrackArea

            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: thinTrack

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Tokens.px(4)
                radius: Tokens.radius.pill
                color: Tokens.veilHoverOf(Tokens.surfaceStyle)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * root.position
                    radius: parent.radius
                    color: Tokens.color.accent
                }
            }

            Rectangle {
                readonly property real knobSize: (thinHover.hovered || thinDrag.active)
                    ? Tokens.px(16) : Tokens.px(13)

                x: thinTrack.width * root.position - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: knobSize
                height: knobSize
                radius: Tokens.radius.pill
                color: Tokens.color.onAccent
                border.width: Tokens.px(3)
                border.color: Tokens.color.accent

                Behavior on width {
                    enabled: !Tokens.reducedMotion && !Tokens.gameMode
                    NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
                }
            }

            HoverHandler {
                id: thinHover

                enabled: root.enabled
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                enabled: root.enabled
                onTapped: eventPoint => root.commitRatio(eventPoint.position.x / Math.max(1, thinTrackArea.width))
            }

            DragHandler {
                id: thinDrag

                enabled: root.enabled
                target: null
                xAxis.enabled: true
                yAxis.enabled: false
                onCentroidChanged: {
                    if (thinDrag.active)
                        root.commitRatio(thinDrag.centroid.position.x / Math.max(1, thinTrackArea.width))
                }
            }
        }

        Item {
            id: readingSlot

            property bool editing: false

            visible: root.showReadout
            Layout.preferredWidth: readingSlot.editing ? Tokens.px(64) : Tokens.px(48)
            Layout.preferredHeight: Tokens.px(22)
            Layout.alignment: Qt.AlignVCenter

            function commitText(entered: string): void {
                const parsed = parseFloat(entered.replace(",", "."))
                if (isNaN(parsed))
                    return
                let wanted = Math.max(root.from, Math.min(root.to, parsed))
                if (root.stepSize > 0)
                    wanted = root.from + Math.round((wanted - root.from) / root.stepSize) * root.stepSize
                root.moved(Math.max(root.from, Math.min(root.to, wanted)))
            }

            TextLabel {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !readingSlot.editing
                role: "mono"
                tabular: true
                tone: readingHover.hovered ? "primary" : "muted"
                text: `${root.value.toFixed(root.decimals)}${root.unit}`
            }

            HoverHandler {
                id: readingHover

                enabled: root.enabled && !readingSlot.editing
                cursorShape: Qt.IBeamCursor
            }

            TapHandler {
                enabled: root.enabled && !readingSlot.editing
                onTapped: {
                    readingSlot.editing = true
                    inlineEditor.text = root.value.toFixed(root.decimals)
                    inlineEditor.forceActiveFocus()
                    inlineEditor.selectAll()
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: readingSlot.editing
                radius: Tokens.radius.xs
                color: Tokens.color.bg
                border.width: Tokens.hairlineWidth
                border.color: Tokens.color.accent

                TextInput {
                    id: inlineEditor

                    anchors.fill: parent
                    anchors.leftMargin: Tokens.space.xs
                    anchors.rightMargin: Tokens.space.xs
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Tokens.type.monoFamily
                    font.pixelSize: Tokens.type.sm
                    color: Tokens.color.text
                    selectionColor: Tokens.color.accent
                    selectedTextColor: Tokens.color.onAccent
                    clip: true
                    validator: RegularExpressionValidator {
                        regularExpression: /-?[0-9]*[.,]?[0-9]*/
                    }
                    Keys.onEscapePressed: readingSlot.editing = false
                    Keys.onUpPressed: root.nudge(1)
                    Keys.onDownPressed: root.nudge(-1)
                    onEditingFinished: {
                        if (!readingSlot.editing)
                            return
                        readingSlot.editing = false
                        readingSlot.commitText(inlineEditor.text)
                    }
                }
            }
        }
    }

    WheelHandler {
        enabled: root.enabled
        acceptedDevices: PointerDevice.Mouse
        onWheel: event => root.nudge(event.angleDelta.y > 0 ? 1 : -1)
    }

    Keys.onLeftPressed: if (root.enabled) root.nudge(-1)
    Keys.onRightPressed: if (root.enabled) root.nudge(1)
    Keys.onPressed: event => {
        if (!root.enabled)
            return
        if (event.key === Qt.Key_Home) {
            root.moved(root.from)
            event.accepted = true
        } else if (event.key === Qt.Key_End) {
            root.moved(root.to)
            event.accepted = true
        }
    }
}

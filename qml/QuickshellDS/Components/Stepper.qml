pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

Rectangle {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property int decimals: 0
    property string unit: ""
    property bool wrap: false
    property string accessibleLabel: qsTr("Stepper")

    signal changed(real value)

    implicitWidth: layout.implicitWidth + Tokens.space.md * 2
    implicitHeight: Tokens.size.controlSm
    radius: Tokens.radius.sm
    opacity: root.enabled ? 1.0 : 0.45
    activeFocusOnTab: root.enabled

    color: Tokens.veilOf(Tokens.surfaceStyle)
    border.width: Tokens.hairlineWidth
    border.color: root.activeFocus ? Tokens.color.accent : Tokens.veilBorderOf(Tokens.surfaceStyle)

    Accessible.role: Accessible.SpinBox
    Accessible.name: root.accessibleLabel

    function step(delta: int): void {
        const span = root.to - root.from
        let next = root.value + delta * root.stepSize
        if (root.wrap && span > 0) {
            if (next > root.to)
                next = root.from
            else if (next < root.from)
                next = root.to
        } else {
            next = Math.max(root.from, Math.min(root.to, next))
        }
        root.changed(next)
    }

    FocusRing {
        active: root.activeFocus
        ringRadius: root.radius
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.space.sm

        TextLabel {
            role: "mono"
            tabular: true
            tone: "primary"
            text: `${root.value.toFixed(root.decimals)}${root.unit !== "" ? " " + root.unit : ""}`
        }

        Column {
            spacing: 0

            Repeater {
                model: [
                    { glyph: "󰅃", delta: 1 },
                    { glyph: "󰅀", delta: -1 }
                ]

                Item {
                    id: arrowBtn

                    required property var modelData

                    width: Tokens.px(16)
                    height: Tokens.px(12)

                    TextLabel {
                        anchors.centerIn: parent
                        role: "caption"
                        tone: arrowHover.hovered ? "accent" : "muted"
                        text: arrowBtn.modelData.glyph
                    }

                    HoverHandler {
                        id: arrowHover

                        enabled: root.enabled
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: root.enabled
                        onTapped: {
                            Tokens.keyboardNavigation = false
                            root.step(arrowBtn.modelData.delta)
                        }
                    }
                }
            }
        }
    }

    WheelHandler {
        enabled: root.enabled
        acceptedDevices: PointerDevice.Mouse
        onWheel: event => root.step(event.angleDelta.y > 0 ? 1 : -1)
    }

    Keys.onUpPressed: if (root.enabled) root.step(1)
    Keys.onDownPressed: if (root.enabled) root.step(-1)
}

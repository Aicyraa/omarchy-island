pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

Item {
    id: root

    property var values: []
    property real maxValue: 100
    property var labels: []
    property bool autoThreshold: false
    property color barColor: Tokens.color.accent
    property real barRadius: Tokens.radius.xs

    implicitWidth: Tokens.px(180)
    implicitHeight: Tokens.px(64)

    readonly property bool hasLabels: root.labels && root.labels.length > 0

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.space.xs

        Repeater {
            model: root.values ? root.values.length : 0

            ColumnLayout {
                id: col

                required property int index
                readonly property real rawVal: Number(root.values[col.index])
                readonly property real ratio: Math.max(0, Math.min(1, col.rawVal / Math.max(0.0001, root.maxValue)))
                readonly property color fillTint: {
                    if (!root.autoThreshold)
                        return root.barColor
                    if (col.ratio >= 0.90)
                        return Tokens.color.danger
                    if (col.ratio >= 0.75)
                        return Tokens.color.warning
                    return root.barColor
                }

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.space.xxs

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: root.barRadius
                    color: Tokens.veilOf(Tokens.surfaceStyle)
                    border.width: Tokens.hairlineWidth
                    border.color: Tokens.veilBorderOf(Tokens.surfaceStyle)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: col.ratio <= 0 ? 0 : Math.max(Tokens.px(4), parent.height * col.ratio)
                        radius: root.barRadius
                        color: col.fillTint

                        Behavior on height {
                            enabled: !Tokens.reducedMotion && !Tokens.gameMode
                            NumberAnimation { duration: Tokens.motion.normal; easing.type: Tokens.motion.easeOut }
                        }
                    }
                }

                TextLabel {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.hasLabels && col.index < root.labels.length
                    role: "caption"
                    tone: "muted"
                    text: root.hasLabels && col.index < root.labels.length ? String(root.labels[col.index]) : ""
                }
            }
        }
    }
}

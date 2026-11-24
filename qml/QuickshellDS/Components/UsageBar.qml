pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Theme"

Rectangle {
    id: root

    property real progress: 0
    property bool segmented: false
    property int segments: 12
    property real segmentGap: Tokens.space.xxs
    property bool autoThreshold: false
    property color fillColor: Tokens.color.accent
    property color trackColor: Tokens.veilHoverOf(Tokens.surfaceStyle)

    readonly property real clamped: Math.max(0, Math.min(1, root.progress))
    readonly property color effectiveFill: {
        if (!root.autoThreshold)
            return root.fillColor
        if (root.clamped >= 0.90)
            return Tokens.color.danger
        if (root.clamped >= 0.75)
            return Tokens.color.warning
        return root.fillColor
    }

    implicitWidth: Tokens.px(160)
    implicitHeight: root.segmented ? Tokens.px(8) : Tokens.px(6)
    radius: Tokens.radius.pill
    color: root.segmented ? "transparent" : root.trackColor
    border.width: root.segmented ? 0 : Tokens.hairlineWidth
    border.color: root.segmented ? "transparent" : Tokens.veilBorderOf(Tokens.surfaceStyle)

    Rectangle {
        visible: !root.segmented
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.clamped <= 0 ? 0 : Math.max(parent.height, parent.width * root.clamped)
        radius: Tokens.radius.pill
        color: root.effectiveFill

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.max(1, parent.height * 0.35)
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, 0.22)
        }

        Behavior on width {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            NumberAnimation { duration: Tokens.motion.normal; easing.type: Tokens.motion.easeOut }
        }
        Behavior on color {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            ColorAnimation { duration: Tokens.motion.normal }
        }
    }

    RowLayout {
        anchors.fill: parent
        visible: root.segmented
        spacing: root.segmentGap

        Repeater {
            model: root.segments

            Rectangle {
                required property int index

                readonly property bool lit: (index + 1) / Math.max(1, root.segments) <= root.clamped + 0.001

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Tokens.radius.xs
                color: lit ? root.effectiveFill : root.trackColor
                border.width: Tokens.hairlineWidth
                border.color: lit ? Qt.lighter(root.effectiveFill, 1.15) : Tokens.veilBorderOf(Tokens.surfaceStyle)

                Behavior on color {
                    enabled: !Tokens.reducedMotion && !Tokens.gameMode
                    ColorAnimation { duration: Tokens.motion.fast }
                }
            }
        }
    }
}

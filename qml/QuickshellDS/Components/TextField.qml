pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

Rectangle {
    id: root

    property alias text: input.text
    property string placeholderText: ""
    property string icon: "search"
    property string prefixBadge: ""
    property string errorText: ""
    property bool clearable: true
    property string accessibleLabel: qsTr("Text input")

    signal accepted()
    signal cleared()

    readonly property bool hasError: root.errorText !== ""

    implicitWidth: Tokens.px(260)
    implicitHeight: Tokens.size.controlMd
    radius: Tokens.radius.sm
    opacity: root.enabled ? 1.0 : 0.45

    color: input.activeFocus ? Tokens.veilHoverOf(Tokens.surfaceStyle) : Tokens.veilOf(Tokens.surfaceStyle)
    border.width: Tokens.hairlineWidth
    border.color: {
        if (root.hasError)
            return Tokens.color.danger
        if (input.activeFocus)
            return Tokens.color.accent
        return Tokens.veilBorderOf(Tokens.surfaceStyle)
    }

    Behavior on color {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        ColorAnimation { duration: Tokens.motion.fast }
    }

    Accessible.role: Accessible.EditableText
    Accessible.name: root.accessibleLabel

    function focusInput(): void {
        input.forceActiveFocus()
    }

    FocusRing {
        active: input.activeFocus && !root.hasError
        keyboardOnly: false
        ringRadius: root.radius
        outset: 0
        ringWidth: Tokens.px(1.5)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.space.md
        anchors.rightMargin: Tokens.space.sm
        spacing: Tokens.space.sm

        Icon {
            visible: root.icon !== ""
            size: Tokens.size.iconMd
            tone: input.activeFocus ? "accent" : "muted"
            icon: root.icon
        }

        Rectangle {
            visible: root.prefixBadge !== ""
            Layout.preferredWidth: badgeLabel.implicitWidth + Tokens.space.sm
            Layout.preferredHeight: Tokens.px(20)
            radius: Tokens.radius.xs
            color: Tokens.color.accentMuted

            TextLabel {
                id: badgeLabel

                anchors.centerIn: parent
                role: "mono"
                tone: "accent"
                text: root.prefixBadge
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextLabel {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                visible: input.text.length === 0 && root.placeholderText !== ""
                role: "body"
                tone: "muted"
                text: root.placeholderText
            }

            TextInput {
                id: input

                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                enabled: root.enabled
                font.family: Tokens.type.uiFamily
                font.pixelSize: Tokens.type.body
                color: Tokens.color.text
                selectionColor: Tokens.color.accent
                selectedTextColor: Tokens.color.onAccent
                clip: true
                onAccepted: root.accepted()
            }
        }

        Icon {
            visible: root.clearable && input.text.length > 0 && root.enabled
            size: Tokens.size.iconSm
            tone: clearHover.hovered ? "primary" : "muted"
            name: "close"

            HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    input.text = ""
                    root.cleared()
                }
            }
        }
    }
}

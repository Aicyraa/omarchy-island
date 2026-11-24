pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"
import "../Components"

Card {
    id: root

    property string appName: ""
    property string title: ""
    property string body: ""
    property string timestamp: ""
    property string iconName: "bell"
    property string badgeIcon: ""
    property string urgency: "normal" // "low" | "normal" | "critical"
    property real progress: -1        // 0..1 expiry bar, < 0 hidden
    property var actions: []          // [{ id, label }]

    signal actionTriggered(string id)
    signal dismissed()

    implicitWidth: Tokens.size.panelSm
    implicitHeight: layout.implicitHeight + root.verticalPadding * 2
    border.color: root.urgency === "critical"
        ? Tokens.color.danger
        : Tokens.veilBorderOf(Tokens.surfaceStyle)

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.space.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.space.md

            Item {
                Layout.preferredWidth: Tokens.px(34)
                Layout.preferredHeight: Tokens.px(34)
                Layout.alignment: Qt.AlignTop

                Icon {
                    anchors.centerIn: parent
                    name: root.iconName
                    size: Tokens.size.iconMd
                    tone: root.urgency === "critical" ? "danger" : "accent"
                    framed: true
                }

                NotificationBadge {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -Tokens.px(3)
                    anchors.bottomMargin: -Tokens.px(3)
                    visible: root.badgeIcon !== ""
                    iconName: root.badgeIcon
                    size: Tokens.px(16)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.xxs

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.xs

                    TextLabel {
                        visible: root.appName !== ""
                        role: "caption"
                        tone: "muted"
                        font.capitalization: Font.AllUppercase
                        text: root.appName
                    }

                    TextLabel {
                        visible: root.appName !== "" && root.timestamp !== ""
                        role: "caption"
                        tone: "muted"
                        text: "·"
                    }

                    TextLabel {
                        visible: root.timestamp !== ""
                        role: "caption"
                        tone: "muted"
                        tabular: true
                        text: root.timestamp
                    }

                    Item { Layout.fillWidth: true }
                }

                TextLabel {
                    Layout.fillWidth: true
                    role: "subtitle"
                    tone: "primary"
                    text: root.title
                }

                TextLabel {
                    Layout.fillWidth: true
                    visible: root.body !== ""
                    singleLine: false
                    maximumLineCount: 2
                    role: "sm"
                    tone: "muted"
                    text: root.body
                }
            }

            Button {
                Layout.alignment: Qt.AlignTop
                icon: "close"
                size: "sm"
                variant: "ghost"
                accessibleLabel: qsTr("Dismiss notification")
                onClicked: root.dismissed()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.actions && root.actions.length > 0
            spacing: Tokens.space.sm

            Item { Layout.fillWidth: true }

            Repeater {
                model: root.actions

                Button {
                    required property var modelData

                    text: modelData.label ?? ""
                    size: "sm"
                    variant: "secondary"
                    onClicked: root.actionTriggered(modelData.id ?? "")
                }
            }
        }

        UsageBar {
            Layout.fillWidth: true
            visible: root.progress >= 0
            progress: Math.max(0, root.progress)
            fillColor: root.urgency === "critical" ? Tokens.color.danger : Tokens.color.accent
        }
    }
}

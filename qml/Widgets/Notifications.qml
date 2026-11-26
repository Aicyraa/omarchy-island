pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Core"
import "../Core/Visuals"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    preferredWidth: 500
    scrollTarget: notifList
    hint: qsTr("↑/↓ select · Del remove · D focus · C clear all · Esc close")

    property int sel: 0
    readonly property int count: Notifs.history.length

    Component.onCompleted: Indicators.refresh()

    function removeAt(idx: int): void {
        const item = Notifs.history[idx]
        if (!item)
            return
        Notifs.removeItem(item.key)
        if (sel >= Notifs.history.length)
            sel = Math.max(0, Notifs.history.length - 1)
    }

    function clearEverything(): void {
        Notifs.clearAll()
        IslandState.clearNotifs()
        sel = 0
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down) {
            IslandState.touch(true)
            root.sel = Math.min(root.sel + 1, Math.max(0, Notifs.history.length - 1))
            root.reveal(notifList.currentItem)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            IslandState.touch(true)
            root.sel = Math.max(root.sel - 1, 0)
            root.reveal(notifList.currentItem)
            event.accepted = true
        } else if (event.key === Qt.Key_D) {
            IslandState.touch(true)
            Indicators.toggleDnd()
            event.accepted = true
        } else if (event.key === Qt.Key_C) {
            IslandState.touch(true)
            root.clearEverything()
            event.accepted = true
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            IslandState.touch(true)
            root.removeAt(root.sel)
            event.accepted = true
        }
    }

    // Header
    RowLayout {
        width: parent.width
        spacing: Tokens.space.sm

        DetailHeader {
            Layout.fillWidth: true
            backable: false
            title: qsTr("Notifications")
            detail: Notifs.summary
        }

        Badge {
            visible: root.count > 0
            text: String(root.count)
            tone: "neutral"
        }

        RowLayout {
            spacing: Tokens.space.xs

            TextLabel {
                role: "sm"
                tone: Indicators.dnd ? "accent" : "muted"
                text: qsTr("DND")
            }

            ToggleSwitch {
                checked: Indicators.dnd
                accessibleLabel: qsTr("Do Not Disturb")
                onToggled: Indicators.toggleDnd()
            }
        }

        Button {
            visible: root.count > 0
            text: qsTr("Clear All")
            icon: "trash-2"
            size: "sm"
            variant: "danger"
            accessibleLabel: qsTr("Clear all notifications")
            onClicked: root.clearEverything()
        }
    }

    // Notification list
    ListView {
        id: notifList

        visible: root.count > 0
        width: parent.width
        implicitHeight: Math.min(Tokens.px(360), contentHeight)
        clip: true
        spacing: Tokens.space.sm
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: root.sel
        model: Notifs.history

        delegate: Card {
            id: nCard

            required property var modelData
            required property int index

            readonly property bool selected: root.sel === index
            readonly property string preview: Notifs.previewOf(modelData)
            readonly property string iconName: Notifs.iconNameOf(modelData)

            width: notifList.width
            horizontalPadding: Tokens.space.lg
            verticalPadding: Tokens.space.md
            implicitHeight: cardRow.implicitHeight + verticalPadding * 2
            border.color: selected ? Tokens.color.accent : Tokens.veilBorderOf(Tokens.surfaceStyle)

            RowLayout {
                id: cardRow

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Tokens.space.md

                NotifThumb {
                    Layout.alignment: Qt.AlignTop
                    size: Tokens.px(40)
                    badge: true
                    preview: nCard.preview
                    iconName: nCard.iconName
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.xxs

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.xs

                        TextLabel {
                            role: "caption"
                            tone: "accent"
                            font.weight: Font.Medium
                            text: nCard.modelData.app || qsTr("Notification")
                        }

                        TextLabel {
                            role: "caption"
                            tone: "muted"
                            text: "·"
                        }

                        TextLabel {
                            role: "caption"
                            tone: "muted"
                            tabular: true
                            text: Notifs.ago(nCard.modelData.ts)
                        }

                        Item { Layout.fillWidth: true }
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        role: "subtitle"
                        font.weight: Font.Medium
                        text: nCard.modelData.summary || nCard.modelData.app || ""
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        visible: text !== ""
                        singleLine: false
                        maximumLineCount: 2
                        role: "sm"
                        tone: "muted"
                        text: nCard.modelData.body || ""
                    }
                }

                Button {
                    Layout.alignment: Qt.AlignTop
                    icon: "close"
                    size: "sm"
                    variant: "ghost"
                    accessibleLabel: qsTr("Dismiss notification")
                    onClicked: root.removeAt(nCard.index)
                }
            }

            TapHandler {
                onTapped: root.sel = nCard.index
            }
        }
    }

    // Empty state
    EmptyState {
        visible: root.count === 0
        width: parent.width
        icon: Indicators.dnd ? "bell-off" : "bell"
        title: qsTr("All caught up")
        description: Indicators.dnd
            ? qsTr("Focus is on — new notifications stay quiet")
            : qsTr("Nothing new right now")
    }
}

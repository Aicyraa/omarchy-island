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

    preferredWidth: 540
    scrollTarget: notifList
    hint: qsTr("↑/↓ select · Del remove · D DND · C clear all · Esc close")

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
            notifList.positionViewAtIndex(root.sel, ListView.Contain)
            root.reveal(notifList.currentItem)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            IslandState.touch(true)
            root.sel = Math.max(root.sel - 1, 0)
            notifList.positionViewAtIndex(root.sel, ListView.Contain)
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
            icon: Indicators.dnd ? "bell-off" : "bell"
            title: qsTr("Notifications")
            detail: root.count > 0 ? qsTr("%1 in history").arg(root.count) : ""
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
            variant: "ghost"
            accessibleLabel: qsTr("Clear all notifications")
            onClicked: root.clearEverything()
        }
    }

    // Notification list
    Surface {
        visible: root.count > 0
        width: parent.width
        role: "card"
        horizontalPadding: Tokens.space.sm
        verticalPadding: Tokens.space.sm
        radius: Tokens.radius.md
        implicitHeight: notifList.height + verticalPadding * 2

        ListView {
            id: notifList

            readonly property real rowHeight: Tokens.px(88)

            width: parent.width
            height: Math.min(3 * rowHeight, contentHeight)
            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.sel
            model: Notifs.history

            delegate: Item {
                id: nCard

                required property var modelData
                required property int index

                readonly property bool selected: root.sel === index
                readonly property string preview: Notifs.previewOf(modelData)
                readonly property string iconName: Notifs.iconNameOf(modelData)
                readonly property string appName: modelData.app || qsTr("Notification")
                readonly property string summaryText: (modelData.summary ?? "").trim()
                readonly property bool hasSummary: summaryText !== ""

                width: notifList.width
                height: notifList.rowHeight
                activeFocusOnTab: true
                Accessible.role: Accessible.ListItem
                Accessible.name: hasSummary ? (appName + ": " + summaryText) : appName

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radius.sm
                    color: nCard.selected
                        ? Tokens.veilHoverOf(Tokens.surfaceStyle)
                        : (rowHover.hovered ? Tokens.veilOf(Tokens.surfaceStyle) : "transparent")

                    Behavior on color {
                        enabled: !Tokens.reducedMotion && !Tokens.gameMode
                        ColorAnimation { duration: Tokens.motion.fast }
                    }
                }

                FocusRing {
                    active: nCard.activeFocus
                    ringRadius: Tokens.radius.sm
                }

                RowLayout {
                    id: cardRow

                    anchors.fill: parent
                    anchors.leftMargin: Tokens.space.lg
                    anchors.rightMargin: Tokens.space.lg
                    anchors.topMargin: Tokens.space.md
                    anchors.bottomMargin: Tokens.space.md
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
                                visible: nCard.hasSummary
                                role: "caption"
                                tone: "accent"
                                font.weight: Font.Medium
                                text: nCard.appName
                            }

                            TextLabel {
                                visible: nCard.hasSummary
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
                            text: nCard.hasSummary ? nCard.summaryText : nCard.appName
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

                Rectangle {
                    visible: nCard.index < notifList.count - 1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Tokens.space.lg
                    anchors.rightMargin: Tokens.space.lg
                    height: Tokens.hairlineWidth
                    color: Tokens.color.hairline
                }

                HoverHandler {
                    id: rowHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.sel = nCard.index
                }

                Keys.onReturnPressed: root.sel = nCard.index
                Keys.onSpacePressed: root.sel = nCard.index
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
            ? qsTr("Do Not Disturb is on — new notifications stay quiet")
            : qsTr("Nothing new right now")
    }
}

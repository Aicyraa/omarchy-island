pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import "../Core"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"

WidgetSurface {
    id: root

    preferredWidth: 320
    compact: true
    readonly property bool capturesEscape: root.menuIndex >= 0
    hint: qsTr("Arrows select · Enter activate · M actions · Esc close")

    property var hostWindow: null
    readonly property var entries: SystemTray.items.values
    property int sel: 0
    property int hoveredIndex: -1
    property int menuIndex: -1

    readonly property var menuEntry: (menuIndex >= 0 && menuIndex < entries.length) ? entries[menuIndex] : null
    readonly property var headerEntry: {
        if (hoveredIndex >= 0 && hoveredIndex < entries.length)
            return entries[hoveredIndex]
        if (menuEntry)
            return menuEntry
        if (sel >= 0 && sel < entries.length)
            return entries[sel]
        return null
    }
    readonly property string headerTitle: headerEntry
        ? (headerEntry.title || headerEntry.id || qsTr("System Tray"))
        : qsTr("System Tray")

    function openActions(idx: int): void {
        if (idx < 0 || idx >= entries.length)
            return
        sel = idx
        menuIndex = (menuIndex === idx) ? -1 : idx
    }

    function closeActions(): void {
        menuIndex = -1
        root.forceActiveFocus()
    }

    onEntriesChanged: {
        if (sel >= entries.length)
            sel = Math.max(0, entries.length - 1)
        if (menuIndex >= entries.length)
            menuIndex = -1
        if (hoveredIndex >= entries.length)
            hoveredIndex = -1
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && root.menuIndex >= 0) {
            IslandState.touch(true)
            root.closeActions()
            event.accepted = true
            return
        }
        const n = root.entries.length
        if (n === 0)
            return
        if (event.key === Qt.Key_Right) {
            IslandState.touch(true)
            root.sel = Math.min(root.sel + 1, n - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            IslandState.touch(true)
            root.sel = Math.max(root.sel - 1, 0)
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            IslandState.touch(true)
            root.sel = Math.min(root.sel + 5, n - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            IslandState.touch(true)
            root.sel = Math.max(root.sel - 5, 0)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            IslandState.touch(true)
            root.entries[root.sel].activate()
            event.accepted = true
        } else if (event.key === Qt.Key_M) {
            IslandState.touch(true)
            root.openActions(root.sel)
            event.accepted = true
        }
    }

    // Compact header label
    RowLayout {
        width: parent.width
        spacing: Tokens.space.sm

        TextLabel {
            Layout.fillWidth: true
            role: "sm"
            font.weight: Font.Medium
            tone: "secondary"
            text: root.headerTitle
        }

        TextLabel {
            visible: root.entries.length > 1
            role: "caption"
            tabular: true
            tone: "muted"
            text: String(root.entries.length)
        }
    }

    EmptyState {
        visible: root.entries.length === 0
        width: parent.width
        icon: "layers"
        title: qsTr("No tray icons")
    }

    Item {
        visible: root.entries.length > 0
        width: parent.width
        implicitHeight: trayGrid.implicitHeight

        Grid {
            id: trayGrid

            anchors.horizontalCenter: parent.horizontalCenter
            columns: Math.max(1, Math.min(5, root.entries.length))
            spacing: Tokens.space.sm

            Repeater {
                model: root.entries

                Surface {
                    id: trayTile

                    required property var modelData
                    required property int index

                    readonly property bool isSel: root.sel === index
                    readonly property bool isMenuOpen: root.menuIndex === index

                    width: Tokens.px(48)
                    height: Tokens.px(48)
                    role: (isSel || isMenuOpen) ? "elevated" : "card"
                    radius: Tokens.radius.sm
                    hovered: tileHover.hovered
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.title || modelData.id || qsTr("Tray item")
                    border.color: (isSel || isMenuOpen)
                        ? Tokens.color.accent
                        : Tokens.veilBorderOf(Tokens.surfaceStyle)

                    Image {
                        anchors.centerIn: parent
                        width: Tokens.px(22)
                        height: Tokens.px(22)
                        source: trayTile.modelData.icon
                        sourceSize: Qt.size(44, 44)
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                    }

                    FocusRing {
                        active: trayTile.activeFocus
                        ringRadius: Tokens.radius.sm
                    }

                    HoverHandler {
                        id: tileHover

                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered)
                                root.hoveredIndex = trayTile.index
                            else if (root.hoveredIndex === trayTile.index)
                                root.hoveredIndex = -1
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onTapped: (eventPoint, button) => {
                            Tokens.keyboardNavigation = false
                            root.sel = trayTile.index
                            if (button === Qt.RightButton)
                                root.openActions(trayTile.index)
                            else
                                trayTile.modelData.activate()
                        }
                    }

                    Keys.onSpacePressed: trayTile.modelData.activate()
                    Keys.onReturnPressed: trayTile.modelData.activate()
                }
            }
        }
    }

    // Inline action drawer (never clips outside 320 px)
    Surface {
        id: actionDrawer

        visible: root.menuEntry !== null
        width: parent.width
        implicitHeight: drawerCol.implicitHeight + Tokens.space.sm * 2
        role: "card"
        radius: Tokens.radius.sm
        horizontalPadding: Tokens.space.sm
        verticalPadding: Tokens.space.sm

        ColumnLayout {
            id: drawerCol

            width: parent.width
            spacing: Tokens.space.xxs

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.space.xs
                spacing: Tokens.space.xs

                TextLabel {
                    Layout.fillWidth: true
                    role: "caption"
                    tone: "muted"
                    text: root.menuEntry
                        ? (root.menuEntry.title || root.menuEntry.id || qsTr("Actions"))
                        : ""
                }

                Button {
                    icon: "close"
                    variant: "ghost"
                    size: "sm"
                    accessibleLabel: qsTr("Close actions")
                    onClicked: root.closeActions()
                }
            }

            ListRow {
                Layout.fillWidth: true
                icon: "external-link"
                title: qsTr("Activate")
                onClicked: {
                    if (root.menuEntry)
                        root.menuEntry.activate()
                    root.closeActions()
                }
            }

            ListRow {
                Layout.fillWidth: true
                icon: "sliders-horizontal"
                title: qsTr("Secondary Action")
                onClicked: {
                    if (root.menuEntry)
                        root.menuEntry.secondaryActivate()
                    root.closeActions()
                }
            }

            ListRow {
                visible: Boolean(root.menuEntry && root.menuEntry.hasMenu && root.hostWindow)
                Layout.fillWidth: true
                icon: "layers"
                title: qsTr("App Menu")
                onClicked: {
                    const entry = root.menuEntry
                    const win = root.hostWindow
                    root.closeActions()
                    if (entry && entry.hasMenu && win)
                        entry.display(win, Math.round(root.width / 2), Math.round(root.height))
                }
            }
        }
    }
}

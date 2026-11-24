pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import "../Core"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"

WidgetSurface {
    id: root

    preferredWidth: 260
    compact: true
    hint: qsTr("Arrows select · Enter activate · M menu · Esc close")

    property var hostWindow: null
    readonly property var entries: SystemTray.items.values
    property int sel: 0
    property int menuIndex: -1

    function openContextMenu(idx: int, itemRef: Item): void {
        if (idx < 0 || idx >= entries.length)
            return
        menuIndex = idx
        const entry = entries[idx]
        const rows = [
            { id: "activate", label: qsTr("Activate"), icon: "external-link", destructive: false },
            { id: "secondary", label: qsTr("Secondary Action"), icon: "sliders-horizontal", destructive: false }
        ]
        if (entry && entry.hasMenu && root.hostWindow)
            rows.push({ id: "native", label: qsTr("App Menu"), icon: "layers", destructive: false })
        trayMenu.rows = rows
        trayMenu.currentIndex = 0
        if (itemRef) {
            const p = itemRef.mapToItem(root, 0, itemRef.height + Tokens.space.xs)
            const clamped = trayMenu.clampToBounds(root.width, root.height, p.x, p.y)
            trayMenu.x = clamped.x
            trayMenu.y = clamped.y
        }
        trayMenu.visible = true
        trayMenu.forceActiveFocus()
    }

    Keys.onPressed: event => {
        if (trayMenu.visible)
            return
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
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            IslandState.touch(true)
            root.entries[root.sel].activate()
            event.accepted = true
        } else if (event.key === Qt.Key_M) {
            IslandState.touch(true)
            root.openContextMenu(root.sel, null)
            event.accepted = true
        }
    }

    EmptyState {
        visible: root.entries.length === 0
        width: parent.width
        icon: "layers"
        title: qsTr("No tray icons")
    }

    Flow {
        visible: root.entries.length > 0
        width: parent.width
        spacing: Tokens.space.sm

        Repeater {
            model: root.entries

            Surface {
                id: trayTile

                required property var modelData
                required property int index

                readonly property bool isSel: root.sel === index

                width: Tokens.px(44)
                height: Tokens.px(44)
                role: isSel ? "elevated" : "card"
                radius: Tokens.radius.sm
                hovered: tileHover.hovered
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: modelData.title || modelData.id || qsTr("Tray item")
                border.color: isSel ? Tokens.color.accent : Tokens.veilBorderOf(Tokens.surfaceStyle)

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
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onTapped: (eventPoint, button) => {
                        root.sel = trayTile.index
                        if (button === Qt.RightButton)
                            root.openContextMenu(trayTile.index, trayTile)
                        else
                            trayTile.modelData.activate()
                    }
                }
            }
        }
    }

    PopMenu {
        id: trayMenu

        visible: false
        z: 20
        onChosen: id => {
            trayMenu.visible = false
            const entry = root.entries[root.menuIndex]
            if (!entry)
                return
            if (id === "activate")
                entry.activate()
            else if (id === "secondary")
                entry.secondaryActivate()
            else if (id === "native" && entry.hasMenu && root.hostWindow)
                entry.display(root.hostWindow, Math.round(trayMenu.x), Math.round(trayMenu.y))
            root.forceActiveFocus()
        }
        onDismissed: {
            trayMenu.visible = false
            root.forceActiveFocus()
        }
    }
}

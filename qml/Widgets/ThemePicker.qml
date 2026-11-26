pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../Core"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    preferredWidth: 720
    scrollTarget: themeList
    readonly property bool wantsKeyboard: true
    readonly property Item initialFocus: searchInput
    readonly property bool capturesEscape: query !== ""
    hint: qsTr("Type to search · ←/→/↑/↓ move · Enter apply · Esc close")

    readonly property var all: Themes.list
    property string query: ""
    readonly property string current: Themes.current
    property bool moved: false
    property string applying: ""
    property int sel: 0
    readonly property bool loading: !Themes.loaded

    dataLoading: !Themes.loaded

    readonly property var themes: {
        const q = query.toLowerCase().replace(/\s+/g, "")
        if (q === "")
            return all
        return all.filter(t => {
            const n = String(t.name).toLowerCase()
            let i = 0
            for (let k = 0; k < n.length && i < q.length; k++) {
                if (n[k] === q[i])
                    i++
            }
            return i === q.length
        })
    }

    Component.onCompleted: {
        syncToCurrent()
        Themes.refreshCurrent()
        Themes.refresh()
        Qt.callLater(() => searchInput.focusInput())
    }

    onCurrentChanged: syncToCurrent()
    onThemesChanged: syncToCurrent()
    onQueryChanged: {
        moved = true
        sel = 0
    }

    function clearSearch(): void {
        searchInput.text = ""
        query = ""
    }

    function apply(t: var): void {
        if (!t)
            return
        Cmd.run(["omarchy-theme-set", t.name])
        Themes.setCurrent(t.name)
        applying = t.name
        applyTimer.restart()
    }

    function syncToCurrent(): void {
        if (moved)
            return
        for (let i = 0; i < themes.length; i++) {
            if (themes[i].name === current) {
                sel = i
                themeList.positionViewAtIndex(i, GridView.Contain)
                break
            }
        }
    }

    Timer { id: applyTimer; interval: 4000; onTriggered: root.applying = "" }

    Keys.onPressed: event => {
        const n = root.themes.length
        if (event.key === Qt.Key_Escape && root.query !== "") {
            IslandState.touch(true)
            root.clearSearch()
            event.accepted = true
            return
        }
        if (n === 0)
            return
        if (event.key === Qt.Key_Right) {
            IslandState.touch(true)
            root.moved = true
            root.sel = Math.min(root.sel + 1, n - 1)
            themeList.positionViewAtIndex(root.sel, GridView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            IslandState.touch(true)
            root.moved = true
            root.sel = Math.max(root.sel - 1, 0)
            themeList.positionViewAtIndex(root.sel, GridView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            IslandState.touch(true)
            root.moved = true
            root.sel = Math.min(root.sel + 3, n - 1)
            themeList.positionViewAtIndex(root.sel, GridView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            IslandState.touch(true)
            root.moved = true
            root.sel = Math.max(root.sel - 3, 0)
            themeList.positionViewAtIndex(root.sel, GridView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            IslandState.touch(true)
            if (root.themes[root.sel])
                root.apply(root.themes[root.sel])
            event.accepted = true
        }
    }

    // Header: search + current badge + counter
    RowLayout {
        width: parent.width
        spacing: Tokens.space.sm

        TextField {
            id: searchInput

            Layout.preferredWidth: Tokens.px(280)
            icon: "search"
            placeholderText: qsTr("Search themes…")
            accessibleLabel: qsTr("Search themes")
            onTextChanged: if (root.query !== text) root.query = text
            onAccepted: if (root.themes[root.sel]) root.apply(root.themes[root.sel])
            onCleared: root.clearSearch()
        }

        Item { Layout.fillWidth: true }

        Badge {
            visible: root.current !== "" && root.applying === ""
            text: root.current
            tone: "accent"
        }

        TextLabel {
            role: "sm"
            tabular: root.applying === ""
            tone: root.applying !== "" ? "accent" : "muted"
            text: root.applying !== ""
                ? qsTr("Applying %1…").arg(root.applying)
                : (root.themes.length > 0 ? (root.sel + 1) + " / " + root.themes.length : "0 / " + root.all.length)
        }
    }

    // Loading / empty
    RowLayout {
        visible: root.loading
        width: parent.width
        spacing: Tokens.space.sm

        LoadingSpinner { running: root.visible && root.loading }
        TextLabel { role: "body"; tone: "muted"; text: qsTr("Reading themes…") }
    }

    EmptyState {
        visible: !root.loading && root.all.length > 0 && root.themes.length === 0
        width: parent.width
        icon: "palette"
        title: qsTr("No matching themes")
        description: qsTr("No theme matches \"%1\"").arg(root.query)
    }

    // Theme Grid
    GridView {
        id: themeList

        visible: !root.loading && root.themes.length > 0
        width: parent.width
        implicitHeight: Math.min(Tokens.px(320), Math.ceil(root.themes.length / 3) * cellHeight)
        cellWidth: Math.floor(width / 3)
        cellHeight: Tokens.px(124)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.themes

        delegate: Item {
            id: slot

            required property var modelData
            required property int index

            readonly property bool selected: root.sel === index
            readonly property bool isCurrent: modelData.name === root.current
            readonly property bool hasImage: /\.(png|jpe?g|webp)$/i.test(modelData.preview ?? "")

            width: themeList.cellWidth
            height: themeList.cellHeight

            Card {
                anchors.fill: parent
                anchors.margins: Tokens.space.xs
                horizontalPadding: Tokens.space.md
                verticalPadding: Tokens.space.md
                hovered: cardHover.hovered
                border.color: slot.isCurrent
                    ? Tokens.color.accent
                    : (slot.selected ? Tokens.color.borderStrong : Tokens.veilBorderOf(Tokens.surfaceStyle))

                ClippingRectangle {
                    visible: slot.hasImage
                    anchors.fill: parent
                    anchors.margins: -Tokens.px(1)
                    radius: Tokens.radius.md
                    opacity: 0.28
                    color: "transparent"

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(320, 216)
                        source: slot.hasImage ? "file://" + slot.modelData.preview : ""
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Tokens.space.sm

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.xs

                        Icon {
                            icon: slot.modelData.mode === "light" ? "sun" : "moon"
                            size: Tokens.size.iconSm
                            tone: "muted"
                        }

                        Item { Layout.fillWidth: true }

                        Badge {
                            visible: slot.isCurrent
                            text: "✓"
                            tone: "accent"
                        }
                    }

                    Item { Layout.fillHeight: true }

                    TextLabel {
                        Layout.fillWidth: true
                        role: "body"
                        font.weight: Font.Medium
                        text: slot.modelData.name ?? ""
                    }

                    Row {
                        spacing: Tokens.space.xs

                        Repeater {
                            model: [
                                slot.modelData.bg ?? "",
                                slot.modelData.fg ?? "",
                                slot.modelData.accent ?? "",
                                slot.modelData.red ?? ""
                            ]

                            Rectangle {
                                required property string modelData

                                width: Tokens.px(10)
                                height: Tokens.px(10)
                                radius: Tokens.radius.pill
                                color: modelData !== "" ? modelData : Tokens.color.surfaceRaised
                                border.width: Tokens.hairlineWidth
                                border.color: Tokens.veilBorderOf(Tokens.surfaceStyle)
                            }
                        }
                    }
                }

                HoverHandler {
                    id: cardHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        root.moved = true
                        root.sel = slot.index
                        root.apply(slot.modelData)
                    }
                }
            }
        }
    }
}

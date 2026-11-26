pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Widgets
import "../Core"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    preferredWidth: 660
    scrollTarget: root.sec === 0 ? bgGrid : fontList
    hint: qsTr("Tab section · ←/→/↑/↓ navigate · Enter apply · Esc close")

    property int sec: 0
    property int bgIdx: 0
    property int fontIdx: 0
    property var bgs: []
    property string bgCurrent: ""
    property var fonts: []
    property string fontCurrent: ""

    readonly property real fontRowHeight: Tokens.px(44)
    readonly property real fontRowSpacing: Tokens.space.xs

    onSecChanged: {
        bgSectionFade.stop()
        bgGrid.opacity = 1.0
        fontList.opacity = 1.0
        bgSectionFade.restart()
    }

    Component.onCompleted: {
        scanBg.running = true
        scanFonts.running = true
        takeIntent()
    }

    function takeIntent(): void {
        const want = IslandState.intent
        if (want === "font") {
            sec = 1
            IslandState.intent = ""
        } else if (want === "background") {
            sec = 0
            IslandState.intent = ""
        }
    }

    Connections {
        target: IslandState
        function onIntentChanged() { root.takeIntent() }
    }

    function nextBg(): void {
        Cmd.run(["omarchy-theme-bg-next"])
        reread.restart()
    }

    function applyBg(i: int): void {
        const p = bgs[i]
        if (!p)
            return
        Cmd.run(["omarchy-theme-bg-set", p])
        bgCurrent = p
    }

    function applyFont(i: int): void {
        const f = fonts[i]
        if (!f)
            return
        Cmd.run(["omarchy-font-set", f])
        fontCurrent = f
    }

    Timer { id: reread; interval: 900; onTriggered: scanBg.running = true }

    Process {
        id: scanBg
        command: ["bash", "-c",
            'theme=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null); '
            + 'readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null | sed "s/^/CUR\\t/"; '
            + 'find -L "$HOME/.config/omarchy/backgrounds/$theme" "$HOME/.local/state/omarchy/current/theme/backgrounds" '
            + '-maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \\) -print0 2>/dev/null '
            + '| sort -z | xargs -0 -r readlink -f | sed "s/^/BG\\t/"']
        stdout: StdioCollector {
            onStreamFinished: {
                let cur = ""
                const list = []
                String(text || "").split("\n").forEach(l => {
                    if (l.indexOf("CUR\t") === 0)
                        cur = l.slice(4)
                    else if (l.indexOf("BG\t") === 0)
                        list.push(l.slice(3))
                })
                root.bgCurrent = cur
                root.bgs = list
                const at = list.indexOf(cur)
                if (at >= 0)
                    root.bgIdx = at
            }
        }
    }

    Process {
        id: scanFonts
        command: ["bash", "-c", 'echo "CUR\t$(omarchy-font-current 2>/dev/null)"; omarchy-font-list 2>/dev/null | sed "s/^/F\t/"']
        stdout: StdioCollector {
            onStreamFinished: {
                let cur = ""
                const list = []
                String(text || "").split("\n").forEach(l => {
                    if (l.indexOf("CUR\t") === 0)
                        cur = l.slice(4).trim()
                    else if (l.indexOf("F\t") === 0 && l.length > 2)
                        list.push(l.slice(2).trim())
                })
                root.fontCurrent = cur
                root.fonts = list
                const at = list.indexOf(cur)
                if (at >= 0)
                    root.fontIdx = at
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            IslandState.touch(true)
            root.sec = 1 - root.sec
            event.accepted = true
        } else if (root.sec === 0 && root.bgs.length > 0) {
            const n = root.bgs.length
            if (event.key === Qt.Key_Left) {
                IslandState.touch(true)
                root.bgIdx = Math.max(0, root.bgIdx - 1)
                bgGrid.positionViewAtIndex(root.bgIdx, GridView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                IslandState.touch(true)
                root.bgIdx = Math.min(n - 1, root.bgIdx + 1)
                bgGrid.positionViewAtIndex(root.bgIdx, GridView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                IslandState.touch(true)
                root.bgIdx = Math.max(0, root.bgIdx - 3)
                bgGrid.positionViewAtIndex(root.bgIdx, GridView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                IslandState.touch(true)
                root.bgIdx = Math.min(n - 1, root.bgIdx + 3)
                bgGrid.positionViewAtIndex(root.bgIdx, GridView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                IslandState.touch(true)
                root.applyBg(root.bgIdx)
                event.accepted = true
            }
        } else if (root.sec === 1 && root.fonts.length > 0) {
            if (event.key === Qt.Key_Up) {
                IslandState.touch(true)
                root.fontIdx = Math.max(0, root.fontIdx - 1)
                fontList.positionViewAtIndex(root.fontIdx, ListView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                IslandState.touch(true)
                root.fontIdx = Math.min(root.fonts.length - 1, root.fontIdx + 1)
                fontList.positionViewAtIndex(root.fontIdx, ListView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                IslandState.touch(true)
                root.applyFont(root.fontIdx)
                event.accepted = true
            }
        }
    }

    // Header + Next Wallpaper + TabStrip
    RowLayout {
        width: parent.width
        spacing: Tokens.space.md

        DetailHeader {
            Layout.fillWidth: true
            backable: false
            icon: "sparkles"
            title: qsTr("Appearance")
            detail: ""
        }

        Button {
            visible: root.sec === 0
            text: qsTr("Next Wallpaper")
            icon: "skip-forward"
            variant: "secondary"
            size: "sm"
            accessibleLabel: qsTr("Cycle to next wallpaper")
            onClicked: root.nextBg()
        }

        TabStrip {
            tabs: [
                { id: "backgrounds", label: qsTr("Backgrounds") },
                { id: "fonts", label: qsTr("Fonts") }
            ]
            current: root.sec === 0 ? "backgrounds" : "fonts"
            accessibleLabel: qsTr("Appearance sections")
            onPicked: id => {
                root.sec = (id === "fonts" ? 1 : 0)
            }
        }
    }

    NumberAnimation {
        id: bgSectionFade
        target: root.sec === 0 ? bgGrid : fontList
        property: "opacity"
        from: 0.25
        to: 1.0
        duration: (Tokens.reducedMotion || Tokens.gameMode) ? 0 : Math.round(120 * Tokens.motionScale)
        easing.type: Easing.OutCubic
    }

    // Backgrounds Tab
    ColumnLayout {
        visible: root.sec === 0
        width: parent.width
        spacing: Tokens.space.sm

        GridView {
            id: bgGrid

            readonly property int rowCount: Math.ceil(root.bgs.length / 3)

            visible: root.bgs.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(0, Math.min(2 * cellHeight, rowCount * cellHeight) - Tokens.space.sm)
            cellWidth: Math.floor(width / 3)
            cellHeight: Tokens.px(116)
            clip: rowCount > 2
            boundsBehavior: Flickable.StopAtBounds
            model: root.bgs

            delegate: Item {
                id: bgTile

                required property string modelData
                required property int index

                readonly property bool isCurrent: modelData === root.bgCurrent
                readonly property bool selected: root.sec === 0 && root.bgIdx === index

                width: bgGrid.cellWidth
                height: bgGrid.cellHeight

                ClippingRectangle {
                    id: bgCard

                    anchors.fill: parent
                    anchors.leftMargin: Tokens.space.xs
                    anchors.rightMargin: Tokens.space.xs
                    anchors.topMargin: 0
                    anchors.bottomMargin: Tokens.space.sm
                    radius: Tokens.radius.md
                    color: Tokens.veilOf(Tokens.surfaceStyle)
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Wallpaper %1").arg(bgTile.index + 1)

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(384, 224)
                        source: "file://" + bgTile.modelData
                    }

                    Badge {
                        visible: bgTile.isCurrent
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Tokens.space.xs
                        text: "✓"
                        tone: "accent"
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radius.md
                        color: "transparent"
                        border.width: bgTile.isCurrent || bgTile.selected ? Tokens.px(1.5) : Tokens.hairlineWidth
                        border.color: bgTile.isCurrent
                            ? Tokens.color.accent
                            : (bgTile.selected ? Tokens.color.text : Tokens.veilBorderOf(Tokens.surfaceStyle))
                    }

                    FocusRing {
                        active: bgCard.activeFocus
                        ringRadius: Tokens.radius.md
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            Tokens.keyboardNavigation = false
                            root.sec = 0
                            root.bgIdx = bgTile.index
                            root.applyBg(bgTile.index)
                        }
                    }

                    Keys.onSpacePressed: root.applyBg(bgTile.index)
                    Keys.onReturnPressed: root.applyBg(bgTile.index)
                }
            }
        }

        EmptyState {
            visible: root.bgs.length === 0
            Layout.fillWidth: true
            icon: "image"
            title: qsTr("No backgrounds found")
            description: qsTr("This theme has no additional background images.")
        }
    }

    // Fonts Tab
    ColumnLayout {
        visible: root.sec === 1
        width: parent.width
        spacing: Tokens.space.sm

        Card {
            Layout.fillWidth: true
            horizontalPadding: Tokens.space.lg
            verticalPadding: Tokens.space.md
            implicitHeight: previewCol.implicitHeight + verticalPadding * 2

            ColumnLayout {
                id: previewCol

                width: parent.width
                spacing: Tokens.space.xs

                RowLayout {
                    Layout.fillWidth: true

                    TextLabel {
                        role: "caption"
                        tone: "muted"
                        text: qsTr("PREVIEW")
                    }

                    Item { Layout.fillWidth: true }

                    Badge {
                        readonly property string previewName: root.fonts[root.fontIdx] || root.fontCurrent

                        visible: previewName !== ""
                        text: previewName
                        tone: "accent"
                    }
                }

                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.family: root.fonts[root.fontIdx] || root.fontCurrent || Tokens.type.monoFamily
                    font.pixelSize: Tokens.px(18)
                    color: Tokens.color.text
                    text: "0123456789  AaBbCc  !==  =>  { omarchy }"
                }
            }
        }

        ListView {
            id: fontList

            readonly property int visibleRows: Math.min(4, Math.max(1, root.fonts.length))

            visible: root.fonts.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: visibleRows * root.fontRowHeight
                + Math.max(0, visibleRows - 1) * root.fontRowSpacing
            clip: root.fonts.length > 4
            spacing: root.fontRowSpacing
            boundsBehavior: Flickable.StopAtBounds
            model: root.fonts

            delegate: ListRow {
                id: fRow

                required property string modelData
                required property int index

                readonly property bool isCurrent: modelData === root.fontCurrent

                width: fontList.width
                height: root.fontRowHeight
                icon: isCurrent ? "check-circle" : "terminal"
                title: modelData
                selected: root.sec === 1 && root.fontIdx === index
                onClicked: {
                    root.sec = 1
                    root.fontIdx = fRow.index
                    root.applyFont(fRow.index)
                }
            }
        }

        EmptyState {
            visible: root.fonts.length === 0
            Layout.fillWidth: true
            icon: "type"
            title: qsTr("No monospace fonts found")
            description: qsTr("Install a monospace font to configure terminal and bar typography.")
        }
    }
}

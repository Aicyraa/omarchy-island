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

    preferredWidth: 640
    scrollTarget: sec === 1 ? fontList : null
    hint: qsTr("Tab section · ←/→ backgrounds · ↑/↓ fonts · Enter apply · Esc close")

    property int sec: 0
    property int bgIdx: 0
    property int fontIdx: 0
    property var bgs: []
    property string bgCurrent: ""
    property var fonts: []
    property string fontCurrent: ""
    readonly property var bgItems: [""].concat(bgs)

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

    function applyBg(i: int): void {
        if (i === 0) {
            Cmd.run(["omarchy-theme-bg-next"])
            reread.restart()
            return
        }
        const p = bgs[i - 1]
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
        } else if (event.key === Qt.Key_Left && root.sec === 0) {
            IslandState.touch(true)
            root.bgIdx = Math.max(0, root.bgIdx - 1)
            bgList.positionViewAtIndex(root.bgIdx, ListView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Right && root.sec === 0) {
            IslandState.touch(true)
            root.bgIdx = Math.min(root.bgItems.length - 1, root.bgIdx + 1)
            bgList.positionViewAtIndex(root.bgIdx, ListView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Up && root.sec === 1) {
            IslandState.touch(true)
            root.fontIdx = Math.max(0, root.fontIdx - 1)
            fontList.positionViewAtIndex(root.fontIdx, ListView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Down && root.sec === 1) {
            IslandState.touch(true)
            root.fontIdx = Math.min(Math.max(0, root.fonts.length - 1), root.fontIdx + 1)
            fontList.positionViewAtIndex(root.fontIdx, ListView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            IslandState.touch(true)
            if (root.sec === 0)
                root.applyBg(root.bgIdx)
            else
                root.applyFont(root.fontIdx)
            event.accepted = true
        }
    }

    // Header + TabStrip
    RowLayout {
        width: parent.width
        spacing: Tokens.space.md

        DetailHeader {
            Layout.fillWidth: true
            backable: false
            title: qsTr("Look")
            detail: root.sec === 0 ? qsTr("Theme backgrounds") : qsTr("Monospace fonts")
        }

        TabStrip {
            tabs: [
                { id: "backgrounds", label: qsTr("Backgrounds") },
                { id: "fonts", label: qsTr("Fonts") }
            ]
            current: root.sec === 0 ? "backgrounds" : "fonts"
            accessibleLabel: qsTr("Look sections")
            onPicked: id => {
                root.sec = (id === "fonts" ? 1 : 0)
                bgSectionFade.restart()
            }
        }
    }

    NumberAnimation {
        id: bgSectionFade
        target: root.sec === 0 ? bgList : fontList
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

        ListView {
            id: bgList

            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.px(108)
            orientation: ListView.Horizontal
            spacing: Tokens.space.sm
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.bgItems

            delegate: Item {
                id: bgTile

                required property string modelData
                required property int index

                readonly property bool isNext: index === 0
                readonly property bool isCurrent: !isNext && modelData === root.bgCurrent
                readonly property bool selected: root.sec === 0 && root.bgIdx === index

                width: Tokens.px(148)
                height: bgList.height

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Tokens.radius.md
                    color: Tokens.veilOf(Tokens.surfaceStyle)

                    Image {
                        visible: !bgTile.isNext
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(296, 216)
                        source: bgTile.isNext ? "" : "file://" + bgTile.modelData
                    }

                    ColumnLayout {
                        visible: bgTile.isNext
                        anchors.centerIn: parent
                        spacing: Tokens.space.xs

                        Icon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: "skip-forward"
                            size: Tokens.size.iconLg
                            tone: "accent"
                        }

                        TextLabel {
                            Layout.alignment: Qt.AlignHCenter
                            role: "sm"
                            font.weight: Font.Medium
                            text: qsTr("Next")
                        }
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

                    TapHandler {
                        onTapped: {
                            root.sec = 0
                            root.bgIdx = bgTile.index
                            root.applyBg(bgTile.index)
                        }
                    }
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
                spacing: Tokens.space.xxs

                RowLayout {
                    Layout.fillWidth: true

                    TextLabel {
                        role: "caption"
                        tone: "muted"
                        text: qsTr("PREVIEW")
                    }

                    Item { Layout.fillWidth: true }

                    Badge {
                        visible: root.fontCurrent !== ""
                        text: root.fontCurrent
                        tone: "accent"
                    }
                }

                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.family: root.fonts[root.fontIdx] || root.fontCurrent || Tokens.type.monoFamily
                    font.pixelSize: Tokens.type.subtitle
                    color: Tokens.color.text
                    text: "0123456789  AaBbCc  !==  =>  { omarchy }"
                }
            }
        }

        ListView {
            id: fontList

            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.px(210)
            clip: true
            spacing: Tokens.space.xs
            boundsBehavior: Flickable.StopAtBounds
            model: root.fonts

            delegate: ListRow {
                id: fRow

                required property string modelData
                required property int index

                readonly property bool isCurrent: modelData === root.fontCurrent

                width: fontList.width
                icon: isCurrent ? "check-circle" : "terminal"
                title: modelData
                subtitle: qsTr("Monospace")
                selected: root.sec === 1 && root.fontIdx === index
                onClicked: {
                    root.sec = 1
                    root.fontIdx = fRow.index
                    root.applyFont(fRow.index)
                }

                Badge {
                    visible: fRow.isCurrent
                    text: qsTr("Active")
                    tone: "accent"
                }
            }
        }
    }
}

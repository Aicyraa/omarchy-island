pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"
import "../Components"

Surface {
    id: root

    property alias query: searchInput.text
    property string placeholderText: qsTr("Search commands, apps, or files...")
    property string prefixBadge: ""
    property var results: [] // [{ id, title, subtitle, icon, meta }]
    property int currentIndex: 0
    property string railVariant: "capsule"
    property string railSide: "right"
    property var hints: [
        { keys: ["↑", "↓"], label: qsTr("Navigate") },
        { keys: ["↵"], label: qsTr("Run") },
        { keys: ["Esc"], label: qsTr("Close") }
    ]

    signal activated(var entry)
    signal dismissed()

    role: "ground"
    radius: Tokens.radius.lg
    horizontalPadding: Tokens.space.xl
    verticalPadding: Tokens.space.lg
    implicitWidth: Tokens.size.panelMd
    implicitHeight: Tokens.px(440)

    function focusSearch(): void {
        searchInput.focusInput()
    }

    function moveSelection(delta: int): void {
        if (!root.results || root.results.length === 0)
            return
        root.currentIndex = (root.currentIndex + delta + root.results.length) % root.results.length
        resultList.positionViewAtIndex(root.currentIndex, ListView.Contain)
    }

    onResultsChanged: {
        if (!root.results || root.results.length === 0)
            root.currentIndex = -1
        else if (root.currentIndex < 0 || root.currentIndex >= root.results.length)
            root.currentIndex = 0
    }

    Keys.onUpPressed: root.moveSelection(-1)
    Keys.onDownPressed: root.moveSelection(1)
    Keys.onEscapePressed: root.dismissed()
    Keys.onReturnPressed: {
        if (root.results && root.currentIndex >= 0 && root.currentIndex < root.results.length)
            root.activated(root.results[root.currentIndex])
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.space.md

        TextField {
            id: searchInput

            Layout.fillWidth: true
            icon: "search"
            prefixBadge: root.prefixBadge
            placeholderText: root.placeholderText
            onAccepted: {
                if (root.results && root.currentIndex >= 0 && root.currentIndex < root.results.length)
                    root.activated(root.results[root.currentIndex])
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Card {
                id: listFrame

                anchors.fill: parent
                anchors.leftMargin: root.railSide === "left" && resultRail.needed ? Tokens.space.lg : 0
                anchors.rightMargin: root.railSide === "right" && resultRail.needed ? Tokens.space.lg : 0
                horizontalPadding: Tokens.space.xs
                verticalPadding: Tokens.space.xs

                ListView {
                    id: resultList

                    anchors.fill: parent
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    visible: root.results && root.results.length > 0
                    model: root.results

                    delegate: ListRow {
                        id: rowItem

                        required property var modelData
                        required property int index

                        width: resultList.width
                        icon: rowItem.modelData.icon ?? ""
                        title: rowItem.modelData.title ?? ""
                        subtitle: rowItem.modelData.subtitle ?? ""
                        meta: rowItem.modelData.meta ?? ""
                        selected: rowItem.index === root.currentIndex
                        onClicked: {
                            root.currentIndex = rowItem.index
                            root.activated(rowItem.modelData)
                        }
                    }
                }

                EmptyState {
                    anchors.centerIn: parent
                    visible: !root.results || root.results.length === 0
                    icon: "search"
                    title: qsTr("No matching results")
                    description: qsTr("Try a different query or clear the filter.")
                }
            }

            ScrollRail {
                id: resultRail

                target: resultList
                anchorWidget: listFrame
                side: root.railSide
                variant: root.railVariant
                revealPolicy: "auto"
            }
        }

        Separator {}

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.space.lg

            Repeater {
                model: root.hints

                RowLayout {
                    id: hintGroup

                    required property var modelData

                    spacing: Tokens.space.xs

                    Repeater {
                        model: hintGroup.modelData.keys ?? []

                        Keycap {
                            required property string modelData

                            text: modelData
                        }
                    }

                    TextLabel {
                        role: "caption"
                        tone: "muted"
                        text: hintGroup.modelData.label ?? ""
                    }
                }
            }

            Item { Layout.fillWidth: true }

            TextLabel {
                role: "caption"
                tone: "muted"
                tabular: true
                text: root.results ? qsTr("%1 items").arg(root.results.length) : ""
            }
        }
    }
}

import QtQuick
import ".."
import "../services"

// Agents: asymmetrical AI harness & usage overview. Shows currently running and default
// harnesses (OpenCode, Antigravity, Claude Code, Codex, etc.) with quota bars for
// limit-tracked providers and model/token/session breakdowns for local-stats harnesses.
// Keys: R refresh · Esc close.
WidgetPanel {
  id: root
  preferredWidth: 620
  hint: "R refresh · Esc close"

  readonly property var agents: AgentUsage.agents
  readonly property bool loading: !AgentUsage.loaded
  readonly property real todayTokens: agents.reduce(function (s, a) { return s + a.today }, 0)
  readonly property real weekTokens: agents.reduce(function (s, a) { return s + a.week }, 0)
  readonly property int activeCount: agents.filter(function (a) { return a.isRunning }).length

  Keys.onPressed: function (e) { if (e.key === Qt.Key_R) { AgentUsage.collect(true); e.accepted = true } }
  Component.onCompleted: { AgentUsage.watch(true); AgentUsage.refresh(); AgentUsage.collect(false) }
  Component.onDestruction: AgentUsage.watch(false)

  property real now: Date.now()
  Timer { interval: 15000; repeat: true; running: true; onTriggered: root.now = Date.now() }
  function ago(ms) { var m = Math.round((root.now - ms) / 60000); return m < 1 ? "just now" : m < 60 ? m + "m ago" : Math.round(m / 60) + "h ago" }

  function glyph(id) {
    return ({
      opencode: "terminal",
      agy: "orbit",
      claude: "spark",
      codex: "brackets",
      copilot: "plane",
      cursor: "pointer"
    })[String(id)] || "bot"
  }
  function resets(iso) {
    var t = Date.parse(iso); if (isNaN(t)) return ""
    var m = Math.max(0, Math.round((t - root.now) / 60000))
    return m < 60 ? ("resets " + m + "m") : m < 1440 ? ("resets " + Math.round(m / 60) + "h") : ("resets " + Math.round(m / 1440) + "d")
  }
  function fmt(n) {
    n = Number(n) || 0
    if (n >= 1e9) return (n / 1e9).toFixed(n >= 1e10 ? 0 : 1) + "B"
    if (n >= 1e6) return (n / 1e6).toFixed(n >= 1e7 ? 0 : 1) + "M"
    if (n >= 1e3) return (n / 1e3).toFixed(n >= 1e4 ? 0 : 1) + "K"
    return String(Math.round(n))
  }
  function shortModel(m) { return String(m).replace(/^claude-/, "").replace(/^gpt-/, "GPT-").slice(0, 26) }

  dataLoading: !AgentUsage.loaded
  compact: !loading && agents.length === 0

  // ---- Asymmetrical summary header: dominant Today hero on left, 7-day + refresh on right ----
  readonly property real sumLeftW: Math.round((width - 2 * pad - Theme.s12) * 0.58)
  readonly property real sumRightW: (width - 2 * pad - Theme.s12) - sumLeftW

  Row {
    visible: root.agents.length > 0
    width: parent.width; spacing: Theme.s12

    SmoothRect {
      width: root.sumLeftW; height: 66; radius: Theme.tileRadius; color: Theme.surface
      Column {
        anchors.left: parent.left; anchors.leftMargin: Theme.s16; anchors.verticalCenter: parent.verticalCenter; spacing: 1
        Label { text: "Tokens today"; color: Theme.textMuted; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel }
        Label { mono: true; text: root.fmt(root.todayTokens); color: Theme.text; font.pixelSize: 24; font.weight: Theme.weightStrong }
      }
      Row {
        anchors.right: parent.right; anchors.rightMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter; spacing: 6
        SmoothRect {
          visible: root.activeCount > 0; height: 22; width: runPillRow.implicitWidth + 14; radius: 11
          color: Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.20)
          Row {
            id: runPillRow; anchors.centerIn: parent; spacing: 5
            SmoothRect { width: 6; height: 6; radius: 3; color: Theme.successInk; anchors.verticalCenter: parent.verticalCenter }
            Label { text: root.activeCount + " active"; color: Theme.successInk; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel; anchors.verticalCenter: parent.verticalCenter }
          }
        }
        SmoothRect {
          visible: AgentUsage.defaultAgent !== ""; height: 22; width: defLbl.implicitWidth + 14; radius: 11
          color: Theme.surfaceRaised
          Label { id: defLbl; anchors.centerIn: parent; text: "Default: " + AgentUsage.defaultAgent; color: Theme.textMuted; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel }
        }
      }
    }

    SmoothRect {
      width: root.sumRightW; height: 66; radius: Theme.tileRadius; color: Theme.surface
      Column {
        anchors.left: parent.left; anchors.leftMargin: Theme.s16; anchors.verticalCenter: parent.verticalCenter; spacing: 1
        Label { text: "7-day activity"; color: Theme.textMuted; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel }
        Label { mono: true; text: root.fmt(root.weekTokens); color: Theme.text; font.pixelSize: 18; font.weight: Theme.weightStrong }
      }
      Row {
        anchors.right: parent.right; anchors.rightMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
        Label {
          visible: AgentUsage.fetchedAt > 0; anchors.verticalCenter: parent.verticalCenter
          text: root.ago(AgentUsage.fetchedAt); color: Theme.textMuted; font.pixelSize: Theme.typeCaption
        }
        IconButton { icon: "refresh"; onClicked: AgentUsage.collect(true) }
      }
    }
  }

  Label { visible: !root.loading && root.agents.length === 0; text: "No agent usage yet"; color: Theme.textMuted; font.pixelSize: Theme.typeTitle }
  Label { visible: root.loading; text: "Reading harness usage…"; color: Theme.textMuted; font.pixelSize: Theme.typeTitle }

  // ---- Per-agent asymmetrical cards ----
  Repeater {
    model: root.agents
    delegate: SmoothRect {
      id: card
      required property var modelData
      readonly property color track: Theme.mix(Theme.surface, Theme.text, 0.14)
      readonly property var mainLimit: modelData.limits && modelData.limits.length > 0 ? modelData.limits[0] : null
      readonly property bool limitKnown: mainLimit !== null && typeof mainLimit.percent === "number"
      readonly property bool hasLocalUsage: modelData.today > 0 || (modelData.inT + modelData.outT) > 0 || modelData.totalPrompts > 0
      width: parent.width
      height: cardRow.implicitHeight + 2 * Theme.s12
      radius: Theme.tileRadius; color: Theme.surface
      borderWidth: modelData.isRunning ? 1 : 0
      borderColor: Qt.rgba(Theme.successInk.r, Theme.successInk.g, Theme.successInk.b, 0.45)

      Row {
        id: cardRow
        x: Theme.s16; y: Theme.s12; width: parent.width - 2 * Theme.s16; spacing: Theme.s12
        readonly property real leftW: Math.round((width - Theme.s12) * 0.68)
        readonly property real rightW: width - Theme.s12 - leftW

        Column {
          width: cardRow.leftW; spacing: Theme.s8

          Row {
            width: parent.width; spacing: Theme.s8
            SmoothRect {
              width: 28; height: 28; radius: Theme.radiusChip; anchors.verticalCenter: parent.verticalCenter
              color: card.modelData.isRunning
                ? Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.22)
                : Theme.mix(Theme.surface, Theme.accentFill, 0.16)
              Icon {
                anchors.centerIn: parent; name: root.glyph(card.modelData.id); size: Theme.iconSm
                color: card.modelData.top >= 0.9 ? Theme.dangerInk : (card.modelData.isRunning ? Theme.successInk : Theme.accentInk)
              }
            }
            Label {
              anchors.verticalCenter: parent.verticalCenter
              text: card.modelData.name; color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightStrong
            }
            SmoothRect {
              visible: card.modelData.isRunning; height: 20; width: runTag.implicitWidth + 12; radius: 10; anchors.verticalCenter: parent.verticalCenter
              color: Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.20)
              Label { id: runTag; anchors.centerIn: parent; text: "Running"; color: Theme.successInk; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel }
            }
            SmoothRect {
              visible: card.modelData.isDefault; height: 20; width: defTag.implicitWidth + 12; radius: 10; anchors.verticalCenter: parent.verticalCenter
              color: Theme.accentFill
              Label { id: defTag; anchors.centerIn: parent; text: "Default"; color: Theme.accentText; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel }
            }
            Label {
              visible: card.modelData.tier !== ""; anchors.verticalCenter: parent.verticalCenter
              text: card.modelData.tier; color: Theme.textMuted; font.pixelSize: Theme.typeCaption
            }
          }

          // Mode A: Provider exposes quota limits
          Column {
            visible: card.limitKnown
            width: parent.width; spacing: 4
            SmoothRect {
              width: parent.width; height: 7; radius: 3.5; color: card.track
              SmoothRect {
                width: Math.max(card.mainLimit && card.mainLimit.percent > 0 ? 6 : 0, parent.width * Math.min(1, Math.max(0, card.mainLimit ? card.mainLimit.percent : 0)))
                height: parent.height; radius: 3.5
                color: card.mainLimit && card.mainLimit.percent >= 0.9 ? Theme.dangerInk
                     : (card.mainLimit && card.mainLimit.percent >= 0.7 ? Theme.warningInk : Theme.accentFill)
              }
            }
            Item {
              width: parent.width; height: 15
              Label {
                anchors.left: parent.left; anchors.right: limRight.left; anchors.rightMargin: Theme.s8
                elide: Text.ElideRight
                text: (card.mainLimit ? String(card.mainLimit.label || "Limit") : "") + (card.modelData.status !== "" ? (" · " + card.modelData.status) : "")
                color: Theme.textMuted; font.pixelSize: Theme.typeCaption
              }
              Label {
                id: limRight; anchors.right: parent.right; mono: true
                text: (card.mainLimit ? Math.round(card.mainLimit.percent * 100) + "%" : "")
                    + (card.mainLimit && root.resets(card.mainLimit.resetsAt) !== "" ? (" · " + root.resets(card.mainLimit.resetsAt)) : "")
                color: Theme.text; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel
              }
            }
          }

          // Mode B: Local-stats / multi-model harness
          Column {
            visible: !card.limitKnown
            width: parent.width; spacing: 4
            Row {
              width: parent.width; spacing: Theme.s8
              SmoothRect {
                visible: card.modelData.topModel !== ""; height: 22; width: Math.min(parent.width * 0.62, modTxt.implicitWidth + 14); radius: 11
                color: Theme.surfaceRaised
                Label {
                  id: modTxt; anchors.centerIn: parent; width: parent.width - 12; horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight; text: root.shortModel(card.modelData.topModel)
                  color: Theme.text; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel
                }
              }
              Label {
                anchors.verticalCenter: parent.verticalCenter
                text: card.hasLocalUsage
                  ? (card.modelData.totalPrompts + " prompts · " + card.modelData.sessions + " sessions")
                  : (card.modelData.isDefault ? "Configured default harness" : "Ready")
                color: Theme.textMuted; font.pixelSize: Theme.typeCaption
              }
            }
            Label {
              visible: card.modelData.inT + card.modelData.outT > 0
              width: parent.width; elide: Text.ElideRight; mono: true
              text: root.fmt(card.modelData.outT) + " out · " + root.fmt(card.modelData.inT) + " in"
                  + (card.modelData.cacheT > 0 ? (" · " + root.fmt(card.modelData.cacheT) + " cached") : "")
              color: Theme.textMuted; font.pixelSize: Theme.typeCaption
            }
          }
        }

        Column {
          width: cardRow.rightW; anchors.verticalCenter: parent.verticalCenter; spacing: 4
          Row {
            anchors.right: parent.right; spacing: 3; visible: card.modelData.week > 0
            Repeater {
              model: card.modelData.days
              delegate: Item {
                required property int index; required property real modelData
                width: 6; height: 22
                SmoothRect {
                  anchors.bottom: parent.bottom; width: 6; radius: 3
                  height: Math.max(3, 22 * parent.modelData / card.modelData.dayMax)
                  color: parent.index === card.modelData.days.length - 1 ? Theme.accentInk : card.track
                }
              }
            }
          }
          Label {
            anchors.right: parent.right; mono: true
            text: card.modelData.today > 0 ? root.fmt(card.modelData.today) : (card.modelData.totalPrompts > 0 ? (card.modelData.totalPrompts + " total") : "—")
            color: card.modelData.today > 0 ? Theme.text : Theme.textMuted
            font.pixelSize: 15; font.weight: Theme.weightStrong
          }
          Label {
            anchors.right: parent.right
            text: card.modelData.today > 0 ? "tokens today" : (card.modelData.totalPrompts > 0 ? "prompts" : "no tokens yet")
            color: Theme.textMuted; font.pixelSize: Theme.typeCaption
          }
        }
      }
    }
  }
}

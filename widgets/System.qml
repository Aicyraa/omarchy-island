import QtQuick
import ".."
import "../services"

// System: asymmetrical Apple telemetry dashboard — dominant CPU hero card (58%) with
// clock/cores/uptime pill and full-width sparkline on the left; Memory and Temperature cards
// on the right (42%) with clear sparklines and status badges; middle Disk/Load/Network/Swap
// tiles; and a clean Top Processes card at the bottom with aligned tabular columns.
WidgetPanel {
  id: root
  preferredWidth: 640
  hint: "Esc close"
  Component.onCompleted: Stats.sampling = true
  Component.onDestruction: Stats.sampling = false

  dataLoading: !SysInfo.loaded
  readonly property int cpuPct: Math.round(Stats.cpu * 100)
  readonly property int memPct: Math.round(Stats.mem * 100)
  readonly property int tempWarn: Stats.temp > 80 ? 2 : (Stats.temp > 70 ? 1 : 0)
  readonly property int memWarn: memPct >= 90 ? 2 : (memPct >= 78 ? 1 : 0)
  readonly property int cpuWarn: cpuPct >= 85 ? 2 : (cpuPct >= 65 ? 1 : 0)

  readonly property real load1: SysInfo.load1
  readonly property real load5: SysInfo.load5
  readonly property real load15: SysInfo.load15
  readonly property real uptimeSec: SysInfo.uptimeSec
  readonly property real diskUsed: SysInfo.diskUsed
  readonly property real diskSize: SysInfo.diskSize
  readonly property real swapTotal: SysInfo.swapTotal
  readonly property real swapUsed: SysInfo.swapUsed
  readonly property real freqMHz: SysInfo.freqMHz
  readonly property int cores: SysInfo.cores
  readonly property real rxRate: SysInfo.rxRate
  readonly property real txRate: SysInfo.txRate
  readonly property var procs: SysInfo.procs

  function bytes(n) {
    n = Number(n) || 0
    var u = ["B", "KB", "MB", "GB", "TB"], i = 0
    while (n >= 1000 && i < 4) { n /= 1000; i++ }
    return (n >= 100 || i === 0 ? Math.round(n) : n.toFixed(1)) + " " + u[i]
  }
  function dur(sec) {
    var d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60)
    return d > 0 ? d + "d " + h + "h" : (h > 0 ? h + "h " + m + "m" : m + "m")
  }
  Timer { interval: 2500; repeat: true; running: true; triggeredOnStart: true; onTriggered: SysInfo.refresh() }

  // Use inner content width (`width - 2 * pad`) so cards never overflow horizontally.
  readonly property real innerW: width - 2 * pad
  readonly property real colL: Math.round((innerW - Theme.s12) * 0.58)
  readonly property real colR: innerW - Theme.s12 - colL

  // ---- Top asymmetrical block: CPU hero (58%) + stacked Memory & Temperature (42%) ----
  Row {
    width: parent.width; spacing: Theme.s12

    // Left CPU hero card
    SmoothRect {
      width: root.colL; height: 150; radius: Theme.tileRadius; color: Theme.surface
      readonly property color tint: root.cpuWarn === 2 ? Theme.dangerInk : (root.cpuWarn === 1 ? Theme.warningInk : Theme.accentInk)

      // Header row: icon chip + CPU label left, clock + cores pill right
      Item {
        x: Theme.s12; y: Theme.s12; width: parent.width - 2 * Theme.s12; height: 28
        SmoothRect {
          id: cpuChip; width: 28; height: 28; radius: Theme.radiusChip
          color: Qt.rgba(parent.parent.tint.r, parent.parent.tint.g, parent.parent.tint.b, 0.16)
          Icon { anchors.centerIn: parent; name: "cpu"; size: Theme.iconSm; color: parent.parent.parent.tint }
        }
        Label {
          anchors.left: cpuChip.right; anchors.leftMargin: Theme.s8; anchors.verticalCenter: parent.verticalCenter
          text: "CPU"; color: Theme.textMuted; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel
        }
        SmoothRect {
          visible: root.freqMHz > 0
          anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
          height: 22; width: clkTxt.implicitWidth + 14; radius: 11; color: Theme.surfaceRaised
          Label {
            id: clkTxt; anchors.centerIn: parent; mono: true
            text: (root.freqMHz / 1000).toFixed(2) + " GHz · " + root.cores + "c"
            color: Theme.textMuted; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel
          }
        }
      }

      // Focal % + state badge + uptime
      Item {
        x: Theme.s12; y: 44; width: parent.width - 2 * Theme.s12; height: 42
        Label {
          id: cpuVal; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
          mono: true; text: root.cpuPct + "%"; color: Theme.text
          font.pixelSize: 34; font.weight: Theme.weightStrong
        }
        Row {
          anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
          Label {
            visible: root.uptimeSec > 0; anchors.verticalCenter: parent.verticalCenter
            text: "Up " + root.dur(root.uptimeSec); color: Theme.textMuted; font.pixelSize: Theme.typeCaption
          }
          SmoothRect {
            height: 22; width: stateLbl.implicitWidth + 14; radius: 11; anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(parent.parent.parent.tint.r, parent.parent.parent.tint.g, parent.parent.parent.tint.b, 0.18)
            Label {
              id: stateLbl; anchors.centerIn: parent
              text: root.cpuWarn === 2 ? "Heavy" : (root.cpuWarn === 1 ? "Active" : "Idle")
              color: parent.parent.parent.parent.tint; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel
            }
          }
        }
      }

      // Clean full-width CPU chart
      Sparkline {
        x: Theme.s12; anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.s12
        width: parent.width - 2 * Theme.s12; height: 46
        samples: Stats.cpuHist; color: parent.tint; lineWidth: 2.2; fillAlpha: 0.24
      }
    }

    // Right stacked cards: Memory + Temperature
    Column {
      width: root.colR; spacing: Theme.s8

      // Memory card
      SmoothRect {
        width: parent.width; height: 71; radius: Theme.tileRadius; color: Theme.surface
        readonly property color tint: root.memWarn === 2 ? Theme.dangerInk : (root.memWarn === 1 ? Theme.warningInk : Theme.accentInk)

        Item {
          x: Theme.s12; y: 8; width: parent.width - 2 * Theme.s12; height: 24
          SmoothRect {
            id: ramChip; width: 24; height: 24; radius: 8
            color: Qt.rgba(parent.parent.tint.r, parent.parent.tint.g, parent.parent.tint.b, 0.16)
            Icon { anchors.centerIn: parent; name: "ram"; size: 14; color: parent.parent.parent.tint }
          }
          Label {
            anchors.left: ramChip.right; anchors.leftMargin: Theme.s8; anchors.verticalCenter: parent.verticalCenter
            text: "Memory"; color: Theme.textMuted; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel
          }
          Label {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; mono: true
            text: root.memPct + "%"; color: parent.parent.tint; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightStrong
          }
        }
        Item {
          x: Theme.s12; y: 35; width: parent.width - 2 * Theme.s12; height: 24
          Row {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 4
            Label { id: memUsedLbl; mono: true; text: Stats.memUsedGb.toFixed(1); color: Theme.text; font.pixelSize: 18; font.weight: Theme.weightStrong }
            Label { anchors.baseline: memUsedLbl.baseline; mono: true; text: "/ " + Stats.memTotalGb.toFixed(0) + " GB"; color: Theme.textMuted; font.pixelSize: Theme.typeCaption }
          }
          Sparkline {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 64; height: 20; samples: Stats.memHist; color: parent.parent.tint; lineWidth: 1.8; fillAlpha: 0.22
          }
        }
        SmoothRect {
          x: Theme.s12; width: parent.width - 2 * Theme.s12; y: parent.height - 6; height: 3; radius: 1.5
          color: Theme.mix(Theme.surface, Theme.text, 0.14)
          SmoothRect { height: parent.height; radius: 1.5; width: parent.width * Math.max(0, Math.min(1, Stats.mem)); color: parent.parent.tint }
        }
      }

      // Temperature card
      SmoothRect {
        width: parent.width; height: 71; radius: Theme.tileRadius; color: Theme.surface
        readonly property color tint: root.tempWarn === 2 ? Theme.dangerInk : (root.tempWarn === 1 ? Theme.warningInk : Theme.accentInk)

        Item {
          x: Theme.s12; y: 8; width: parent.width - 2 * Theme.s12; height: 24
          SmoothRect {
            id: thChip; width: 24; height: 24; radius: 8
            color: Qt.rgba(parent.parent.tint.r, parent.parent.tint.g, parent.parent.tint.b, 0.16)
            Icon { anchors.centerIn: parent; name: "thermo"; size: 14; color: parent.parent.parent.tint }
          }
          Label {
            anchors.left: thChip.right; anchors.leftMargin: Theme.s8; anchors.verticalCenter: parent.verticalCenter
            text: "Temperature"; color: Theme.textMuted; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel
          }
          SmoothRect {
            visible: Stats.temp > 0; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            height: 18; width: thState.implicitWidth + 12; radius: 9
            color: Qt.rgba(parent.parent.tint.r, parent.parent.tint.g, parent.parent.tint.b, 0.18)
            Label {
              id: thState; anchors.centerIn: parent
              text: root.tempWarn === 2 ? "Hot" : (root.tempWarn === 1 ? "Warm" : "Cool")
              color: parent.parent.parent.tint; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel
            }
          }
        }
        Item {
          x: Theme.s12; y: 35; width: parent.width - 2 * Theme.s12; height: 24
          Label {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; mono: true
            text: Stats.temp > 0 ? Math.round(Stats.temp) + "°C" : "—"
            color: Theme.text; font.pixelSize: 18; font.weight: Theme.weightStrong
          }
          Sparkline {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 64; height: 20; samples: Stats.tempHist; color: parent.parent.tint; lineWidth: 1.8; fillAlpha: 0.22
          }
        }
      }
    }
  }

  // ---- Middle asymmetrical telemetry grid: Disk & Load left, Network & Swap right ----
  Row {
    width: parent.width; spacing: Theme.s12
    Column {
      width: root.colL; spacing: Theme.s8
      StatTile {
        width: parent.width; label: "Disk /"; monoValue: true
        value: root.bytes(root.diskUsed) + " / " + root.bytes(root.diskSize)
        fraction: root.diskUsed / root.diskSize
      }
      StatTile {
        width: parent.width; label: "Load average"; monoValue: true
        value: root.load1.toFixed(2) + " · " + root.load5.toFixed(2) + " · " + root.load15.toFixed(2)
        fraction: root.cores > 0 ? root.load1 / root.cores : -1
      }
    }
    Column {
      width: root.colR; spacing: Theme.s8
      StatTile {
        width: parent.width; label: "Network"; monoValue: true
        value: root.rxRate >= 0 ? ("↓ " + root.bytes(root.rxRate) + "/s  ↑ " + root.bytes(root.txRate) + "/s") : "Measuring…"
      }
      StatTile {
        width: parent.width; label: "Swap"; monoValue: true
        value: root.swapTotal > 0 ? (root.bytes(root.swapUsed) + " / " + root.bytes(root.swapTotal)) : "None"
        fraction: root.swapTotal > 0 ? root.swapUsed / root.swapTotal : -1
      }
    }
  }

  // ---- Bottom Top Processes card with aligned tabular CPU / MEM columns ----
  SmoothRect {
    visible: root.procs.length > 0
    width: parent.width
    height: procCol.implicitHeight + 2 * Theme.s12
    radius: Theme.tileRadius; color: Theme.surface

    Column {
      id: procCol
      x: Theme.s12; y: Theme.s12; width: parent.width - 2 * Theme.s12; spacing: 4

      Item {
        width: parent.width; height: 16
        Label { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Top processes"; color: Theme.textMuted; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel }
        Row {
          anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s12
          Label { width: 46; horizontalAlignment: Text.AlignRight; text: "CPU"; color: Theme.textMuted; font.pixelSize: Theme.typeCaption }
          Label { width: 50; horizontalAlignment: Text.AlignRight; text: "MEM"; color: Theme.textMuted; font.pixelSize: Theme.typeCaption }
        }
      }

      Repeater {
        model: root.procs.slice(0, 3)
        delegate: Item {
          required property var modelData
          readonly property color tint: modelData.cpu >= 50 ? Theme.dangerInk : (modelData.cpu >= 25 ? Theme.warningInk : Theme.accentInk)
          width: parent.width; height: 24

          SmoothRect {
            id: pBadge; x: 0; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; radius: 10
            color: Theme.mix(Theme.surfaceRaised, parent.tint, 0.24)
            Label { anchors.centerIn: parent; text: String(modelData.name).charAt(0).toUpperCase(); color: parent.parent.tint; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightStrong }
          }
          Label {
            id: pName
            anchors.left: pBadge.right; anchors.leftMargin: Theme.s8
            width: Math.min(180, parent.width * 0.34); anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight; text: modelData.name; color: Theme.text; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel
          }
          SmoothRect {
            anchors.left: pName.right; anchors.leftMargin: Theme.s12
            anchors.right: pCols.left; anchors.rightMargin: Theme.s12
            anchors.verticalCenter: parent.verticalCenter
            height: 4; radius: 2; color: Theme.mix(Theme.surface, Theme.text, 0.12)
            SmoothRect {
              height: parent.height; radius: 2; color: parent.parent.tint
              width: Math.max(3, parent.width * Math.min(1, modelData.cpu / 100))
              Behavior on width { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 280; easing.type: Easing.OutCubic } }
            }
          }
          Row {
            id: pCols; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s12
            Label {
              width: 46; horizontalAlignment: Text.AlignRight; mono: true
              text: modelData.cpu.toFixed(modelData.cpu < 10 ? 1 : 0) + "%"
              color: Theme.text; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel
            }
            Label {
              width: 50; horizontalAlignment: Text.AlignRight; mono: true
              text: modelData.mem.toFixed(1) + "%"
              color: Theme.textMuted; font.pixelSize: Theme.typeCaption
            }
          }
        }
      }
    }
  }
}

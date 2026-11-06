import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import ".."
import "../services"

// The idle form of the pill (the hover form is HoverPreview).
//
// Layout rules (they fix the old "unequal gaps" and "clock jumps on hover" bugs):
//   * The TIME is anchored to the exact centre of the form, so it never moves.
//     position never changes when the pill grows. Hover only adds the date to its right.
//   * The pill width is computed from content so the left and right halves are
//     equal: half = pad + timeW/2 + gap + max(left need, right need). The wider side
//     decides, and the other side's extra room becomes window-title space.
//   * Left content left-aligns, right content right-aligns, icons are all iconMd (20).
//
// widthFor() is read by Island to size the idle pill.
Item {
  id: form
  property var win: null                  // the PanelWindow (for screen name + widget toggling)

  readonly property int pad: Theme.s12
  readonly property int gap: Theme.s12
  readonly property int iconGap: Theme.s8

  // ---- measuring (TextMetrics works even while an item is hidden) ----
  TextMetrics { id: timeM; font.pixelSize: 12; font.weight: Theme.weightLabel; text: "00:00" }
  readonly property real timeW: timeM.advanceWidth
  readonly property real baseW: baseRow.implicitWidth
  readonly property real wsW: ws.implicitWidth
  // Audio visualizer: while a player is playing, a few bars come out of the left side of the time.
  readonly property bool playing: Quickshell.env("ISLAND_FORCE_VIZ") === "1" || Mpris.players.values.some(function (p) { return p.isPlaying })
  readonly property real vizW: 32
  readonly property real vizNeed: playing ? vizW + Theme.s8 : 0

  // Equal halves around the centred clock: the wider side decides.
  function widthFor() {
    var left = timeW / 2 + gap + wsW + vizNeed
    var right = timeW / 2 + gap + baseW
    return Math.ceil(2 * (pad + Math.max(left, right)))
  }

  SystemClock { id: clock; precision: SystemClock.Minutes }

  // ---------------- left: workspaces ----------------
  Item {
    id: left
    width: ws.implicitWidth; height: ws.implicitHeight
    anchors.left: parent.left; anchors.leftMargin: form.pad
    anchors.verticalCenter: parent.verticalCenter
    Workspaces { id: ws }
  }

  // ---------------- centre: time (fixed at the centre) ----------------
  Text {
    id: timeText
    objectName: "clockText"
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: Qt.formatDateTime(clock.date, "HH:mm")
    color: Theme.text; font.pixelSize: 12; font.weight: Theme.weightLabel
    TapHandler { onTapped: IslandState.toggleWidget("calendar", form.win ? form.win.screenName : "") }
  }

  // The bars sit against the time's left edge inside a clipping box whose width springs open, so they appear to
  // slide out from behind the clock (and slide back in when the music stops).
  Item {
    id: vizBox
    anchors.right: timeText.left; anchors.rightMargin: Theme.s8
    anchors.verticalCenter: parent.verticalCenter
    height: 14; clip: true
    width: form.playing ? form.vizW : 0
    opacity: form.playing ? 1 : 0
    Behavior on width { enabled: !IslandState.reducedMotion; SpringAnimation { spring: 4.5; damping: 0.38; epsilon: 0.3 } }
    Behavior on opacity { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 200 } }
    Visualizer {
      anchors.right: parent.right; width: form.vizW; height: 14
      bars: 7; color: Theme.text
      active: form.playing && form.visible
    }
  }

  // ---------------- right: [hover extras] [indicators, Wi-Fi, battery] ----------------
  Row {
    id: right
    anchors.right: parent.right; anchors.rightMargin: form.pad
    anchors.verticalCenter: parent.verticalCenter
    spacing: form.iconGap

    // active indicators (only while on), Wi-Fi, battery
    Row {
      id: baseRow
      spacing: form.iconGap
      anchors.verticalCenter: parent.verticalCenter
      BarIcon {                                // screen recording with a ticking timer
        visible: Indicators.recording; anchors.verticalCenter: parent.verticalCenter
        onClicked: Cmd.run(["omarchy-capture-screenrecording", "--stop-recording"])
        Row { spacing: 4
          Icon { name: "record"; size: Theme.iconMd; matchBattery: true; color: Theme.dangerInk; anchors.verticalCenter: parent.verticalCenter }
          Text { id: recText; textFormat: Text.PlainText; color: Theme.dangerInk; font.pixelSize: 11; font.weight: Theme.weightLabel
            anchors.verticalCenter: parent.verticalCenter
            property real startedAt: Date.now() - Indicators.recSeconds * 1000
            property int elapsed: 0
            text: Math.floor(elapsed / 60) + ":" + ("0" + elapsed % 60).slice(-2)
            Timer { interval: 1000; repeat: true; running: Indicators.recording; triggeredOnStart: true      // exists only while recording
              onTriggered: recText.elapsed = Math.max(0, Math.floor((Date.now() - recText.startedAt) / 1000)) } } }
      }
      BarIcon { visible: Indicators.dictationAvailable && Indicators.dictation !== "idle"; anchors.verticalCenter: parent.verticalCenter
        onClicked: Indicators.toggleDictation(); Icon { name: "mic-dictate"; size: Theme.iconMd; matchBattery: true; color: Theme.warningInk } }
      BarIcon { visible: Indicators.dnd; anchors.verticalCenter: parent.verticalCenter
        onClicked: Indicators.toggleDnd(); Icon { name: "bell-off"; size: Theme.iconMd; matchBattery: true; color: Theme.textMuted } }
      BarIcon { visible: Indicators.nightLight; anchors.verticalCenter: parent.verticalCenter
        onClicked: Indicators.toggleNightLight(); Icon { name: "moon"; size: Theme.iconMd; matchBattery: true; color: Theme.warningInk } }
      BarIcon { visible: Indicators.stayAwake; anchors.verticalCenter: parent.verticalCenter
        onClicked: Indicators.toggleStayAwake(); Icon { name: "coffee"; size: Theme.iconMd; matchBattery: true; color: Theme.textMuted } }
      BarIcon { visible: Indicators.updateAvailable; anchors.verticalCenter: parent.verticalCenter
        onClicked: Cmd.run(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"])
        Icon { name: "download"; size: Theme.iconMd; matchBattery: true; color: Theme.accentInk } }
      BarIcon { visible: Net.hasWifi; anchors.verticalCenter: parent.verticalCenter
        onClicked: IslandState.toggleWidget("wifi", form.win ? form.win.screenName : "")
        onRightClicked: IslandState.toggleWidget("wifi", form.win ? form.win.screenName : "")
        WifiIcon { level: Net.connected ? Net.strength : 0; off: !Net.enabled; size: Theme.iconMd; matchBattery: true } }
      BarIcon { visible: Power.present; anchors.verticalCenter: parent.verticalCenter
        onClicked: IslandState.toggleWidget("battery", form.win ? form.win.screenName : "")
        onRightClicked: IslandState.toggleWidget("battery", form.win ? form.win.screenName : "")
        BatteryIcon { size: Theme.iconMd } }
    }
  }
}

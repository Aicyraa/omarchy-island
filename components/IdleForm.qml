import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../services"

// The idle and hover forms of the pill, in ONE component so they share geometry.
//
// Layout rules (they fix the old "unequal gaps" and "clock jumps on hover" bugs):
//   * The TIME is anchored to the exact centre of the form in both states, so its
//     position never changes when the pill grows. Hover only adds the date to its right.
//   * The pill width is computed from content so the left and right halves are
//     equal: half = pad + timeW/2 + gap + max(left need, right need). The wider side
//     decides, and the other side's extra room becomes window-title space.
//   * Left content left-aligns, right content right-aligns, icons are all iconMd (20).
//
// widthFor(hover) is read by Island to size the pill for either state.
Item {
  id: form
  property bool expanded: false           // hover form
  property var win: null                  // the PanelWindow (for screen name + widget toggling)

  readonly property int pad: Theme.s12
  readonly property int gap: Theme.s12
  readonly property int iconGap: Theme.s8

  // ---- measuring (TextMetrics works even while an item is hidden) ----
  TextMetrics { id: timeM; font.pixelSize: 12; font.bold: true; text: "00:00" }
  TextMetrics { id: dateM; font.pixelSize: 12; text: "Wed, Nov 30" }       // widest plausible date
  TextMetrics { id: notifM; font.pixelSize: 11; text: Notifs.summary }
  readonly property real timeW: timeM.advanceWidth
  readonly property real dateW: dateM.advanceWidth
  readonly property real baseW: baseRow.implicitWidth
  readonly property real extraW: notifM.advanceWidth + 3 * Theme.iconMd + 4 * iconGap
  readonly property real wsW: ws.implicitWidth
  readonly property real minTitle: 120

  function halfFor(hover) {
    var left = timeW / 2 + gap + (hover ? Math.max(wsW, minTitle) : wsW)
    var right = timeW / 2 + (hover ? Theme.s8 + dateW : 0) + gap + baseW + (hover ? extraW + iconGap : 0)
    return pad + Math.max(left, right)
  }
  function widthFor(hover) { return Math.ceil(2 * halfFor(hover)) }
  // Room for the window title on the left of the clock.
  readonly property real titleMax: width / 2 - pad - timeW / 2 - gap

  SystemClock { id: clock; precision: SystemClock.Minutes }

  // ---------------- left: workspaces (+ window title when expanded) ----------------
  Column {
    id: left
    anchors.left: parent.left; anchors.leftMargin: form.pad
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2
    Text {
      visible: form.expanded
      width: Math.max(0, Math.min(form.titleMax, implicitWidth))
      elide: Text.ElideRight; textFormat: Text.PlainText       // window titles are untrusted text
      readonly property bool has: ToplevelManager.activeToplevel !== null && ToplevelManager.activeToplevel !== undefined
      text: has ? ToplevelManager.activeToplevel.title : "No focused window"
      color: has ? Theme.text : Theme.textMuted               // muted when nothing is focused
      font.pixelSize: 11
    }
    Workspaces { id: ws }
  }

  // ---------------- centre: time (fixed at the centre) + date (hover only) ----------------
  Text {
    id: timeText
    objectName: "clockText"
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: Qt.formatDateTime(clock.date, "HH:mm")
    color: Theme.text; font.pixelSize: 12; font.bold: true
    TapHandler { onTapped: IslandState.toggleWidget("calendar", form.win ? form.win.screenName : "") }
  }
  Text {
    objectName: "dateText"
    anchors.left: timeText.right; anchors.leftMargin: Theme.s8
    anchors.verticalCenter: parent.verticalCenter
    opacity: form.expanded ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 140 } }
    textFormat: Text.PlainText
    text: Qt.formatDateTime(clock.date, "ddd, MMM d")
    color: Theme.textMuted; font.pixelSize: 12
  }

  // ---------------- right: [hover extras] [indicators, Wi-Fi, battery] ----------------
  Row {
    id: right
    anchors.right: parent.right; anchors.rightMargin: form.pad
    anchors.verticalCenter: parent.verticalCenter
    spacing: form.iconGap

    // hover-only: notification summary + bell, volume, brightness
    Row {
      visible: form.expanded
      spacing: form.iconGap
      anchors.verticalCenter: parent.verticalCenter
      Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
        text: Notifs.summary; color: Theme.textMuted; font.pixelSize: 11 }
      BarIcon { anchors.verticalCenter: parent.verticalCenter
        onClicked: IslandState.toggleWidget("notifications", form.win ? form.win.screenName : "")
        Icon { name: Indicators.dnd ? "bell-off" : "bell"; size: Theme.iconMd; color: Notifs.liveCount > 0 ? Theme.text : Theme.textMuted } }
      // volume: scroll adjusts, middle-click mutes, click opens Audio
      BarIcon { anchors.verticalCenter: parent.verticalCenter; visible: Audio.hasSink
        onScrolled: function (d) { Audio.setVolume(Audio.volume + d * 0.03); IslandState.showHud("volume", Math.round(Audio.volume * 100), "", 0) }
        onMiddleClicked: Audio.toggleMute()
        onClicked: IslandState.toggleWidget("audio", form.win ? form.win.screenName : "")
        onRightClicked: IslandState.toggleWidget("audio", form.win ? form.win.screenName : "")
        VolumeIcon { level: Audio.volume; muted: Audio.muted; size: Theme.iconMd; color: Theme.text } }
      // brightness: scroll adjusts
      BarIcon { anchors.verticalCenter: parent.verticalCenter; visible: Brightness.available
        onScrolled: function (d) { Brightness.set(Brightness.level + d * 0.05); IslandState.showHud("brightness", Math.round(Brightness.level * 100), "", 0) }
        onClicked: IslandState.toggleWidget("display", form.win ? form.win.screenName : "")
        onRightClicked: IslandState.toggleWidget("display", form.win ? form.win.screenName : "")
        Icon { name: "sun"; size: Theme.iconMd } }
    }

    // always: active indicators (only while on), Wi-Fi, battery
    Row {
      id: baseRow
      spacing: form.iconGap
      anchors.verticalCenter: parent.verticalCenter
      BarIcon {                                // screen recording with a ticking timer
        visible: Indicators.recording; anchors.verticalCenter: parent.verticalCenter
        onClicked: Cmd.run(["omarchy-capture-screenrecording", "--stop-recording"])
        Row { spacing: 4
          Icon { name: "record"; size: Theme.iconSm; color: Theme.dangerInk; anchors.verticalCenter: parent.verticalCenter }
          Text { id: recText; textFormat: Text.PlainText; color: Theme.dangerInk; font.pixelSize: 11; font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            property real startedAt: Date.now() - Indicators.recSeconds * 1000
            property int elapsed: 0
            text: Math.floor(elapsed / 60) + ":" + ("0" + elapsed % 60).slice(-2)
            Timer { interval: 1000; repeat: true; running: Indicators.recording; triggeredOnStart: true      // exists only while recording
              onTriggered: recText.elapsed = Math.max(0, Math.floor((Date.now() - recText.startedAt) / 1000)) } } }
      }
      BarIcon { visible: Indicators.dictationAvailable && Indicators.dictation !== "idle"; anchors.verticalCenter: parent.verticalCenter
        onClicked: Indicators.toggleDictation(); Icon { name: "mic-dictate"; size: Theme.iconMd; color: Theme.warningInk } }
      BarIcon { visible: Indicators.dnd && !form.expanded; anchors.verticalCenter: parent.verticalCenter
        onClicked: Indicators.toggleDnd(); Icon { name: "bell-off"; size: Theme.iconMd; color: Theme.textMuted } }
      BarIcon { visible: Indicators.nightLight; anchors.verticalCenter: parent.verticalCenter
        onClicked: Indicators.toggleNightLight(); Icon { name: "moon"; size: Theme.iconMd; color: Theme.warningInk } }
      BarIcon { visible: Indicators.stayAwake; anchors.verticalCenter: parent.verticalCenter
        onClicked: Indicators.toggleStayAwake(); Icon { name: "coffee"; size: Theme.iconMd; color: Theme.textMuted } }
      BarIcon { visible: Indicators.updateAvailable; anchors.verticalCenter: parent.verticalCenter
        onClicked: Cmd.run(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"])
        Icon { name: "download"; size: Theme.iconMd; color: Theme.accentInk } }
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

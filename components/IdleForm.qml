import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import ".."
import "../services"

// Unified idle notch: [ workspaces | clock (+ cava visualizer) | battery % ].
// All compartments live inside the single centre pill so there are no detached
// side capsules; widthFor() is read by Island.qml to size the docked notch.
Item {
  id: form
  property var win: null                  // the PanelWindow (for screen name + widget toggling)

  readonly property int edgePad: 16       // clears the bottom 13 px corner radius
  readonly property int divGap: 10
  readonly property int divRoom: 2 * divGap + 1

  TextMetrics { id: timeM; font.family: Theme.monoFamily; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel; text: "00:00" }
  readonly property real timeW: timeM.advanceWidth

  readonly property bool playing: Quickshell.env("ISLAND_FORCE_VIZ") === "1" || Mpris.players.values.some(function (p) { return p.isPlaying })
  readonly property real vizRoom: 29      // along-bar room the bars need: 3 px edge + 18 px of bars + an 8 px gap to the time
  property real vizWidth: playing ? vizRoom : 0
  property real vizEdge: playing ? 3 : -5
  Behavior on vizWidth { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }
  Behavior on vizEdge { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

  readonly property bool hasRight: Power.present || Indicators.recording
  readonly property real leftW: wsView.implicitWidth
  readonly property real rightW: hasRight ? rightRow.implicitWidth : 0
  readonly property real wingW: hasRight ? Math.max(leftW, rightW) : leftW

  function widthFor() {
    var cw = timeW + (playing ? vizRoom : 0)
    if (hasRight) return Math.ceil(2 * edgePad + 2 * wingW + 2 * divRoom + cw)
    return Math.ceil(2 * edgePad + leftW + divRoom + cw)
  }

  readonly property real centerW: timeW + vizWidth
  readonly property real centerX: hasRight ? form.width / 2 : (edgePad + leftW + divRoom + centerW / 2)

  SystemClock { id: clock; precision: SystemClock.Minutes }

  // ---- spectrum: 5 bands, only while playing and this form is showing ----
  property var spectrum: [0, 0, 0, 0, 0]
  Process {
    running: form.playing && form.visible
    command: ["cava", "-p", Qt.resolvedUrl("../assets/viz-bar.conf").toString().replace("file://", "")]
    stdout: SplitParser {
      onRead: function (line) { form.spectrum = line.split(";").slice(0, 5).map(function (v) { return Math.max(0, Math.min(1000, Number(v) || 0)) }) }
    }
    onRunningChanged: if (!running) form.spectrum = [0, 0, 0, 0, 0]
  }

  // ---- left wing: workspaces ----
  Item {
    id: leftWing
    x: form.edgePad
    width: form.wingW
    height: parent.height
    MouseArea {
      z: -1; anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: Cmd.run(["omarchy-shell", "-q", "io.github.aicyraa.workspace-gallery.perspective", "toggle"])
    }
    Workspaces { id: wsView; anchors.centerIn: parent }
  }

  // Left hairline divider
  SmoothRect {
    x: Math.round(form.centerX - form.centerW / 2 - form.divGap - 1)
    anchors.verticalCenter: parent.verticalCenter
    width: 1; height: 10; radius: 0.5
    color: Theme.pillBorder
  }

  // ---- centre: clock (+ optional cava bars) ----
  Label {
    id: timeText
    objectName: "clockText"
    x: Math.round(form.centerX - width / 2 + form.vizWidth / 2)
    anchors.verticalCenter: parent.verticalCenter
    mono: true
    text: Qt.formatDateTime(clock.date, "HH:mm")
    color: Theme.text; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel
    TapHandler { onTapped: IslandState.toggleWidget("calendar", form.win ? form.win.screenName : "") }
  }

  Grid {
    id: bars
    visible: opacity > 0.001
    opacity: form.playing ? 1 : 0
    scale: form.playing ? 1 : 0.65
    transformOrigin: Item.Center
    x: timeText.x - form.vizWidth + form.vizEdge
    anchors.verticalCenter: parent.verticalCenter
    columns: 5; spacing: 2
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on scale { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Repeater {
      model: 5
      Item {
        required property int index
        readonly property real level: Math.max(2, 12 * Math.sqrt((form.spectrum[index] || 0) / 1000))
        width: 2; height: 12
        Rectangle {
          anchors.centerIn: parent; width: 2; height: parent.level; radius: 1; color: Theme.text
          Behavior on height { NumberAnimation { duration: 65; easing.type: Easing.OutQuad } }
        }
      }
    }
  }

  // Right hairline divider
  SmoothRect {
    visible: form.hasRight
    x: Math.round(form.centerX + form.centerW / 2 + form.divGap)
    anchors.verticalCenter: parent.verticalCenter
    width: 1; height: 10; radius: 0.5
    color: Theme.pillBorder
  }

  // ---- right wing: recording indicator + battery % ----
  Item {
    id: rightWing
    visible: form.hasRight
    x: Math.round(form.width - form.edgePad - width)
    width: form.wingW
    height: parent.height

    Row {
      id: rightRow
      anchors.centerIn: parent
      spacing: 6

      // Screen recording indicator: pulsing red dot; click stops recording.
      Item {
        visible: Indicators.recording
        width: 12; height: rightWing.height
        anchors.verticalCenter: parent.verticalCenter
        SmoothRect {
          anchors.centerIn: parent
          width: 8; height: 8; radius: 4; color: Theme.dangerInk
          SequentialAnimation on opacity {
            running: Indicators.recording; loops: Animation.Infinite
            NumberAnimation { to: 0.55; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 800; easing.type: Easing.InOutSine }
          }
        }
        MouseArea {
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: Cmd.run(["omarchy-capture-screenrecording", "--stop-recording"])
        }
      }

      // Battery icon + percentage
      Item {
        visible: Power.present
        width: batContent.implicitWidth + 8; height: rightWing.height
        anchors.verticalCenter: parent.verticalCenter
        SmoothRect {
          anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: 3; radius: height / 2
          color: Theme.text
          opacity: batArea.containsMouse ? 0.14 : 0
          Behavior on opacity { NumberAnimation { duration: 120 } }
        }
        Row {
          id: batContent
          anchors.centerIn: parent
          spacing: 4
          BatteryIcon { size: 20; anchors.verticalCenter: parent.verticalCenter }
          Label {
            mono: true
            text: Math.round(Power.level * 100) + "%"
            color: Power.low ? Theme.dangerInk : (Power.charging ? Theme.successInk : Theme.textMuted)
            font.pixelSize: 10
            font.weight: Theme.weightLabel
            verticalAlignment: Text.AlignVCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
          }
        }
        MouseArea {
          id: batArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: IslandState.toggleWidget("battery", form.win ? form.win.screenName : "")
        }
      }
    }
  }
}

import QtQuick
import Quickshell
import ".."
import "../services"
import "../menu-core/MenuModel.js" as MenuModel

// Menu: Omarchy's menu inside the island, laid out like Compass. A search box on top with the item count; an icon rail
// on the left (Home, then the top-level categories); the rows of the chosen category on the right. Home shows Recent
// (the most used apps and actions), Toggles (night light, stay awake, notifications) and About.
// The rail and the search stay where they are: only the list scrolls, and its highlight moves quickly.
// Keys: type to search · ↑/↓ move · Enter or → open or run · ← or Backspace up · Tab rail · Esc up, then close.
// Install rows for software that is already installed are hidden (Omarchy's `disabled:` checks, via MenuData).
// Running an action closes the widget first (as Power does).
WidgetPanel {
  id: root
  preferredWidth: 520
  pad: 8                                  // a tighter edge: the rail and the list sit close to the panel edges
  hint: "type to search · ↑/↓ move · Enter open or run · ←/Backspace up · Tab rail · Esc up or close"

  // The fixed body. Search (30) + section gap (12) + body (340) + padding (2 x 16) is 398, within the 420 px panel
  // limit, so the panel itself never scrolls: only the list does, and only when its rows overflow.
  readonly property int bodyH: 340
  readonly property int railW: 44
  readonly property string glyphFamily: "JetBrainsMono Nerd Font"
  readonly property string homeGlyph: "󰋜"

  property string route: "root"           // the menu being shown; "root" = a rail category (or Home)
  property string railId: "home"          // with route "root": the rail item whose rows are shown
  property bool railFocus: false          // Tab moves the selection into the rail
  property string query: ""
  property int sel: 0

  // A dmenu request (from Omarchy's scripts): a list to pick from (select) or a line to type (input). Its answer goes back
  // through MenuData.finishRequest; leaving the widget any other way cancels it (see onDestruction).
  readonly property bool dmenu: MenuData.request.active === true
  readonly property bool dmenuInput: dmenu && MenuData.request.mode === "input"
  readonly property string dmenuPrompt: dmenu ? String(MenuData.request.prompt || "") : ""

  // Esc leaves the search, then the rail, then goes up, before it closes the widget; Island checks this flag.
  readonly property bool capturesEscape: dmenu ? query !== "" : (query !== "" || route !== "root" || railFocus)

  // Rail: Home, then the top-level categories of the tree.
  readonly property var railRows: {
    MenuData.revision
    return [{ id: "home", label: "Home", icon: homeGlyph, kind: "home" }].concat(MenuData.childrenOf("root"))
  }
  readonly property int railItemH: Math.max(24, Math.min(40, Math.floor((bodyH - (railRows.length - 1) * 2) / Math.max(1, railRows.length))))
  readonly property string highlightedRail: route === "root" ? railId : MenuModel.topLevelFor(MenuData.items, route)

  // The rows. Toggles are re-read when their state changes, so the checks follow the switch.
  readonly property var rows: {
    MenuData.revision
    Indicators.nightLight; Indicators.stayAwake; Indicators.dnd
    if (dmenu) return dmenuRows()
    if (query !== "") return MenuData.search(query, 60)
    if (route === "root" && railId === "home") return homeRows()
    return MenuData.childrenOf(route === "root" ? railId : route)
  }

  function homeRows() {
    var out = []
    var recent = MenuData.recentRows()
    for (var i = 0; i < recent.length; i++) out.push(withSection(recent[i], "Recent"))
    out.push(toggleRow("toggle.nightlight", "Night light", "moon", Indicators.nightLight, "Toggles"))
    out.push(toggleRow("toggle.stayawake", "Stay awake", "coffee", Indicators.stayAwake, ""))
    out.push(toggleRow("toggle.notifications", "Notifications", Indicators.dnd ? "bell-off" : "bell", !Indicators.dnd, ""))
    var about = MenuData.item("about")
    if (about && MenuData.visible(about)) out.push(withSection(about, "divider"))
    return out
  }
  function withSection(entry, section) {
    var o = {}
    for (var k in entry) o[k] = entry[k]
    o.section = section
    return o
  }
  function toggleRow(id, label, icon, on, section) {
    return { id: id, kind: "toggle", label: label, icon: icon, checked: on, section: section, description: on ? "On" : "Off" }
  }
  function runToggle(id) {
    if (id === "toggle.nightlight") Indicators.toggleNightLight()
    else if (id === "toggle.stayawake") Indicators.toggleStayAwake()
    else if (id === "toggle.notifications") Indicators.toggleDnd()
  }

  // dmenu options are "<glyph>\t<label>\t<detail>" (glyph and detail optional); the answer is "<label>" or "<label>\t<detail>".
  function dmenuRows() {
    if (dmenuInput) return []
    var out = []
    var q = query.trim().toLowerCase()
    var options = MenuData.request.options || []
    for (var i = 0; i < options.length; i++) {
      var parts = String(options[i] || "").split("\t")
      var icon = parts.length > 1 ? parts.shift() : ""
      var label = parts.shift() || ""
      var detail = parts.join("\t")
      if (q && label.toLowerCase().indexOf(q) < 0 && detail.toLowerCase().indexOf(q) < 0) continue
      out.push({ id: "dmenu." + i, kind: "dmenu", label: label, icon: icon, description: detail,
                 answer: detail ? label + "\t" + detail : label, section: "" })
    }
    return out
  }

  // Apply the request or the route this menu was opened for (also when it is already open and gets a new one).
  function applyOpen() {
    query = ""; sel = 0; railFocus = false
    root.forceActiveFocus()
    if (dmenu) { route = "root"; return }
    route = MenuData.pendingRoute || "root"
    if (route === "root") railId = "home"
    else railId = MenuModel.topLevelFor(MenuData.items, route)
  }
  Connections { target: MenuData; function onOpenSerialChanged() { root.applyOpen() } }
  Component.onCompleted: { MenuData.refresh(); applyOpen() }
  // Leaving by any path other than a choice cancels the request (a script waiting on it must not hang).
  Component.onDestruction: MenuData.cancelRequest()
  readonly property var debugState: ({ route: route, railId: railId, query: query, sel: sel, rows: rows.length, railFocus: railFocus })

  function navigable(e) { return !!e && (e.kind === "menu" || e.kind === "link" || e.provider !== "") }
  function enter(id) { route = id; sel = 0; query = ""; railFocus = false }
  function up() {
    var cur = MenuData.item(route)
    if (!cur) { route = "root"; sel = 0; return }
    if (cur.parent === "root") railId = cur.id
    route = cur.parent || "root"; sel = 0
  }
  function selectRail(id) {
    query = ""; sel = 0
    route = "root"; railId = id
  }
  function moveRail(delta) {
    var ids = railRows
    var at = 0
    for (var i = 0; i < ids.length; i++) if (ids[i].id === highlightedRail) at = i
    var next = Math.max(0, Math.min(ids.length - 1, at + delta))
    selectRail(ids[next].id)
  }

  // A dmenu choice: input mode answers with the typed text, select mode with the chosen row.
  function accept(e) {
    if (dmenuInput) { MenuData.finishRequest(query); IslandState.closeWidget(); return }
    if (!e) return
    MenuData.finishRequest(e.answer !== undefined ? e.answer : e.label)
    IslandState.closeWidget()
  }
  function open(e) {
    if (!e) return
    if (dmenu) { accept(e); return }
    if (e.kind === "toggle") { runToggle(e.id); return }
    if (navigable(e)) {
      if (e.kind === "link" && e.target) enter(e.target)
      else enter(e.id)
      return
    }
    IslandState.closeWidget()
    MenuData.activate(e)
  }
  function trailingFor(e) {
    if (e.kind === "toggle") return ""
    var tag = MenuModel.tagFor(e.id)
    if (tag !== "") return tag
    return navigable(e) ? "›" : ""
  }

  Keys.onPressed: function (e) {
    var n = rows.length
    if (dmenu) {
      if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, Math.max(0, n - 1)); e.accepted = true }
      else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
      else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
        if (dmenuInput) accept(null); else if (rows[sel]) accept(rows[sel]); e.accepted = true }
      else if (e.key === Qt.Key_Backspace) { if (query !== "") { query = query.slice(0, -1); sel = 0 } e.accepted = true }
      else if (e.key === Qt.Key_Escape) { if (query !== "") { query = ""; sel = 0; e.accepted = true } }
      else if (e.text.length === 1 && e.text >= " ") { query += e.text; sel = 0; e.accepted = true }
      return
    }
    if (railFocus) {
      if (e.key === Qt.Key_Up) { moveRail(-1); e.accepted = true }
      else if (e.key === Qt.Key_Down) { moveRail(1); e.accepted = true }
      else if (e.key === Qt.Key_Right || e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Tab) { railFocus = false; e.accepted = true }
      else if (e.key === Qt.Key_Escape) { railFocus = false; e.accepted = true }
      return
    }
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, Math.max(0, n - 1)); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (rows[sel]) open(rows[sel]); e.accepted = true }
    else if (e.key === Qt.Key_Right) { if (rows[sel] && (navigable(rows[sel]) || rows[sel].kind === "toggle")) open(rows[sel]); e.accepted = true }
    else if (e.key === Qt.Key_Tab) { railFocus = true; e.accepted = true }
    else if (e.key === Qt.Key_Delete) {
      var r = rows[sel]
      if (r && r.section === "Recent" && query === "") { MenuData.forgetRecent(r.id); sel = Math.max(0, Math.min(sel, rows.length - 2)) }
      e.accepted = true
    }
    else if (e.key === Qt.Key_Left) { if (route !== "root" && query === "") up(); else railFocus = true; e.accepted = true }
    else if (e.key === Qt.Key_Backspace) {
      if (query !== "") { query = query.slice(0, -1); sel = 0 } else if (route !== "root") up()
      e.accepted = true
    }
    else if (e.key === Qt.Key_Escape) {
      if (query !== "") { query = ""; sel = 0; e.accepted = true }
      else if (route !== "root") { up(); e.accepted = true }
    }
    else if (e.text.length === 1 && e.text >= " ") { query += e.text; sel = 0; e.accepted = true }
  }

  // ---- search row: the back button (in a submenu), the search box, the item count ----
  Item { width: parent.width; height: 30
    Rectangle {
      id: back
      visible: !root.dmenu && root.route !== "root" && root.query === ""
      width: 30; height: 30; radius: 15; color: backArea.containsMouse ? Theme.mix(Theme.surface, Theme.text, 0.12) : Theme.surface
      Icon { anchors.centerIn: parent; name: "chevron-left"; size: Theme.iconSm }
      MouseArea { id: backArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.up() }
    }
    Rectangle {
      id: searchBox
      anchors.left: parent.left; anchors.right: count.left; anchors.rightMargin: Theme.s8
      anchors.leftMargin: back.visible ? 38 : 0
      height: 30; radius: 15
      color: root.query !== "" ? Theme.mix(Theme.surface, Theme.text, 0.08) : Theme.surface
      Icon { id: searchIcon; x: Theme.s12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: Theme.iconSm; color: Theme.textMuted }
      Text { x: Theme.s12 + Theme.iconSm + Theme.s8; width: parent.width - x - Theme.s12; anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight; textFormat: Text.PlainText
        text: root.query !== "" ? root.query : (root.dmenu && root.dmenuPrompt !== "" ? root.dmenuPrompt : "Search…")
        color: root.query === "" ? Theme.textMuted : Theme.text; font.pixelSize: 12; font.weight: root.query === "" ? Font.Normal : Theme.weightLabel }
    }
    Text { id: count; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
      text: root.dmenu ? "" : (root.rows.length + (root.rows.length === 1 ? " item" : " items"))
      color: Theme.textMuted; font.pixelSize: 11 }
  }

  // ---- body: rail (fixed) + list (scrolls on its own) ----
  Item {
    width: parent.width; height: root.bodyH
    // The rail is a square container; its items are square too, so the whole column reads as one block.
    Rectangle {
      id: rail
      visible: !root.dmenu
      width: root.railW; height: root.bodyH; color: Theme.surface; radius: 16
      Column {
      anchors.fill: parent; spacing: 2
      Repeater {
        model: root.railRows
        delegate: Item {
          id: railItem
          required property var modelData
          required property int index
          readonly property bool active: modelData.id === root.highlightedRail
          width: rail.width; height: root.railItemH
          // A square, rounded icon box, centred in its row of the rail.
          Rectangle {
            width: Math.min(root.railItemH, root.railW - 8); height: width
            anchors.centerIn: parent
            radius: 10
            color: railItem.active ? Theme.surfaceRaised : (railArea.containsMouse ? Theme.mix(Theme.surface, Theme.text, 0.06) : "transparent")
            Behavior on color { ColorAnimation { duration: 90 } }
            FocusRing { on: root.railFocus && railItem.active; radius: 10 }
          }
          Item {
            anchors.centerIn: parent; width: 18; height: 18
            Image { visible: railItem.modelData.kind === "app"; anchors.fill: parent; sourceSize: Qt.size(36, 36)
              asynchronous: true; smooth: true; mipmap: true
              source: railItem.modelData.kind === "app" && railItem.modelData.icon ? (Quickshell.iconPath(railItem.modelData.icon, true) || "") : "" }
            Text { visible: railItem.modelData.kind !== "app"; anchors.fill: parent; horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter; textFormat: Text.PlainText
              text: railItem.modelData.icon || ""; color: railItem.active ? Theme.text : Theme.textMuted
              font.family: root.glyphFamily; font.pixelSize: 15 }
          }
          MouseArea { id: railArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { root.railFocus = false; root.selectRail(modelData.id) } }
        }
      }
      }
    }

    ListView {
      id: list
      x: root.dmenu ? 0 : root.railW + Theme.s12
      width: parent.width - x
      height: root.bodyH
      clip: true
      model: root.rows
      currentIndex: root.sel
      interactive: contentHeight > height
      boundsBehavior: Flickable.StopAtBounds
      // One highlight, moved quickly to the selected row (no delay, no panel-wide scroll).
      highlightFollowsCurrentItem: true
      highlightMoveDuration: IslandState.reducedMotion ? 0 : 110
      highlight: Rectangle { radius: 12; color: root.railFocus ? "transparent" : Theme.surfaceRaised }
      onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
      // A thin indicator, shown only while the rows run past the body.
      Rectangle {
        visible: list.contentHeight > list.height + 1
        anchors.right: parent.right; anchors.rightMargin: 2
        width: 3; radius: 2; color: Theme.mix(Theme.surface, Theme.text, 0.35)
        height: Math.max(24, list.height * list.height / list.contentHeight)
        y: (list.height - height) * (list.contentY / Math.max(1, list.contentHeight - list.height))
      }
      section.property: "section"
      section.criteria: ViewSection.FullString
      section.delegate: Item {
        required property string section
        width: list.width
        height: section === "" ? 0 : (section === "divider" ? 12 : 26)
        Rectangle { visible: section === "divider"; x: Theme.s8; width: parent.width - 2 * Theme.s8; height: 1
          anchors.verticalCenter: parent.verticalCenter; color: Theme.mix(Theme.surface, Theme.text, 0.14) }
        Text { visible: section !== "" && section !== "divider"; x: Theme.s8; anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText; text: section; color: Theme.textMuted; font.pixelSize: 11; font.weight: Theme.weightLabel }
      }
      delegate: Item {
        id: rowItem
        required property var modelData
        required property int index
        width: list.width; height: 38
        MouseArea { anchors.fill: parent; hoverEnabled: true
          onEntered: if (!root.railFocus) root.sel = index
          onClicked: { root.railFocus = false; root.sel = index; root.open(rowItem.modelData) } }
        Item {
          id: lead
          x: Theme.s8 + 4; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20
          Image { visible: rowItem.modelData.kind === "app"; anchors.fill: parent; sourceSize: Qt.size(40, 40)
            asynchronous: true; smooth: true; mipmap: true
            source: rowItem.modelData.kind === "app" && rowItem.modelData.icon ? (Quickshell.iconPath(rowItem.modelData.icon, true) || "") : "" }
          Icon { visible: rowItem.modelData.kind === "toggle"; anchors.centerIn: parent; size: Theme.iconSm
            name: rowItem.modelData.icon || ""; color: index === root.sel ? Theme.text : Theme.textMuted }
          Text { visible: rowItem.modelData.kind !== "app" && rowItem.modelData.kind !== "toggle"; anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; textFormat: Text.PlainText
            text: rowItem.modelData.icon || ""; color: index === root.sel ? Theme.text : Theme.textMuted
            font.family: root.glyphFamily; font.pixelSize: 15 }
        }
        Column {
          x: lead.x + 20 + Theme.s12; anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x - 96
          Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
            text: rowItem.modelData.label || ""; color: Theme.text; font.pixelSize: 13; font.weight: Theme.weightLabel }
          Text { visible: text !== ""; width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
            text: rowItem.modelData.description || ""; color: Theme.textMuted; font.pixelSize: 11 }
        }
        Row {
          anchors.right: parent.right; anchors.rightMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
          Icon { visible: rowItem.modelData.checked === true; anchors.verticalCenter: parent.verticalCenter; size: Theme.iconSm
            name: "check"; color: Theme.text; strokeWidth: 2 }
          Text { visible: text !== ""; textFormat: Text.PlainText; text: root.trailingFor(rowItem.modelData)
            color: Theme.textMuted; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
        }
      }
      Text { anchors.centerIn: parent; visible: list.count === 0; textFormat: Text.PlainText
        text: root.query !== "" ? "No match" : "Nothing here"; color: Theme.textMuted; font.pixelSize: 13 }
    }
  }
}

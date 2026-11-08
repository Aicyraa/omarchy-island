import QtQuick
import Quickshell
import ".."
import "../services"
import "../menu-core/MenuModel.js" as MenuModel

// Menu: Omarchy's menu inside the island. A category rail on the left, the chosen category's rows on the right, a
// breadcrumb and a search box on top. Typing searches every row; Enter (or Right) opens a submenu or runs an action;
// Backspace / Left / Esc go up one level, and Esc closes the widget from the top level.
// Install rows for software that is already installed are hidden (Omarchy's own `disabled:` checks, via MenuData).
// The tree and its checks come from MenuData; running an action closes the widget first (as Power does).
WidgetPanel {
  id: root
  preferredWidth: 720
  hint: "type to search · ↑/↓ move · Enter open or run · ←/Backspace up · Esc up or close"

  property string route: "root"          // the menu being shown; "root" = the top level
  property string railId: "apps"         // with route "root": the rail category whose rows are previewed
  property string query: ""
  property int sel: 0
  readonly property string glyphFamily: "JetBrainsMono Nerd Font"

  // A dmenu request (from Omarchy's scripts): a list to pick from (select) or a line to type (input). Its answer goes back
  // through MenuData.finishRequest; leaving the widget any other way cancels it (see onDestruction).
  readonly property bool dmenu: MenuData.request.active === true
  readonly property bool dmenuInput: dmenu && MenuData.request.mode === "input"
  readonly property string dmenuPrompt: dmenu ? String(MenuData.request.prompt || "") : ""

  // Esc goes up (or clears the search) before it closes the widget; Island checks this flag.
  readonly property bool capturesEscape: dmenu ? query !== "" : (query !== "" || route !== "root")

  readonly property var railRows: { MenuData.revision; return MenuData.childrenOf("root") }
  readonly property var crumbs: { MenuData.revision; return route === "root" ? [] : MenuModel.crumbsFor(MenuData.items, route) }
  readonly property string highlightedRail: route === "root" ? railId : MenuModel.topLevelFor(MenuData.items, route)
  readonly property var rows: {
    MenuData.revision
    if (dmenu) return dmenuRows()
    if (query !== "") return MenuData.search(query, 60)
    return MenuData.childrenOf(route === "root" ? railId : route)
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
                 answer: detail ? label + "\t" + detail : label })
    }
    return out
  }

  // Apply the request or the route this menu was opened for (also when it is already open and gets a new one).
  function applyOpen() {
    query = ""; sel = 0
    if (dmenu) { route = "root"; return }
    route = MenuData.pendingRoute || "root"
    if (route !== "root") railId = MenuModel.topLevelFor(MenuData.items, route)
  }
  Connections { target: MenuData; function onOpenSerialChanged() { root.applyOpen() } }
  Component.onCompleted: { MenuData.refresh(); applyOpen() }
  // Leaving by any path other than a choice cancels the request (a script waiting on it must not hang).
  Component.onDestruction: MenuData.cancelRequest()
  readonly property var debugState: ({ route: route, query: query, sel: sel, rows: rows.length, rail: highlightedRail,
    apps: Object.keys(MenuData.items).filter(function (k) { return MenuData.items[k].kind === "app" }).length,
    appsChildren: MenuData.itemOrder.filter(function (k) { return MenuData.items[k] && MenuData.items[k].parent === "apps" }).length,
    appsVisible: MenuData.childrenOf("apps").length, desktop: MenuData.desktopCount,
    installService: MenuData.childrenOf("install.service").length, guardsDisabled: Object.keys(MenuData.disabledResults).length, guardsWhen: Object.keys(MenuData.whenResults).length, guardsRunning: MenuData.guardsRunning, installBrowser: MenuData.childrenOf("install.browser").length })

  function navigable(e) { return !!e && (e.kind === "menu" || e.kind === "link" || e.provider !== "") }
  function enter(id) { route = id; sel = 0; query = "" }
  function up() {
    var cur = MenuData.item(route)
    if (!cur) { route = "root"; sel = 0; return }
    if (cur.parent === "root") railId = cur.id
    route = cur.parent || "root"; sel = 0
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
    if (navigable(e)) {
      if (e.kind === "link" && e.target) enter(e.target)
      else enter(e.id)
      return
    }
    IslandState.closeWidget()
    MenuData.activate(e)
  }
  function trailingFor(e) {
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
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, Math.max(0, n - 1)); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (rows[sel]) open(rows[sel]); e.accepted = true }
    else if (e.key === Qt.Key_Right) { if (rows[sel] && navigable(rows[sel])) open(rows[sel]); e.accepted = true }
    else if (e.key === Qt.Key_Left) { if (route !== "root" && query === "") up(); e.accepted = true }
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

  // ---- header: search on the left, the breadcrumb on the right ----
  Item { width: parent.width; height: 28
    Rectangle {
      antialiasing: true
      anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
      height: 28; width: 260; radius: 14
      color: root.query !== "" ? Theme.mix(Theme.surface, Theme.text, 0.08) : Theme.surface
      Icon { id: searchIcon; x: Theme.s12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: Theme.iconSm; color: Theme.textMuted }
      Text { x: Theme.s12 + Theme.iconSm + Theme.s8; width: parent.width - x - Theme.s12; anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight; textFormat: Text.PlainText
        text: root.query === "" ? (root.dmenu && root.dmenuPrompt !== "" ? root.dmenuPrompt : "Search menu…") : root.query
        color: root.query === "" ? Theme.textMuted : Theme.text; font.pixelSize: 12; font.weight: root.query === "" ? Font.Normal : Theme.weightLabel }
    }
    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 280; horizontalAlignment: Text.AlignRight
      elide: Text.ElideLeft; textFormat: Text.PlainText
      text: root.dmenu ? root.dmenuPrompt
            : root.query !== "" ? root.rows.length + " results"
            : (root.crumbs.length === 0 ? "Menu" : root.crumbs.map(function (c) { return c.label }).join("  ›  "))
      color: Theme.textMuted; font.pixelSize: 12 }
  }

  // ---- body: rail + rows ----
  Row {
    width: parent.width; spacing: Theme.s12
    // category rail
    Column {
      id: rail
      visible: !root.dmenu
      width: 168; spacing: 2
      Repeater {
        model: root.railRows
        delegate: ListRow {
          required property var modelData
          required property int index
          width: rail.width
          title: modelData.label
          icon: ""
          active: modelData.id === root.highlightedRail
          leading: Component {
            Item {
              width: 20; height: 20
              Image { visible: modelData.kind === "app"; anchors.centerIn: parent; width: 20; height: 20; sourceSize: Qt.size(40, 40)
                asynchronous: true; smooth: true; mipmap: true
                source: modelData.kind === "app" && modelData.icon ? (Quickshell.iconPath(modelData.icon, true) || "") : "" }
              Text { visible: modelData.kind !== "app"; anchors.fill: parent; horizontalAlignment: Text.AlignHCenter; textFormat: Text.PlainText
                text: modelData.icon || ""; color: Theme.text; font.family: root.glyphFamily; font.pixelSize: 15 }
            }
          }
          onClicked: {
            root.query = ""
            if (root.route === "root") root.railId = modelData.id
            else root.enter(modelData.id)
          }
        }
      }
    }
    // rows
    Column {
      id: list
      width: root.dmenu ? parent.width : parent.width - rail.width - Theme.s12; spacing: Theme.rowGap
      Repeater {
        model: root.rows
        delegate: ListRow {
          id: row
          required property var modelData
          required property int index
          width: list.width
          title: modelData.label
          subtitle: modelData.description || ""
          trailing: modelData.kind === "dmenu" ? "" : root.trailingFor(modelData)
          selected: root.sel === index
          onSelectedChanged: if (selected) root.reveal(row)
          leading: Component {
            Item {
              width: 20; height: 20
              Image { visible: modelData.kind === "app"; anchors.centerIn: parent; width: 20; height: 20; sourceSize: Qt.size(40, 40)
                asynchronous: true; smooth: true; mipmap: true
                source: modelData.kind === "app" && modelData.icon ? (Quickshell.iconPath(modelData.icon, true) || "") : "" }
              Text { visible: modelData.kind !== "app"; anchors.fill: parent; horizontalAlignment: Text.AlignHCenter; textFormat: Text.PlainText
                text: modelData.icon || ""; color: (row.selected ? Theme.text : Theme.textMuted); font.family: root.glyphFamily; font.pixelSize: 15 }
            }
          }
          onClicked: { root.sel = index; root.open(modelData) }
        }
      }
      Text { visible: root.rows.length === 0; textFormat: Text.PlainText
        text: root.query !== "" ? "No match" : "Nothing here"; color: Theme.textMuted; font.pixelSize: 13 }
    }
  }
}

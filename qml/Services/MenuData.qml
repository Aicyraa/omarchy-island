pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../MenuCore/MenuModel.js" as MenuModel
import "../MenuCore/MenuHidden.js" as MenuHidden
import "../Core"

// MenuData: Omarchy's menu tree as the island's menu widget shows it.
//   * The tree: the stock jsonc, overridden by the user's extension, minus the sections the island replaces
//     (menu-core/MenuHidden.js). Read from disk on load and whenever either file changes.
//   * Installed apps: every desktop entry, as `apps.<id>` rows (kind "app"), launched through DesktopEntries.
//   * Guards: one read-only bash batch for every `when:`, `checked:` and `disabled:`; it runs when the tree loads and
//     each time the menu opens (Omarchy's own checks, so an installed app's Install row is hidden).
// Recents and frecency are not part of this milestone.
Singleton {
  id: root
  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  readonly property string userPath: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"

  property string stockText: ""
  property string userText: ""
  property var items: ({})
  property var itemOrder: []
  property var whenResults: ({})
  property var checkedResults: ({})
  property var disabledResults: ({})
  property int revision: 0
  readonly property bool guardsRunning: guards.running

  FileView { path: root.omarchyPath + "/default/omarchy/omarchy-menu.jsonc"; printErrors: false; watchChanges: true
    onFileChanged: reload()
    onLoaded: root.stockText = text()
    onLoadFailed: root.stockText = "" }
  FileView { path: root.userPath; printErrors: false; watchChanges: true
    onFileChanged: reload()
    onLoaded: root.userText = text()
    onLoadFailed: root.userText = "" }

  onStockTextChanged: rebuild()
  onUserTextChanged: rebuild()

  // Installed software changes the desktop entries; rebuild the app rows when they do (and on each open).
  readonly property int desktopCount: DesktopEntries.applications.values.length
  onDesktopCountChanged: rebuild()

  function rebuild() {
    var merged = MenuModel.mergeMenuSources(MenuModel.parseMenuJsonc(stockText), MenuModel.parseMenuJsonc(userText), MenuHidden.hide)
    var next = withApps(merged.items, merged.itemOrder)
    items = next.items
    itemOrder = next.itemOrder
    revision += 1
    refreshGuards()
  }

  // Installed apps are rebuilt from DesktopEntries each time (they change when software is installed or removed).
  function withApps(baseItems, baseOrder) {
    var out = ({})
    for (var k in baseItems) if (baseItems[k].kind !== "app") out[k] = baseItems[k]
    var order = []
    for (var i = 0; i < baseOrder.length; i++) if (out[baseOrder[i]]) order.push(baseOrder[i])
    var entries = DesktopEntries.applications.values
    var rows = []
    for (var j = 0; j < entries.length; j++) {
      var e = entries[j]
      if (!e || e.noDisplay || !e.name) continue
      rows.push(e)
    }
    rows.sort(function (a, b) { return String(a.name).localeCompare(String(b.name)) })
    for (var r = 0; r < rows.length; r++) {
      var id = "apps." + MenuModel.slugify(rows[r].id || rows[r].name)
      if (out[id]) id += "-" + r
      out[id] = { id: id, parent: "apps", kind: "app", icon: rows[r].icon || "", iconFont: "", label: rows[r].name,
                  title: "", target: "", description: rows[r].genericName || "", action: "", provider: "", aliases: [],
                  when: "", checked: "", disabled: "", order: r, desktop: rows[r] }
      order.push(id)
    }
    return { items: out, itemOrder: order }
  }

  // ---- guards: one read-only batch, results keyed by id ----
  function refreshGuards() {
    if (guards.running) { guardsPending = true; return }
    guardsPending = false
    var script = MenuModel.guardScript(items)
    if (!script) { whenResults = ({}); checkedResults = ({}); disabledResults = ({}); return }
    guards.command = ["bash", "-lc", script]
    guards.running = true
  }
  property bool guardsPending: false

  Process {
    id: guards
    stdout: StdioCollector {
      onStreamFinished: {
        var nextWhen = ({}), nextChecked = ({}), nextDisabled = ({})
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim()
          if (!line) continue
          var colon = line.lastIndexOf(":")
          if (colon < 0) continue
          var value = line.substring(colon + 1) === "1"
          var rest = line.substring(0, colon)
          var tagAt = rest.lastIndexOf(":")
          if (tagAt < 0) continue
          var id = rest.substring(0, tagAt), tag = rest.substring(tagAt + 1)
          if (tag === "w") nextWhen[id] = value
          else if (tag === "c") nextChecked[id] = value
          else if (tag === "d") nextDisabled[id] = value
        }
        root.whenResults = nextWhen
        root.checkedResults = nextChecked
        root.disabledResults = nextDisabled
        root.revision += 1
      }
    }
    onExited: function (code) { if (root.guardsPending) Qt.callLater(function () { root.refreshGuards() }) }
  }

  // Re-check everything (called when the menu opens). Cheap enough: one batch of read-only checks.
  function refresh() { rebuild(); bindsReader.running = true }

  // ---- shortcuts: Hyprland's binds, matched by their description ("Background switcher", "Screenshot") ----
  property var shortcuts: ({})          // lower-case description -> "Super Ctrl Space"
  Process {
    id: bindsReader
    command: ["hyprctl", "binds", "-j"]
    stdout: StdioCollector { onStreamFinished: {
      try {
        var binds = JSON.parse(String(text || "[]")), out = ({})
        for (var i = 0; i < binds.length; i++) {
          var d = String(binds[i].description || "").toLowerCase()
          if (d === "" || out[d] !== undefined) continue
          out[d] = root.shortcutText(binds[i].modmask, binds[i].key)
        }
        root.shortcuts = out
      } catch (e) {}
    } }
  }
  function shortcutText(mask, key) {
    var m = Number(mask) || 0, parts = []
    if (m & 64) parts.push("Super")
    if (m & 4) parts.push("Ctrl")
    if (m & 8) parts.push("Alt")
    if (m & 1) parts.push("Shift")
    var names = { SPACE: "Space", ESCAPE: "Esc", PRINT: "Print", RETURN: "Enter", TAB: "Tab" }
    var k = String(key || "").toUpperCase()
    parts.push(names[k] || (k.length === 1 ? k : k.charAt(0) + k.slice(1).toLowerCase()))
    return parts.join(" ")
  }
  function shortcutFor(entry) {
    if (!entry || entry.kind !== "action") return ""
    var label = String(entry.label || "").toLowerCase()
    if (label === "") return ""
    if (shortcuts[label] !== undefined) return shortcuts[label]
    for (var k in shortcuts) if (k.indexOf(label) === 0) return shortcuts[k]
    return ""
  }

  // ---- pins, the last category, and what the install check hid ----
  property var pins: []
  property string lastRail: "home"
  function togglePin(id) {
    pins = pins.indexOf(id) >= 0 ? pins.filter(function (p) { return p !== id }) : pins.concat([id])
    Cache.put("menu-pins", pins)
    revision += 1
  }
  function pinnedRows() {
    var out = []
    for (var i = 0; i < pins.length; i++) { var e = items[pins[i]]; if (e && visible(e)) out.push(e) }
    return out
  }
  function setLastRail(id) { lastRail = id; Cache.put("menu-last-rail", id) }
  function hiddenInstallCount() {
    var n = 0
    for (var k in disabledResults) if (disabledResults[k] && String(k).indexOf("install.") === 0) n++
    return n
  }
  // The rows under a category (any depth), ranked like the search.
  function underScope(entry, scope) {
    var p = entry.parent, guard = 0
    while (p && guard++ < 20) {
      if (p === scope) return true
      var pe = items[p]
      p = pe ? pe.parent : null
    }
    return false
  }
  function searchWithin(scope, query, limit) {
    var hits = []
    for (var i = 0; i < itemOrder.length; i++) {
      var e = items[itemOrder[i]]
      if (!e || !visible(e) || !underScope(e, scope)) continue
      if (!MenuModel.matchesQuery(e, query, true)) continue
      hits.push({ entry: e, score: MenuModel.searchScore(items, e, query) })
    }
    hits.sort(function (a, b) { return a.score - b.score })
    return hits.slice(0, limit || 60).map(function (h) { return h.entry })
  }
  Component.onCompleted: { rebuild(); loadUsage() }

  // ---- queries used by the widget ----
  function visible(entry) {
    return MenuModel.isVisible(items, itemOrder, whenResults, entry, 0, disabledResults)
  }
  function childrenOf(id) {
    var out = []
    for (var i = 0; i < itemOrder.length; i++) {
      var e = items[itemOrder[i]]
      if (e && e.parent === id && e.id !== id && visible(e)) out.push(e)
    }
    return out
  }
  function search(query, limit) {
    var hits = []
    for (var i = 0; i < itemOrder.length; i++) {
      var e = items[itemOrder[i]]
      if (!e || e.id === "root") continue
      if (!MenuModel.matchesQuery(e, query, visible(e))) continue
      hits.push({ entry: e, score: MenuModel.searchScore(items, e, query) })
    }
    hits.sort(function (a, b) { return a.score - b.score })
    return hits.slice(0, limit || 60).map(function (h) { return h.entry })
  }
  function item(id) { return items[id] || null }

  // ---- recents: frecency of the apps and actions run from the menu (the same ranking Compass used) ----
  // Kept in the island's Cache; the first start imports Compass's usage file once, so the recents carry over.
  property var usage: ({})
  property var recentIds: []
  readonly property int recentLimit: 8
  function setUsage(next) { usage = next || ({}); recentIds = MenuModel.topUsed(usage, recentLimit, Date.now()) }
  function remember(id) {
    setUsage(MenuModel.recordUse(usage, id, Date.now()))
    Cache.put("menu-usage", usage)
    revision += 1
  }
  // Delete on a Recent row forgets it (Compass did the same).
  function forgetRecent(id) {
    setUsage(MenuModel.forgetUse(usage, id))
    Cache.put("menu-usage", usage)
    revision += 1
  }
  function recentRows() {
    var out = []
    for (var i = 0; i < recentIds.length; i++) {
      var e = items[recentIds[i]]
      if (e && visible(e)) out.push(e)
    }
    return out.slice(0, recentLimit)
  }
  function loadUsage() {
    var c = Cache.get("menu-usage")
    if (c && typeof c === "object" && Object.keys(c).length > 0) setUsage(c)
    else compassUsage.reload()
    var p = Cache.get("menu-pins"), l = Cache.get("menu-last-rail")
    if (Array.isArray(p)) pins = p
    if (typeof l === "string" && l !== "") lastRail = l
    bindsReader.running = true
  }
  FileView {
    id: compassUsage
    path: Quickshell.env("HOME") + "/.local/state/compass-menu-recent.json"
    printErrors: false
    onLoaded: {
      try { root.setUsage(JSON.parse(text())); Cache.put("menu-usage", root.usage) } catch (e) {}
    }
  }

  // ---- opening the menu (summon routes and dmenu requests) ----
  // openSerial changes on every open, so an already-open menu can follow a new request.
  property int openSerial: 0
  property string pendingRoute: "root"
  // A dmenu request (mode select|input) from one of Omarchy's scripts. `active` is true until its result is written.
  property var request: ({ active: false })
  function resolveRoute(input) { return MenuModel.resolveRoute(items, itemOrder, input) }

  function startRequest(p) {
    cancelRequest()
    request = { active: true, mode: p.mode === "input" ? "input" : "select", prompt: String(p.prompt || ""),
                options: Array.isArray(p.options) ? p.options : [], width: Number(p.width) || 0,
                selectionFile: String(p.selectionFile || ""), doneFile: String(p.doneFile || "") }
  }
  // Every exit that is not a choice (Esc, a click outside, a newer request, closing) writes ONLY the done file, so the
  // script that asked waits no longer and sees that nothing was chosen.
  function cancelRequest() {
    if (!request.active) return
    var done = request.doneFile
    request = ({ active: false })
    if (done) Cmd.run(["bash", "-c", ': > "$1"', "_", done])
  }
  // A choice: the selection goes to the selection file, then the done file is written (the same order as the stock menu).
  function finishRequest(selection) {
    if (!request.active) return
    var r = request
    request = ({ active: false })
    if (!r.doneFile) return
    if (selection === null || selection === undefined || r.selectionFile === "")
      Cmd.run(["bash", "-c", ': > "$1"', "_", r.doneFile])
    else
      Cmd.run(["bash", "-c", 'printf "%s\\n" "$1" > "$2"; : > "$3"', "_", String(selection), r.selectionFile, r.doneFile])
  }

  // Entry point for `omarchy-shell island openMenu <json>` (and the shim plugin): a dmenu request, or a route. A route
  // that Omarchy's bindings ask for but that the island has replaced opens that island widget instead.
  // The widget that the last openFromPayload opened (the menu, or a widget a route redirected to), and whether it is still
  // open. The menu shim reads "open" from the shell, so when this widget closes, for any reason, the shim is told.
  property bool shown: false
  property string shownWidget: ""
  Connections {
    target: IslandState
    function onWidgetNameChanged() {
      if (root.shown && IslandState.widgetName !== root.shownWidget) {
        root.shown = false
        Cmd.run(["omarchy-shell", "-q", "menu", "closed"])
      }
    }
  }
  // Closes what the shell opened (the menu, or the widget it redirected to); does nothing otherwise.
  function close() { if (shown && IslandState.widgetName === shownWidget) IslandState.closeWidget("menu closed by shell") }

  function openFromPayload(json) {
    var p = ({})
    try { p = JSON.parse(json || "{}") } catch (e) { p = ({}) }
    if (p.mode === "select" || p.mode === "input") {
      startRequest(p)
      pendingRoute = "root"
      openSerial += 1
      shown = true; shownWidget = "menu"
      IslandState.openWidget("menu", "", true)
      return
    }
    cancelRequest()
    var raw = String(p.initialMenu || p.menu || "root").toLowerCase().replace(/_/g, "-")
    var target = resolveRoute(raw)
    // A route the island replaced opens its widget. Checked on the raw name first: a hidden section (and its alias) is not in the tree, so the lookup cannot find it.
    var widget = MenuHidden.redirectFor(raw, MenuHidden.hide) || MenuHidden.redirectFor(target, MenuHidden.hide)
    if (widget !== "") { IslandState.intent = MenuHidden.intents[raw] || MenuHidden.intents[target] || ""; shown = true; shownWidget = widget; IslandState.openWidget(widget, "", true); return }
    // An unknown route opens the top level; a route that is an action (a row, not a menu) runs it, as the stock menu does.
    var entry = item(target)
    if (!entry) target = "root"
    else if (entry.kind === "action" && entry.provider === "" && target !== "apps") { activate(entry); return }
    pendingRoute = target
    openSerial += 1
    shown = true; shownWidget = "menu"
    IslandState.openWidget("menu", "", true)
  }

  // Run a row: apps launch through DesktopEntries; actions run through a login shell (the same as the stock menu).
  function activate(entry) {
    if (!entry) return
    if (entry.kind === "app") { remember(entry.id); if (entry.desktop) entry.desktop.execute(); return }
    if (entry.kind === "action" && entry.action) { remember(entry.id); Cmd.run(["bash", "-lc", entry.action]) }
  }
}

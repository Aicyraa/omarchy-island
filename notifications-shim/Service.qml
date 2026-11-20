import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Commons

// Headless replacement for omarchy.notifications (`clonedFrom: "omarchy.notifications"`).
// Owns org.freedesktop.Notifications, persists live.json / history.json / quiet.json
// in ~/.local/state/omarchy/notifications/, and answers all `notifications` IPC calls
// (plus `clearHistory` and `removeHistory`) without creating any top-right toast windows,
// so Omarchy Island's NotifToast is the single notification toast UI on screen.
Item {
  id: service

  property var shell: null

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/notifications"
  readonly property int historyLimit: 100
  readonly property int liveLimit: 50
  readonly property int retentionHours: 24

  property bool doNotDisturb: false
  property bool storeReady: false
  property bool liveLoaded: false
  property bool historyLoaded: false
  property bool quietLoaded: false

  property var liveEntries: []
  property var historyEntries: []
  property var refs: ({})
  property var expireTimers: ({})
  property var unsaved: ({})
  property int keySeed: 0

  function nextKey() {
    keySeed += 1
    return "n" + Date.now().toString(36) + keySeed.toString(36)
  }

  function bounded(v, maxLen) {
    var s = String(v === undefined || v === null ? "" : v)
    return s.length > maxLen ? s.slice(0, maxLen) : s
  }

  function stripMarkup(raw) {
    return String(raw || "")
      .replace(/<[^>]+>/g, " ")
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, "\"")
      .replace(/&#39;/g, "'")
      .replace(/\s+/g, " ")
      .trim()
  }

  function serialiseArgv(v) {
    if (Array.isArray(v)) return JSON.stringify(v.slice(0, 16).map(function (x) { return bounded(x, 512) }))
    if (typeof v === "string" && v.length > 0 && v.length < 4096) return v
    return ""
  }

  function snapshot(n, key) {
    var hints = n.hints || {}
    var img = bounded(n.image, 256)
    var named = ""
    if (img.indexOf("image://icon/") === 0 && !/^image:\/\/icon\/(?:\/|file:)/i.test(img)) {
      named = img.substring("image://icon/".length)
    }
    var appIcon = bounded(n.appIcon || named || n.desktopEntry, 256)
    if (!/^[a-zA-Z0-9_.-]{1,256}$/.test(appIcon)) appIcon = ""
    var expire = Number(n.expireTimeout || 0)
    if (!isFinite(expire) || expire < 0) expire = 0
    return {
      key: key,
      originalId: n.id || 0,
      senderPid: Number(hints["sender-pid"] || 0) || 0,
      execArgv: serialiseArgv(hints["omarchy-exec-argv"]),
      execActions: serialiseArgv(hints["omarchy-actions"]),
      glyph: bounded(hints["omarchy-glyph"], 16),
      transient: hints["transient"] === true || hints["transient"] === 1,
      app: bounded(n.appName, 120),
      appIcon: appIcon,
      summary: bounded(stripMarkup(n.summary), 300),
      body: bounded(stripMarkup(n.body), 2000),
      rawBody: "",
      source: bounded(n.appName, 120),
      groupKey: "toast:" + key,
      urgency: typeof n.urgency === "number" ? n.urgency : NotificationUrgency.Normal,
      expireTimeout: expire,
      duration: expire > 0 ? Math.min(30000, Math.max(4500, expire)) : 5000,
      ts: Date.now() / 1000
    }
  }

  function retainHistory(list) {
    var cutoff = Date.now() / 1000 - retentionHours * 3600
    var out = []
    for (var i = 0; i < list.length && out.length < historyLimit; i++) {
      var e = list[i]
      if (!e || typeof e !== "object" || typeof e.key !== "string") continue
      var t = Number(e.closed_ts || e.ts || 0)
      if (t > cutoff) out.push(e)
    }
    return out
  }

  function saveSoon(file) {
    unsaved[file] = true
    if (!saveTimer.running) saveTimer.start()
  }

  Timer {
    id: saveTimer
    interval: 120
    onTriggered: service.flushStore()
  }

  function flushStore() {
    if (unsaved.live && liveLoaded) {
      delete unsaved.live
      liveFile.setText(JSON.stringify(liveEntries) + "\n")
    }
    if (unsaved.history && historyLoaded) {
      delete unsaved.history
      historyFile.setText(JSON.stringify(historyEntries) + "\n")
    }
    if (unsaved.quiet && quietLoaded) {
      delete unsaved.quiet
      quietFile.setText(JSON.stringify({ dnd: !!doNotDisturb }) + "\n")
    }
  }

  function setDoNotDisturb(value) {
    var on = !!value
    if (on === doNotDisturb) return
    doNotDisturb = on
    saveSoon("quiet")
  }

  function recordHistory(entry, reason) {
    if (!entry || entry.transient) return
    var closed = Object.assign({}, entry)
    closed.closed_ts = Date.now() / 1000
    closed.closed_reason = reason || "expired"
    historyEntries = retainHistory([closed].concat(historyEntries.filter(function (x) { return x.key !== closed.key })))
    saveSoon("history")
  }

  function releaseRef(key, reason) {
    var ref = refs[key]
    if (!ref) return
    delete refs[key]
    try {
      if (reason === "expired") ref.expire()
      else if (reason) ref.dismiss()
      else ref.tracked = false
    } catch (e) {}
  }

  function closeLive(key, reason) {
    var found = null
    var rest = []
    for (var i = 0; i < liveEntries.length; i++) {
      if (liveEntries[i].key === key) found = liveEntries[i]
      else rest.push(liveEntries[i])
    }
    if (found) {
      liveEntries = rest
      saveSoon("live")
      recordHistory(found, reason)
    }
    releaseRef(key, reason)
  }

  function clearAllLive(reason) {
    var snapshotList = liveEntries.slice()
    liveEntries = []
    saveSoon("live")
    for (var i = 0; i < snapshotList.length; i++) {
      recordHistory(snapshotList[i], reason)
      releaseRef(snapshotList[i].key, reason)
    }
  }

  function clearAllHistory() {
    clearAllLive("dismissed")
    historyEntries = []
    saveSoon("history")
  }

  function removeHistoryKey(key) {
    if (!key) return false
    var beforeLive = liveEntries.length
    liveEntries = liveEntries.filter(function (x) { return x.key !== key })
    if (liveEntries.length !== beforeLive) {
      saveSoon("live")
      releaseRef(key, "dismissed")
    }
    var beforeHist = historyEntries.length
    historyEntries = historyEntries.filter(function (x) { return x.key !== key })
    if (historyEntries.length !== beforeHist) {
      saveSoon("history")
      return true
    }
    return liveEntries.length !== beforeLive
  }

  function handleNotification(notification) {
    var key = nextKey()
    if (notification.id) {
      for (var i = 0; i < liveEntries.length; i++) {
        if (liveEntries[i].originalId === notification.id) { key = liveEntries[i].key; break }
      }
    }
    notification.tracked = true
    var row = snapshot(notification, key)
    refs[key] = notification

    var silenced = doNotDisturb && row.urgency !== NotificationUrgency.Critical
    if (silenced) {
      recordHistory(row, "silenced")
      releaseRef(key, "")
      return
    }

    var next = liveEntries.filter(function (x) { return x.key !== key })
    next.push(row)
    if (next.length > liveLimit) next = next.slice(-liveLimit)
    liveEntries = next
    saveSoon("live")

    // Move out of live.json into history.json once the Island toast window elapses.
    scheduleExpiry(key, row.duration || 5000)
  }

  function scheduleExpiry(key, ms) {
    var t = Qt.createQmlObject("import QtQuick; Timer { repeat: false }", service)
    t.interval = Math.max(4800, Math.min(30000, ms || 5000))
    t.triggered.connect(function () {
      service.closeLive(key, "expired")
      t.destroy()
    })
    t.start()
  }

  function parseArray(raw) {
    try {
      var v = JSON.parse(String(raw || ""))
      return Array.isArray(v) ? v : []
    } catch (e) { return [] }
  }

  FileView {
    id: liveFile
    path: service.storeReady ? service.stateDir + "/live.json" : ""
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (service.liveLoaded) return
      service.liveLoaded = true
      var prev = service.parseArray(text())
      // Archive any leftover live notifications from before restart into history cleanly.
      for (var i = 0; i < prev.length; i++) service.recordHistory(prev[i], "expired")
      if (prev.length > 0) service.saveSoon("live")
    }
    onLoadFailed: service.liveLoaded = true
  }

  FileView {
    id: historyFile
    path: service.storeReady ? service.stateDir + "/history.json" : ""
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (service.historyLoaded) return
      service.historyLoaded = true
      service.historyEntries = service.retainHistory(service.historyEntries.concat(service.parseArray(text())))
      if (service.unsaved.history) service.saveSoon("history")
    }
    onLoadFailed: service.historyLoaded = true
  }

  FileView {
    id: quietFile
    path: service.storeReady ? service.stateDir + "/quiet.json" : ""
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (service.quietLoaded) return
      service.quietLoaded = true
      try {
        var j = JSON.parse(String(text() || ""))
        if (j && typeof j === "object") service.doNotDisturb = j.dnd === true
      } catch (e) {}
      if (service.unsaved.quiet) service.saveSoon("quiet")
    }
    onLoadFailed: service.quietLoaded = true
  }

  Process {
    id: storePrepare
    command: ["bash", "-c",
      "umask 077\n" +
      "dir=$1\n" +
      "mkdir -p -- \"$dir\" && chmod 700 -- \"$dir\" || exit 1\n" +
      "for name in live.json history.json quiet.json; do\n" +
      "  file=$dir/$name\n" +
      "  if [[ -L $file ]]; then rm -f -- \"$file\"; fi\n" +
      "  if [[ -f $file ]]; then chmod 600 -- \"$file\"; elif [[ ! -e $file ]]; then : >\"$file\"; fi\n" +
      "done\n",
      "island-notifications-state", service.stateDir]
    onExited: function (code) { service.storeReady = (code === 0) }
  }

  Component.onCompleted: storePrepare.running = true
  Component.onDestruction: flushStore()

  NotificationServer {
    id: server
    keepOnReload: false
    imageSupported: true
    actionsSupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    persistenceSupported: true
    onNotification: function (notification) { service.handleNotification(notification) }
  }

  function runShortcut(method) {
    if (typeof ipcHandler[method] !== "function") return false
    ipcHandler[method]()
    return true
  }

  ShellIpc {
    id: ipcHandler
    target: "notifications"

    function ping(): string { return "ok" }
    function isDnd(): string { return service.doNotDisturb ? "on" : "off" }
    function toggleDnd(): string { service.setDoNotDisturb(!service.doNotDisturb); return isDnd() }
    function setDnd(value: string): string {
      var v = String(value || "").toLowerCase()
      service.setDoNotDisturb(v === "true" || v === "1" || v === "on" || v === "yes")
      return isDnd()
    }
    function act(): string { return dismissOne() }
    function dismissOne(): string {
      if (service.liveEntries.length === 0) return "none"
      service.closeLive(service.liveEntries[service.liveEntries.length - 1].key, "dismissed")
      return "ok"
    }
    function dismissAll(): string { service.clearAllLive("dismissed"); return "ok" }
    function clearHistory(): string { service.clearAllHistory(); return "ok" }
    function removeHistory(key: string): string { return service.removeHistoryKey(String(key || "")) ? "ok" : "none" }
    function invokeLast(): string { return dismissOne() }
    function invokeAction(n: int): string { return "none" }
    function keyboard(): string { return "off" }
    function showHistory(): string {
      Quickshell.execDetached(["omarchy-shell", "-q", "island", "open", "notifications"])
      return "ok"
    }
    function dismiss(summary: string): string {
      var needle = String(summary || "")
      if (!needle) return "none"
      var matched = service.liveEntries.filter(function (e) { return String(e.summary || "").indexOf(needle) !== -1 })
      for (var i = 0; i < matched.length; i++) service.closeLive(matched[i].key, "dismissed")
      return matched.length ? "ok" : "none"
    }
    function count(): string { return String(service.liveEntries.length) }
    function expand(): string { return "collapsed" }
    function probe(): string {
      return JSON.stringify({
        headless: true,
        toasts: service.liveEntries.length,
        history: service.historyEntries.length,
        doNotDisturb: service.doNotDisturb
      })
    }
  }
}

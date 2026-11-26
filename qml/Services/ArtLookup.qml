pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Cover-art fallback for players that send no `mpris:artUrl` (browsers playing YouTube, for example).
// Asks Apple's public iTunes Search API for "<artist> <title>" and keeps the 600px cover URL.
// PRIVACY: the search term (the track's artist and title) leaves the machine, once per distinct track,
// and only while a media card is on screen. Results (including misses) are cached for the session.
Singleton {
  id: root
  property var cache: ({})                 // term -> url ("" = looked up, nothing found)
  property string current: ""
  property var queue: []

  function request(term) {
    term = String(term || "").trim().slice(0, 120)
    if (term === "" || cache[term] !== undefined || current === term || queue.indexOf(term) >= 0) return
    if (current === "") start(term); else queue = queue.concat([term])
  }
  function start(term) { current = term; proc.command = ["curl", "-sfm", "8", "-G", "https://itunes.apple.com/search",
    "--data-urlencode", "term=" + term, "-d", "entity=song", "-d", "limit=1"]; proc.running = true }
  function done(url) {
    var c = Object.assign({}, cache); c[current] = url; cache = c
    current = ""
    if (queue.length > 0) { var n = queue[0]; queue = queue.slice(1); start(n) }
  }
  Process {
    id: proc
    stdout: StdioCollector { onStreamFinished: {
      var url = ""
      try { var r = JSON.parse(text).results; if (r && r.length) url = String(r[0].artworkUrl100 || "").replace(/\/\d+x\d+bb\.jpg$/, "/600x600bb.jpg") } catch (e) {}
      root.done(/^https:\/\/[a-z0-9.-]+\.mzstatic\.com\//.test(url) ? url : "")
    } }
    onExited: function (code) { if (code !== 0 && root.current !== "") root.done("") }
  }
}

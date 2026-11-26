pragma Singleton
import QtQuick
import Quickshell

// Cmd: the one place the island runs commands. In the test rig `dryRun` is on,
// so power actions are only LOGGED (and readable over IPC), never executed.
Singleton {
  property bool dryRun: false
  property string last: ""
  function run(argv) {
    last = argv.join(" ")
    if (dryRun) { console.log("island[dry-run]: " + last); return }
    Quickshell.execDetached(argv)
  }
}

import Quickshell

// Test rig: runs the island WITHOUT the Omarchy shell host, so it can be tried
// next to the live bar. `rig: true` stops it reserving screen space.
//   qs -p rig.qml
ShellRoot { Bar { rig: true } }

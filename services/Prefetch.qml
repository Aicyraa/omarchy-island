pragma Singleton
import QtQuick
import Quickshell

// Prefetch: decides WHEN the data services refresh, so a widget never opens empty.
//   * start(): shortly after the shell is up, warm everything once (restored-from-cache data is already showing).
//   * touch(): the pointer is nearing the island (hover intent), or a widget is about to open: refresh what is stale.
// Each refresh is bounded and skipped when the data is recent, so this costs almost nothing when idle.
Singleton {
  id: root
  property bool started: false

  function start() {
    if (started) return
    started = true
    warm.start()
  }
  function touch() {
    SysInfo.refreshIfOlder(5000)
    AgentUsage.refreshIfOlder(60000)
    WeatherData.refreshIfStale()
    Themes.refreshCurrent()
  }
  Timer { id: warm; interval: 2500
    onTriggered: { Themes.refresh(); Themes.refreshCurrent(); AgentUsage.refresh(); SysInfo.refresh(); WeatherData.refreshIfStale() } }
}

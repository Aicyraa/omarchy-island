pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../QuickshellDS/Theme"

// ConfigStore: live-reactive persistent user configuration for Omarchy Island.
// Stored at ~/.config/omarchy/island-config.json and synced directly to QuickshellDS Tokens.
Singleton {
  id: root

  readonly property string configDir: Quickshell.env("HOME") + "/.config/omarchy"
  readonly property string configPath: configDir + "/island-config.json"

  property bool ready: false

  // ---- Appearance ----
  property string surfaceStyle: "classic"        // "classic" | "glass" | "liquid"
  property bool followCompositorRadius: false
  property string density: "comfortable"         // "compact" | "comfortable" | "spacious"
  property real userScale: 1.0
  property bool shadowsEnabled: true
  property string scrollRailVariant: "capsule"   // "capsule" | "hairline" | "gauge"
  property string scrollRailSide: "right"        // "right" | "left"

  // ---- Layout & Position ----
  property string barPosition: "top"             // "top" | "bottom"
  property string barStyle: "pill"               // "pill" | "notch" | "full"

  // ---- Behavior & Motion ----
  property string menuPresentation: "morphed"    // "morphed" | "spotlight"
  property bool reducedMotion: false
  property bool gameMode: false
  property real motionScale: 1.0
  property bool hideInFullscreen: true

  // ---- Topbar Items Visibility ----
  property var barItems: defaultBarItems()

  function defaultBarItems() {
    return {
      workspaces: true,
      activeApps: true,
      clock: true,
      weather: true,
      visualizer: true,
      recording: true,
      wifi: true,
      bluetooth: true,
      battery: true,
      notifications: true,
      audio: true,
      system: true,
      capture: true,
      look: true,
      clipboard: true,
      theme: true,
      settings: true,
      power: true,
      statusEar: true
    }
  }

  function barItemVisible(key) {
    if (!barItems || barItems[key] === undefined) return true
    return !!barItems[key]
  }

  function setBarItem(key, value) {
    var next = Object.assign({}, defaultBarItems(), barItems || {})
    next[key] = !!value
    barItems = next
    save()
  }

  function syncTokens() {
    Tokens.surfaceStyle = surfaceStyle
    Tokens.followCompositorRadius = followCompositorRadius
    Tokens.density = density
    Tokens.userScale = Math.max(0.85, Math.min(1.25, userScale))
    Tokens.shadowsEnabled = shadowsEnabled
    Tokens.reducedMotion = reducedMotion
    Tokens.gameMode = gameMode
    Tokens.motionScale = Math.max(0.6, Math.min(1.4, motionScale))
  }

  onSurfaceStyleChanged: { syncTokens(); save() }
  onFollowCompositorRadiusChanged: { syncTokens(); save() }
  onDensityChanged: { syncTokens(); save() }
  onUserScaleChanged: { syncTokens(); save() }
  onShadowsEnabledChanged: { syncTokens(); save() }
  onScrollRailVariantChanged: save()
  onScrollRailSideChanged: save()
  onBarPositionChanged: save()
  onBarStyleChanged: save()
  onMenuPresentationChanged: save()
  onReducedMotionChanged: { syncTokens(); save() }
  onGameModeChanged: { syncTokens(); save() }
  onMotionScaleChanged: { syncTokens(); save() }
  onHideInFullscreenChanged: save()

  function applyPreset(name) {
    if (name === "obsidian-pill") {
      surfaceStyle = "classic"
      followCompositorRadius = false
      density = "comfortable"
      barStyle = "pill"
      scrollRailVariant = "capsule"
      shadowsEnabled = true
    } else if (name === "frosted-liquid") {
      surfaceStyle = "liquid"
      followCompositorRadius = false
      density = "comfortable"
      barStyle = "pill"
      scrollRailVariant = "capsule"
      shadowsEnabled = true
    } else if (name === "minimal-docked") {
      surfaceStyle = "classic"
      followCompositorRadius = false
      density = "compact"
      barStyle = "notch"
      scrollRailVariant = "hairline"
      shadowsEnabled = true
    }
    save()
  }

  function resetDefaults() {
    surfaceStyle = "classic"
    followCompositorRadius = false
    density = "comfortable"
    userScale = 1.0
    shadowsEnabled = true
    scrollRailVariant = "capsule"
    scrollRailSide = "right"
    barPosition = "top"
    barStyle = "pill"
    menuPresentation = "morphed"
    reducedMotion = false
    gameMode = false
    motionScale = 1.0
    hideInFullscreen = true
    barItems = defaultBarItems()
    syncTokens()
    save()
  }

  function applyJson(raw) {
    try {
      var j = JSON.parse(raw)
      if (!j || typeof j !== "object") return
      if (j.surfaceStyle === "classic" || j.surfaceStyle === "glass" || j.surfaceStyle === "liquid")
        surfaceStyle = j.surfaceStyle
      if (typeof j.followCompositorRadius === "boolean")
        followCompositorRadius = j.followCompositorRadius
      if (j.density === "compact" || j.density === "comfortable" || j.density === "spacious")
        density = j.density
      if (typeof j.userScale === "number" && isFinite(j.userScale))
        userScale = Math.max(0.85, Math.min(1.25, j.userScale))
      if (typeof j.shadowsEnabled === "boolean")
        shadowsEnabled = j.shadowsEnabled
      if (j.scrollRailVariant === "capsule" || j.scrollRailVariant === "hairline" || j.scrollRailVariant === "gauge")
        scrollRailVariant = j.scrollRailVariant
      if (j.scrollRailSide === "right" || j.scrollRailSide === "left")
        scrollRailSide = j.scrollRailSide
      if (j.barPosition === "top" || j.barPosition === "bottom")
        barPosition = j.barPosition
      if (j.barStyle === "pill" || j.barStyle === "notch" || j.barStyle === "full")
        barStyle = j.barStyle
      if (j.menuPresentation === "morphed" || j.menuPresentation === "spotlight")
        menuPresentation = j.menuPresentation
      if (typeof j.reducedMotion === "boolean")
        reducedMotion = j.reducedMotion
      if (typeof j.gameMode === "boolean")
        gameMode = j.gameMode
      if (typeof j.motionScale === "number" && isFinite(j.motionScale))
        motionScale = Math.max(0.6, Math.min(1.4, j.motionScale))
      if (typeof j.hideInFullscreen === "boolean")
        hideInFullscreen = j.hideInFullscreen
      if (j.barItems && typeof j.barItems === "object")
        barItems = Object.assign({}, defaultBarItems(), j.barItems)
    } catch (e) {}
  }

  function serialize() {
    return JSON.stringify({
      surfaceStyle: surfaceStyle,
      followCompositorRadius: followCompositorRadius,
      density: density,
      userScale: userScale,
      shadowsEnabled: shadowsEnabled,
      scrollRailVariant: scrollRailVariant,
      scrollRailSide: scrollRailSide,
      barPosition: barPosition,
      barStyle: barStyle,
      menuPresentation: menuPresentation,
      reducedMotion: reducedMotion,
      gameMode: gameMode,
      motionScale: motionScale,
      hideInFullscreen: hideInFullscreen,
      barItems: barItems
    }, null, 2)
  }

  function save() {
    if (!ready) return
    store.setText(serialize())
  }

  FileView {
    id: store
    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.ready = false
      root.applyJson(text())
      root.syncTokens()
      root.ready = true
    }
    onLoadFailed: {
      root.syncTokens()
      root.ready = true
    }
  }

  Component.onCompleted: syncTokens()
}

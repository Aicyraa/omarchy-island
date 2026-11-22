import QtQuick
import ".."

// Shared crisp text element: always PlainText (safe for external/untrusted strings),
// native vertical-hinted rasterization for sharp rendering on 1x DPI screens, and
// explicit Adwaita Sans / JetBrainsMono Nerd Font families.
// For text inside dynamically scaled containers (e.g. ThemePicker cards), override
// `renderType: Text.QtRendering`.
Text {
  property bool mono: false
  textFormat: Text.PlainText
  renderType: Theme.textRenderType
  font.family: mono ? Theme.monoFamily : Theme.fontFamily
  font.hintingPreference: Theme.fontHinting
}

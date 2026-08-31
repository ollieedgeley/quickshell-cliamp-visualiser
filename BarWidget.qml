import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var bar: null
  property string moduleName: "io.github.olliethomas1992.cliamp-visualiser"
  property var settings: ({})
  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")

  property bool playing: false
  property var bands: []
  property string visualizerName: "Bars"
  property var cliampTheme: ({})

  property color fallbackForeground: "#c5c9c5"
  property color fallbackAccent: "#658594"
  property color fallbackGreen: "#8a9a7b"
  property color fallbackYellow: "#c4b28a"
  property color fallbackRed: "#c4746e"

  readonly property real slotSize: {
    var b = bar
    if (b && "theme" in b && b.theme && b.theme.touchMinimum > 0)
      return b.theme.touchMinimum
    if (b && "barSize" in b && b.barSize > 0)
      return b.barSize
    return 26
  }

  readonly property string rendererKind: rendererFor(visualizerName)
  readonly property color foregroundColor: themeColor("fg", fallbackForeground)
  readonly property color accentColor: themeColor("accent", fallbackAccent)
  readonly property color lowColor: themeColor("green", fallbackGreen)
  readonly property color midColor: themeColor("yellow", fallbackYellow)
  readonly property color highColor: themeColor("red", fallbackRed)

  implicitWidth: Math.max(104, slotSize * 4)
  implicitHeight: slotSize
  visible: playing && rendererKind !== "none"

  function rendererFor(name) {
    var key = String(name || "Bars").toLowerCase().replace(/[^a-z]/g, "")
    var known = [
      "bars", "barsdot", "rain", "barsoutline", "bricks", "columns",
      "classicpeak", "wave", "scatter", "flame", "retro", "pulse",
      "matrix", "binary", "sakura", "firework", "bubbles", "logo",
      "terrain", "scope", "heartbeat", "butterfly", "ascii", "firefly",
      "mosaic", "sand", "geyser", "classicled", "stereo", "none"
    ]
    return known.indexOf(key) >= 0 ? key : "bars"
  }

  function themeColor(key, fallback) {
    var value = cliampTheme && cliampTheme[key]
    return typeof value === "string" && value.length > 0 ? value : fallback
  }

  function clamp01(value) {
    value = Number(value)
    if (!isFinite(value) || value <= 0)
      return 0
    if (value >= 1)
      return 1
    return value
  }

  function clearBands() {
    if (bands.length)
      bands = []
  }

  function setPlaying(next) {
    playing = next === true
    if (!playing) {
      visProc.running = false
      clearBands()
    } else if (!visProc.running) {
      visProc.running = true
    }
  }

  function applyTheme(theme) {
    if (!theme || typeof theme !== "object")
      return
    cliampTheme = {
      name: String(theme.name || ""),
      accent: String(theme.accent || ""),
      fg: String(theme.fg || theme.bright_fg || ""),
      green: String(theme.green || ""),
      yellow: String(theme.yellow || ""),
      red: String(theme.red || "")
    }
  }

  function applyStatus(text) {
    var next = false
    try {
      var data = JSON.parse(String(text || ""))
      next = !!(data && data.state === "playing")
      if (data && data.visualizer)
        visualizerName = String(data.visualizer)
      if (data && data.theme)
        applyTheme(data.theme)
    } catch (e) {
    }
    setPlaying(next)
  }

  function applyFrame(line) {
    if (!playing)
      return
    try {
      var data = JSON.parse(String(line || ""))
      if (data && data.visualizer)
        visualizerName = String(data.visualizer)
      var raw = data && data.bands
      if (!Array.isArray(raw) || raw.length === 0)
        return
      var next = []
      for (var i = 0; i < raw.length; i++)
        next.push(clamp01(raw[i]))
      bands = next
    } catch (e) {
    }
  }

  function applyOmarchyTheme(source) {
    if (!source)
      return
    var lines = String(source).split("\n")
    var pattern = /^\s*([A-Za-z0-9_]+)\s*=\s*"?(#?[0-9A-Fa-f]+)"?\s*$/
    var colors = {}
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(pattern)
      if (match)
        colors[match[1]] = match[2]
    }
    if (colors.foreground)
      fallbackForeground = colors.foreground
    if (colors.accent)
      fallbackAccent = colors.accent
    if (colors.green || colors.color2)
      fallbackGreen = colors.green || colors.color2
    if (colors.yellow || colors.color3)
      fallbackYellow = colors.yellow || colors.color3
    if (colors.red || colors.color1)
      fallbackRed = colors.red || colors.color1
  }

  Component.onCompleted: statusProc.running = true

  FileView {
    id: themeFile
    path: root.stateHome + "/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyOmarchyTheme(text())
    onLoadFailed: themeReload.restart()
  }

  Timer {
    id: themeReload
    interval: 400
    repeat: false
    onTriggered: themeFile.reload()
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: if (!statusProc.running) statusProc.running = true
  }

  Process {
    id: statusProc
    command: ["cliamp", "status", "--json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        root.setPlaying(false)
    }
  }

  Process {
    id: visProc
    command: ["cliamp", "visstream", "--fps", "30"]
    running: false
    stdout: SplitParser {
      onRead: function(line) { root.applyFrame(line) }
    }
    onExited: root.clearBands()
  }

  CompactVisualizer {
    anchors.fill: parent
    bands: root.bands
    mode: root.rendererKind
    foregroundColor: root.foregroundColor
    accentColor: root.accentColor
    lowColor: root.lowColor
    midColor: root.midColor
    highColor: root.highColor
  }
}

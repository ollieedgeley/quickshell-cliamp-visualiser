import QtQuick
import Quickshell.Io

Item {
  id: root

  property bool active: false
  property var levels: [0, 0]
  property var peaks: [0, 0]
  property bool available: false
  readonly property string helperPath: decodeURIComponent(
    String(Qt.resolvedUrl("audio-meter")).replace(/^file:\/\//, ""))

  visible: false
  width: 0
  height: 0

  function clamp(value) {
    value = Number(value)
    return !isFinite(value) ? 0 : Math.max(0, Math.min(1, value))
  }

  function pair(value) {
    if (!Array.isArray(value) || value.length < 2)
      return null
    return [clamp(value[0]), clamp(value[1])]
  }

  function applyFrame(line) {
    try {
      var data = JSON.parse(String(line || ""))
      var nextLevels = pair(data && data.levels)
      var nextPeaks = pair(data && data.peaks)
      if (!nextLevels)
        return
      levels = nextLevels
      peaks = nextPeaks || nextLevels
      available = true
    } catch (e) {
    }
  }

  function clear() {
    available = false
    levels = [0, 0]
    peaks = [0, 0]
  }

  function start() {
    if (active && !capture.running)
      capture.running = true
  }

  onActiveChanged: {
    if (active) {
      start()
    } else {
      retry.stop()
      capture.running = false
      clear()
    }
  }

  Component.onCompleted: start()

  Timer {
    id: retry
    interval: 1000
    repeat: false
    onTriggered: root.start()
  }

  Process {
    id: capture
    command: [root.helperPath]
    running: false
    stdout: SplitParser {
      onRead: function(line) { root.applyFrame(line) }
    }
    onExited: {
      root.clear()
      if (root.active)
        retry.restart()
    }
  }
}

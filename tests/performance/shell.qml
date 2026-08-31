import QtQuick
import QtQuick.Window
import Quickshell

ShellRoot {
  id: shell
  property var renderer: null
  property int paintCount: 0
  property int feedCount: 0

  Window {
    id: window
    width: 124
    height: 46
    visible: true
    color: "#1e2229"

    Item {
      id: host
      anchors.centerIn: parent
      width: 104
      height: 26
    }
  }

  Timer {
    interval: 33
    running: shell.renderer !== null && shell.renderer.active
    repeat: true
    onTriggered: {
      var next = []
      for (var i = 0; i < 25; i++)
        next.push(0.5 + 0.48 * Math.sin((shell.feedCount + i * 2.7) * 0.13))
      shell.renderer.bands = next
      shell.feedCount++
    }
  }

  Timer {
    interval: 4000
    running: true
    repeat: false
    onTriggered: {
      console.log("PERF_RESULT paints=" + shell.paintCount
                  + " feeds=" + shell.feedCount
                  + " animationFrames=" + (shell.renderer ? shell.renderer.frame : 0))
      Qt.quit()
    }
  }

  Component.onCompleted: {
    if (Quickshell.env("PERF_MODE") === "empty")
      return

    var component = Qt.createComponent("file://" + Quickshell.env("PLUGIN_ROOT") + "/CompactVisualizer.qml")
    if (component.status !== Component.Ready) {
      console.error("PERF_SETUP_FAIL " + component.errorString())
      Qt.quit()
      return
    }

    var requestedMode = Quickshell.env("PERF_MODE") || "flame"
    shell.renderer = component.createObject(host, {
      width: host.width,
      height: host.height,
      active: requestedMode !== "idle",
      mode: requestedMode === "idle" ? "flame" : requestedMode,
      bands: [0.5, 0.7, 0.9, 0.6, 0.4, 0.8, 1.0, 0.7, 0.5, 0.3]
    })
    shell.renderer.paint.connect(function() { shell.paintCount++ })
  }
}

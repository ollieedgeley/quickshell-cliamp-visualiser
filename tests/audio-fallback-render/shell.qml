import QtQuick
import QtQuick.Window
import Quickshell

ShellRoot {
  id: shell
  property var meter: null
  property var renderer: null

  Window {
    id: window
    width: 144
    height: 46
    visible: true
    color: "#1e2229"

    Item {
      id: host
      anchors.centerIn: parent
      width: 124
      height: 26
    }
  }

  Component.onCompleted: {
    var rootPath = "file://" + Quickshell.env("PLUGIN_ROOT") + "/"
    var meterComponent = Qt.createComponent(rootPath + "AudioMeter.qml")
    var rendererComponent = Qt.createComponent(rootPath + "CompactVisualizer.qml")
    if (meterComponent.status !== Component.Ready || rendererComponent.status !== Component.Ready) {
      console.error("AUDIO_FALLBACK_RENDER_FAIL setup=" + meterComponent.errorString()
                    + rendererComponent.errorString())
      Qt.quit()
      return
    }
    shell.meter = meterComponent.createObject(host, { active: true })
    shell.renderer = rendererComponent.createObject(host, {
      width: host.width,
      height: host.height,
      mode: "stereo",
      bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      foregroundColor: "#ffffff",
      lowColor: "#00ff00",
      midColor: "#ffff00",
      highColor: "#ff0000"
    })
    shell.meter.levelsChanged.connect(function() {
      shell.renderer.channelLevels = shell.meter.levels
    })
    shell.meter.peaksChanged.connect(function() {
      shell.renderer.channelPeaks = shell.meter.peaks
    })
  }

  Timer {
    interval: 1000
    running: true
    repeat: false
    onTriggered: {
      if (!shell.meter || !shell.meter.available
          || shell.meter.levels[0] <= shell.meter.levels[1] + 0.2) {
        console.error("AUDIO_FALLBACK_RENDER_FAIL available="
                      + (shell.meter ? shell.meter.available : false)
                      + " levels=" + (shell.meter ? shell.meter.levels : []))
        Qt.quit()
        return
      }
      host.grabToImage(function(result) {
        var output = Quickshell.env("AUDIO_FALLBACK_RENDER_OUTPUT")
        if (result.saveToFile(output))
          console.log("AUDIO_FALLBACK_RENDER_PASS levels=" + shell.meter.levels
                      + " peaks=" + shell.meter.peaks + " output=" + output)
        else
          console.error("AUDIO_FALLBACK_RENDER_FAIL save=" + output)
        Qt.quit()
      })
    }
  }
}

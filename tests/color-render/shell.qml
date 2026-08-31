import QtQuick
import QtQuick.Window
import Quickshell

ShellRoot {
  Window {
    id: window
    width: visualizerHost.width + 20
    height: visualizerHost.height + 20
    visible: true
    color: "#1e2229"

    Item {
      id: visualizerHost
      anchors.centerIn: parent
      width: Number(Quickshell.env("RENDER_WIDTH")) || 220
      height: Number(Quickshell.env("RENDER_HEIGHT")) || 40
    }

    Timer {
      interval: 500
      running: true
      repeat: false
      onTriggered: {
        visualizerHost.grabToImage(function(result) {
          var path = Quickshell.env("COLOR_RENDER_OUTPUT")
          if (result.saveToFile(path))
            console.log("COLOR_RENDER_SAVED " + path)
          else
            console.error("COLOR_RENDER_SAVE_FAIL " + path)
          Qt.quit()
        })
      }
    }

    Component.onCompleted: {
      var component = Qt.createComponent("file://" + Quickshell.env("PLUGIN_ROOT") + "/CompactVisualizer.qml")
      if (component.status !== Component.Ready) {
        console.error("COLOR_RENDER_SETUP_FAIL " + component.errorString())
        Qt.quit()
        return
      }

      component.createObject(visualizerHost, {
        width: visualizerHost.width,
        height: visualizerHost.height,
        mode: Quickshell.env("VISUALIZER_MODE") || "classicled",
        bands: [0.25, 0.45, 0.65, 0.85, 1.0, 0.85, 0.65, 0.45, 0.25],
        foregroundColor: "#ffffff",
        accentColor: "#0088ff",
        lowColor: "#00ff00",
        midColor: "#ffff00",
        highColor: "#ff0000"
      })
    }
  }
}

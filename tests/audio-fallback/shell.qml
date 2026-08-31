import QtQuick
import Quickshell

ShellRoot {
  Component.onCompleted: {
    var component = Qt.createComponent("file://" + Quickshell.env("PLUGIN_ROOT") + "/BarWidget.qml")
    if (component.status !== Component.Ready) {
      console.error("AUDIO_FALLBACK_SETUP_FAIL " + component.errorString())
      Qt.quit()
      return
    }

    var widget = component.createObject(null, { width: 120, height: 26 })
    widget.playing = true
    widget.applyFrame('{"visualizer":"Stereo","bands":[0,0,0,0,0,0,0,0,0,0]}')
    var missingUsesFallback = widget.audioFallbackRequired === true

    widget.applyFrame('{"visualizer":"Stereo","bands":[0,0,0,0,0,0,0,0,0,0],'
                      + '"levels":[0.25,0.75],"peaks":[0.4,0.9]}')
    var directWins = widget.audioFallbackRequired === false
                  && Math.abs(widget.visualizerLevels[0] - 0.25) < 0.001
                  && Math.abs(widget.visualizerLevels[1] - 0.75) < 0.001
                  && Math.abs(widget.visualizerPeaks[0] - 0.4) < 0.001
                  && Math.abs(widget.visualizerPeaks[1] - 0.9) < 0.001

    widget.applyFrame('{"visualizer":"Bars","bands":[0.2,0.4,0.7,0.4,0.2]}')
    var spectrumSkipsFallback = widget.audioFallbackRequired === false

    if (missingUsesFallback && directWins && spectrumSkipsFallback)
      console.log("AUDIO_FALLBACK_ROUTING_PASS")
    else
      console.error("AUDIO_FALLBACK_ROUTING_FAIL missing=" + missingUsesFallback
                    + " direct=" + directWins + " spectrum=" + spectrumSkipsFallback)

    widget.destroy()
    Qt.quit()
  }
}

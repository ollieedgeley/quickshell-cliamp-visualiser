import QtQuick
import Quickshell

ShellRoot {
  Component.onCompleted: {
    var component = Qt.createComponent("file://" + Quickshell.env("PLUGIN_ROOT") + "/BarWidget.qml")
    if (component.status !== Component.Ready) {
      console.error("MODE_FOLLOW_SETUP_FAIL " + component.errorString())
      Qt.quit()
      return
    }

    var widget = component.createObject(null, { width: 120, height: 26 })
    widget.applyOmarchyTheme('foreground = "#a1b2c3"\n'
                             + 'accent = "#1a2b3c"\n'
                             + 'green = "#00ff00"\n'
                             + 'yellow = "#ffff00"\n'
                             + 'red = "#ff0000"\n')

    var omarchyPaletteMatches = String(widget.fallbackForeground) === "#a1b2c3"
                              && String(widget.fallbackAccent) === "#1a2b3c"
                              && String(widget.fallbackGreen) === "#00ff00"
                              && String(widget.fallbackYellow) === "#ffff00"
                              && String(widget.fallbackRed) === "#ff0000"

    widget.applyStatus('{"state":"playing","visualizer":"ClassicLED",'
                       + '"theme":{"name":"Test",'
                       + '"accent":"#102030","fg":"#203040",'
                       + '"green":"#304050","yellow":"#405060","red":"#506070"}}')
    widget.applyFrame('{"visualizer":"Wave","bands":[0.1,0.4,0.8,0.4,0.1]}')

    var modeMatches = widget.visualizerName === "Wave" && widget.rendererKind === "wave"
    var paletteMatches = String(widget.accentColor) === "#102030"
                         && String(widget.foregroundColor) === "#203040"
                         && String(widget.lowColor) === "#304050"
                         && String(widget.midColor) === "#405060"
                         && String(widget.highColor) === "#506070"

    if (omarchyPaletteMatches && modeMatches && paletteMatches)
      console.log("MODE_FOLLOW_PASS")
    else
      console.error("MODE_FOLLOW_FAIL visualizer=" + widget.visualizerName
                    + " renderer=" + widget.rendererKind
                    + " palette=" + widget.lowColor + "," + widget.midColor + "," + widget.highColor
                    + " omarchy=" + widget.fallbackGreen + "," + widget.fallbackYellow + "," + widget.fallbackRed)

    widget.destroy()
    Qt.quit()
  }
}

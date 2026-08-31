import QtQuick
import Quickshell

ShellRoot {
  Component.onCompleted: {
    var component = Qt.createComponent("file://" + Quickshell.env("PLUGIN_ROOT") + "/BarWidget.qml")
    if (component.status !== Component.Ready) {
      console.error("INTERACTION_SETUP_FAIL " + component.errorString())
      Qt.quit()
      return
    }

    var widget = component.createObject(null, { width: 120, height: 26 })
    var startsUnlocked = widget.visualizerLocked === false
    var locks = widget.interactionForButton(Qt.RightButton) === "locked"
             && widget.visualizerLocked === true
    var lockedBlocksCycle = widget.interactionForButton(Qt.LeftButton) === "none"
    var unlocks = widget.interactionForButton(Qt.RightButton) === "unlocked"
               && widget.visualizerLocked === false
    var unlockedCycles = widget.interactionForButton(Qt.LeftButton) === "cycle"

    var lockedNotice = widget.notificationForLockState(true)
    var unlockedNotice = widget.notificationForLockState(false)
    var noticesMatch = lockedNotice.headline === "Visualiser locked"
                    && lockedNotice.glyph === "󰌾"
                    && unlockedNotice.headline === "Visualiser unlocked"
                    && unlockedNotice.glyph === ""

    if (startsUnlocked && locks && lockedBlocksCycle && unlocks
        && unlockedCycles && noticesMatch)
      console.log("INTERACTION_PASS")
    else
      console.error("INTERACTION_FAIL start=" + startsUnlocked
                    + " locks=" + locks + " blocked=" + lockedBlocksCycle
                    + " unlocks=" + unlocks + " cycles=" + unlockedCycles
                    + " notices=" + noticesMatch)

    widget.destroy()
    Qt.quit()
  }
}

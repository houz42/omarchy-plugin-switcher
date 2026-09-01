import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// This widget has no popup of its own: the picker UI IS the native
// omarchy.menu list (bin/omarchy-toggle-plugin summons it). "opened" just
// tracks a momentary trigger, flipped back off as soon as the script fires,
// so the standard shell.toggle IPC call still works as a one-shot hotkey
// action instead of a real open/close panel state.
Panel {
  id: root
  moduleName: "houz42.plugin-switcher"
  ipcTarget: "houz42.plugin-switcher"

  readonly property string scriptPath: decodeURIComponent(Qt.resolvedUrl("bin/omarchy-toggle-plugin").toString().replace("file://", ""))

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: {
    if (opened) {
      if (!pickProc.running) pickProc.running = true
      root.opened = false
    }
  }

  Process {
    id: pickProc
    command: [root.scriptPath]
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍉"
    onPressed: function(b) { root.toggle() }
  }
}

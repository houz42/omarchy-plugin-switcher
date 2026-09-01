import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui
import qs.Commons

// Vimium-style hint mode: open it (bar icon or the IPC toggle, e.g. from a
// keybinding), a small letter/number badge appears next to every bar icon,
// then pressing that key toggles that plugin's panel immediately -- no
// typing a name, no Enter, no separate list to search.
//
// Badge positions come from bar.debugBarGeometry(), the same first-party
// function the bar's own overlay-click forwarding relies on (Bar.qml,
// registerClickTarget/moduleSlots) -- it returns each module's id and its
// on-screen x/y/width/height. Coordinates line up directly with screen
// coordinates for a full-width top bar (see KeyboardPanel.qml's own
// cardOrigin comment); bottom/left/right bar positions aren't handled yet.
Panel {
  id: root
  moduleName: "houz42.plugin-switcher"
  ipcTarget: "houz42.plugin-switcher"

  readonly property var anchorWindow: button.QsWindow ? button.QsWindow.window : null

  readonly property var labelPool: {
    var pool = []
    for (var d = 0; d <= 9; d++) pool.push(String(d))
    var skipLower = { h: true, j: true, k: true, l: true, x: true }
    for (var c = 97; c <= 122; c++) {
      var ch = String.fromCharCode(c)
      if (!skipLower[ch]) pool.push(ch)
    }
    for (var C = 65; C <= 90; C++) {
      var chu = String.fromCharCode(C)
      if (chu !== "X") pool.push(chu)
    }
    return pool
  }

  property var hints: []

  // Ids with no popup of their own -- a purely decorative bar-widget (a
  // spacer) or a pure indicator with no open/close state (the workspace
  // number display) -- so `omarchy-shell shell toggle <id>` on them is a
  // silent no-op. There's no reliable way to detect that generically from
  // debugBarGeometry() alone, so known no-op ids are denylisted here.
  readonly property var noOpIds: ["omarchy.spacer", "omarchy.workspaces"]

  // Rough minimum bubble width (a single bold glyph plus its padding),
  // used only to keep adjacent badges from overlapping when their icons
  // sit closer together than that -- the actual per-badge width (which
  // depends on font metrics) is computed later in QML.
  readonly property real minBadgeSpacing: Style.space(26)

  // debugBarGeometry() enumerates every bar moduleSlot -- id, x/y/width/
  // height, visibility -- the same first-party function the bar's own
  // overlay-click forwarding relies on (Bar.qml, registerClickTarget/
  // moduleSlots). It can list more than one entry for the same visible
  // icon (e.g. a plugin registering both a service and a bar-widget slot
  // at the same position), so dedupe by id.
  function buildHints() {
    var geo = (root.bar && typeof root.bar.debugBarGeometry === "function") ? root.bar.debugBarGeometry() : []
    var pool = root.labelPool
    var seen = {}
    var list = []
    for (var i = 0; i < geo.length && list.length < pool.length; i++) {
      var g = geo[i]
      if (!g || g.id === root.moduleName || seen[g.id]) continue
      if (!g.visible || !g.itemVisible) continue
      if (root.noOpIds.indexOf(g.id) !== -1) continue
      seen[g.id] = true
      list.push({ id: g.id, label: pool[list.length], x: g.x, y: g.y, w: g.width, h: g.height })
    }
    list.sort(function(a, b) { return a.x - b.x })

    // Nudge badges whose icons sit closer together than minBadgeSpacing
    // apart, so their bubbles don't overlap. The arrow stays centered on
    // the (now shifted) bubble rather than skewing toward the icon, so
    // this trades a little pointing precision for legibility in crowded
    // bar regions (e.g. the system tray).
    var rightEdge = -Infinity
    for (var j = 0; j < list.length; j++) {
      var item = list[j]
      var center = item.x + item.w / 2
      var left = center - root.minBadgeSpacing / 2
      if (left < rightEdge) center += (rightEdge - left)
      item.cx = center
      rightEdge = center + root.minBadgeSpacing / 2
    }

    root.hints = list
  }

  function activate(label) {
    for (var i = 0; i < root.hints.length; i++) {
      if (root.hints[i].label === label) {
        toggleProc.command = ["omarchy-shell", "shell", "toggle", root.hints[i].id, "{}"]
        toggleProc.running = true
        root.close()
        return
      }
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) buildHints()

  Process {
    id: toggleProc
    stderr: StdioCollector { id: toggleStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var reason = toggleStderr.text.trim()
        notifyProc.command = ["omarchy-notification-send", "Plugin Switcher: toggle failed"
          + (reason ? " (" + reason + ")" : "")]
        notifyProc.running = true
      }
    }
  }

  Process {
    id: notifyProc
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍉"
    onPressed: function(b) { root.toggle() }
  }

  PanelWindow {
    id: overlay
    screen: root.anchorWindow ? root.anchorWindow.screen : null
    visible: root.opened
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "houz42-plugin-switcher-hints"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    Item {
      id: catcher
      anchors.fill: parent
      focus: root.opened

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true; return }
        if (event.text && event.text.length === 1) { root.activate(event.text); event.accepted = true }
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.close()
      }

      Repeater {
        model: root.hints

        // A speech-bubble callout with its point aimed up at the icon it
        // labels, drawn as one closed ShapePath (bubble + triangular tail)
        // so there's no seam or stray corner from compositing separate
        // shapes -- QtQuick.Shapes is the real primitive for this; no
        // pre-made bubble/callout component exists anywhere on this system
        // (checked qs.Ui, qs.Commons, every Qt Quick Controls style, and
        // Quickshell's own modules).
        Item {
          id: badge

          readonly property real bubbleW: badgeText.implicitWidth + Style.space(10)
          readonly property real bubbleH: badgeText.implicitHeight + Style.space(6)
          readonly property real arrowW: Style.space(8)
          readonly property real arrowH: Style.space(5)

          x: modelData.cx - bubbleW / 2
          y: modelData.y + modelData.h + Style.space(2)
          width: bubbleW
          height: bubbleH + arrowH

          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
              strokeWidth: 0
              fillColor: Color.accent
              joinStyle: ShapePath.RoundJoin

              startX: badge.bubbleW / 2
              startY: 0
              PathLine { x: badge.bubbleW / 2 + badge.arrowW / 2; y: badge.arrowH }
              PathLine { x: badge.bubbleW; y: badge.arrowH }
              PathLine { x: badge.bubbleW; y: badge.arrowH + badge.bubbleH }
              PathLine { x: 0; y: badge.arrowH + badge.bubbleH }
              PathLine { x: 0; y: badge.arrowH }
              PathLine { x: badge.bubbleW / 2 - badge.arrowW / 2; y: badge.arrowH }
              PathLine { x: badge.bubbleW / 2; y: 0 }
            }
          }

          Text {
            id: badgeText
            anchors.horizontalCenter: parent.horizontalCenter
            y: badge.arrowH + Style.space(3)
            text: modelData.label
            font.bold: true
            font.pixelSize: Style.font.body
            color: Color.background
          }
        }
      }
    }
  }
}

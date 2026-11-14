import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.Commons
import qs.Ui

// The window: a search bar that grows into a result list. Toggle: `lore`
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  // ---- knobs ----------------------------------------------------------
  property int barWidth: Style.space(760)          // empty state
  property int cardWidth: Style.space(1240)        // with results
  property int topOffset: Style.space(180)          // distance from top of screen
  property int radius: Style.space(40)              // cap; the empty bar is a full pill
  // ---------------------------------------------------------------------

  function open(payloadJson) {
    root.opened = true
    Qt.callLater(function() { view.focusSearch() })
  }
  function close() { root.opened = false }
  function dismiss() {
    root.opened = false
    if (root.shell) root.shell.hide(root.manifest ? root.manifest.id : "lore")
  }
  function toggle() { root.opened ? root.dismiss() : root.open("{}") }

  IpcHandler {                                      // bin/lore and agents call these
    target: "lore"
    function search(query: string, limit: int): string { return view.query(query, limit) }
    function docs(): string { return JSON.stringify(view.docs) }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "lore"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore               // cover the bar too, no undimmed strip

    Rectangle { anchors.fill: parent; color: Color.menu.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      width: view.hasResults ? root.cardWidth : root.barWidth
      Behavior on width { NumberAnimation { duration: view.enterMs; easing.type: Easing.OutQuint } }
      height: view.implicitHeight + contentTopInset + contentBottomInset
      Behavior on height { NumberAnimation { duration: view.enterMs; easing.type: Easing.OutQuint } }
      x: (panel.width - width) / 2
      y: root.topOffset
      radius: Math.min(height / 2, root.radius)
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(1)))
      padding: 0
      clip: true

      MouseArea { anchors.fill: parent; onClicked: {} }

      LoreView {
        id: view
        x: card.contentLeftInset
        y: card.contentTopInset
        width: card.width - card.contentLeftInset - card.contentRightInset
        onCloseRequested: root.dismiss()
      }
    }
  }
}

import Quickshell.Io
import QtQuick
import qs.Commons
import "Search.js" as Search

// Search bar on top. Results: one-line rows on the left, the selected one in full on the right.
// Design knobs at the top. Ranking lives in Search.js.
Item {
  id: root

  signal closeRequested()

  // ---- knobs ----------------------------------------------------------
  property var    docs: ["kitty.conf", "kitty", "hyprctl", "Hyprland"]   // man pages loaded on start
  property int    maxResults: 8
  property int    columns: 90                       // man wraps at this width
  property string mono: Style.font.resolvedFamily
  property real   scale: 1.25                       // text size multiplier for this plugin
  function px(n) { return Math.round(n * scale) }

  property color  fg: Color.menu.text
  property color  accent: Color.accent
  property color  dim: Util.alpha(fg, 0.45)
  property color  hairline: Util.alpha(fg, 0.10)
  property color  codeBg: Util.alpha(fg, 0.06)
  property color  rowSelected: Util.alpha(accent, 0.12)
  property color  optionColor: Util.alpha(accent, 0.8)   // option_names inside descriptions

  property int    padX: Style.spacing.huge + Style.spacing.md   // search field padding
  property int    padY: Style.spacing.huge
  property int    listWidth: Style.space(340)
  property int    rowHeight: Style.space(38)
  property int    resultsHeight: Style.space(520)
  property int    enterMs: 160                      // empty -> results transition
  property bool   rememberQuery: false              // true: reopen with the last search; false: start cleared
  // ---------------------------------------------------------------------

  property var entries: []
  property var results: []
  property int selected: 0
  property bool expanded: false                     // Enter: show the hit's whole section
  readonly property bool hasResults: results.length > 0
  readonly property var current: hasResults ? results[Math.min(selected, results.length - 1)] : null
  // every entry of the current hit's section, in page order (used when expanded)
  readonly property var sectionEntries: current ? entries.filter(function(e) { return e.doc === current.doc && e.section === current.section }) : []

  // QML copies JS objects across property boundaries, so compare entries by content
  function same(a, b) { return a && b && a.doc === b.doc && a.section === b.section && a.lines[0] === b.lines[0] && a.lines.length === b.lines.length }

  function back() { if (root.expanded) root.expanded = false; else root.closeRequested() }
  function expand() {
    if (!root.hasResults) return
    root.expanded = true
    scrollToHit.restart()
  }
  Timer {                                            // after layout, scroll the pane to the hit
    id: scrollToHit
    interval: 120
    onTriggered: {
      for (var i = 0; i < sectionRepeater.count; i++) {
        var item = sectionRepeater.itemAt(i)
        if (item && root.same(item.entry, root.current)) {
          detail.contentY = detailCol.y + item.y - Style.spacing.lg
          detail.returnToBounds()
          return
        }
      }
    }
  }

  implicitHeight: search.height + (hasResults ? root.resultsHeight : 0)

  function focusSearch() {
    if (!root.rememberQuery) input.text = ""
    root.expanded = false
    input.forceActiveFocus(); input.selectAll()
  }

  function runSearch() {
    root.results = Search.search(root.entries, input.text, root.docs, root.maxResults)
    root.selected = 0
  }

  function move(delta) {
    if (!hasResults) return
    root.selected = (root.selected + delta + results.length) % results.length
    list.positionViewAtIndex(root.selected, ListView.Contain)
    if (root.expanded) root.expand(); else detail.contentY = 0
  }

  // ---- description rendering (StyledText) ------------------------------
  function esc(t) { return t.replace(/&/g, "&amp;").replace(/</g, "&lt;") }
  function colorize(t) {
    var out = esc(t)
    out = out.replace(/&lt;#[^&>]*&gt;/g, function(m) { return "<font color='" + root.dim + "'>" + m + "</font>" })   // <#anchor> refs
    out = out.replace(/\b[a-z]+(?:_[a-z0-9]+)+\b/g, function(m) { return "<font color='" + root.optionColor + "'>" + m + "</font>" }) // option_names
    var terms = Search.parseQuery(input.text, root.docs).terms
    for (var i = 0; i < terms.length; i++) {
      var re = new RegExp("(" + terms[i].replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + ")", "gi")
      out = out.replace(re, "<b><font color='" + root.accent + "'>$1</font></b>")
    }
    return out
  }
  // does the entry's second line carry the default value? ("dim_opacity 0.4")
  function hasDefault(e) { return e.header && e.lines.length > 1 && e.lines[1].indexOf(e.lines[0].split(/[ ,]/)[0]) === 0 }
  function title(e) { return e.header ? e.lines[0] : e.section }
  function body(e) {
    var skip = e.header ? (hasDefault(e) ? 2 : 1) : 0          // lines already shown as title / chip
    var html = [], seen = 0
    for (var i = 0; i < e.paras.length; i++) {
      var p = e.paras[i], lines = p.lines
      if (seen < skip) { lines = lines.slice(skip - seen); seen += p.lines.length - lines.length }
      if (!lines.length) continue
      html.push(p.table ? "<font color='" + root.dim + "'>" + lines.map(function(l) { return esc(l).replace(/ /g, "&nbsp;") }).join("<br>") + "</font>"
                        : colorize(lines.join(" ")))
    }
    return html.join("<br><br>")
  }

  Process {
    id: loader
    command: ["sh", "-c", "for p in " + root.docs.join(" ") + "; do printf '\\037%s\\n' \"$p\"; MANWIDTH=" + root.columns + " man --no-hyphenation --no-justification -P cat \"$p\" 2>/dev/null | col -bx; done"]
    running: true
    stdout: StdioCollector { onStreamFinished: { root.entries = Search.parseDocs(this.text); root.runSearch() } }
  }

  Keys.onEscapePressed: root.back()

  // ---- search field: no border of its own, the card border is the border
  Item {
    id: search
    width: parent.width
    height: input.implicitHeight + root.padY * 2

    TextInput {
      id: input
      x: root.padX; y: root.padY
      width: parent.width - root.padX * 2
      color: root.fg
      selectionColor: Util.alpha(root.accent, 0.35)
      selectedTextColor: root.fg
      font.family: root.mono
      font.pixelSize: root.px(Style.font.display)
      clip: true
      onTextChanged: { root.expanded = false; root.runSearch() }
      Keys.onEscapePressed: root.back()
      Keys.onReturnPressed: root.expand()
      Keys.onDownPressed: root.move(1)
      Keys.onUpPressed: root.move(-1)
      Keys.onTabPressed: root.move(1)
    }
    Text {
      x: input.x; y: input.y; width: input.width
      visible: input.text === ""
      text: "Search docs"
      elide: Text.ElideRight
      color: root.dim
      font: input.font
    }
  }

  // ---- results: fade + slide up once, then swap instantly on each keystroke
  Item {
    id: resultsArea
    anchors.top: search.bottom
    width: parent.width
    height: root.resultsHeight
    visible: opacity > 0
    opacity: root.hasResults ? 1 : 0
    transform: Translate { y: root.hasResults ? 0 : 10
      Behavior on y { NumberAnimation { duration: root.enterMs; easing.type: Easing.OutQuint } } }
    Behavior on opacity { NumberAnimation { duration: root.enterMs; easing.type: Easing.OutQuint } }

    Rectangle { width: parent.width; height: 1; color: root.hairline }                       // under the bar
    Rectangle { x: root.listWidth; y: 1; width: 1; height: parent.height - 1; color: root.hairline } // between panes

    // left: one line per hit
    ListView {
      id: list
      x: Style.spacing.lg
      y: Style.spacing.lg + 1
      width: root.listWidth - Style.spacing.lg * 2
      height: parent.height - y - footer.height - Style.spacing.lg
      clip: true
      model: root.results
      boundsBehavior: Flickable.StopAtBounds

      delegate: Rectangle {
        width: list.width
        height: root.rowHeight
        radius: Style.cornerRadius
        color: index === root.selected ? root.rowSelected : (hover.hovered ? Style.hoverFill : "transparent")
        HoverHandler { id: hover }
        TapHandler { onTapped: { root.selected = index; detail.contentY = 0 } }

        Text {
          x: Style.spacing.xxl
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x - doc.width - Style.spacing.xxl * 2
          text: root.title(modelData)
          elide: Text.ElideRight
          color: index === root.selected ? root.fg : Util.alpha(root.fg, 0.8)
          font.family: root.mono
          font.pixelSize: root.px(Style.font.subtitle)
          font.weight: index === root.selected ? Font.DemiBold : Font.Normal
        }
        Text {
          id: doc
          anchors.right: parent.right
          anchors.rightMargin: Style.spacing.xxl
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.doc
          color: root.dim
          font.family: root.mono
          font.pixelSize: root.px(Style.font.caption)
        }
      }
    }

    Text {
      id: footer
      x: Style.spacing.lg + Style.spacing.xxl
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.spacing.lg
      height: implicitHeight + Style.spacing.md
      text: root.results.length + (root.results.length === 1 ? " result" : " results")
      color: root.dim
      font.family: root.mono
      font.pixelSize: root.px(Style.font.caption)
    }

    // right: the selected hit in full
    Flickable {
      id: detail
      x: root.listWidth + 1
      y: 1
      width: parent.width - x
      height: parent.height - 1
      clip: true
      contentHeight: detailCol.height + Style.spacing.huge * 2
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: detailCol
        x: Style.spacing.huge + Style.spacing.md
        y: Style.spacing.huge
        width: detail.width - x * 2
        spacing: Style.spacing.lg
        visible: root.current !== null

        Row {
          spacing: Style.spacing.md
          Text { text: root.current ? root.current.doc : ""; color: root.accent; font.family: root.mono; font.pixelSize: root.px(Style.font.bodySmall); font.weight: Font.DemiBold }
          Text { text: "›"; color: root.dim; font.family: root.mono; font.pixelSize: root.px(Style.font.bodySmall) }
          Text { text: root.current ? root.current.section : ""; color: root.dim; font.family: root.mono; font.pixelSize: root.px(Style.font.bodySmall) }
          Text { visible: !root.expanded; text: "     Enter: whole section"; color: root.dim; font.family: root.mono; font.pixelSize: root.px(Style.font.bodySmall) }
        }

        Repeater {
          id: sectionRepeater
          model: root.expanded ? root.sectionEntries : (root.current ? [root.current] : [])
          delegate: Entry { entry: modelData; width: detailCol.width; hit: root.expanded && root.same(modelData, root.current) }
        }
      }
    }
  }
}

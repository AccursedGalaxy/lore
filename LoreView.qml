import Quickshell
import Quickshell.Io
import QtQuick
import qs.Commons
import "Search.js" as Search

Item {
  id: root

  signal closeRequested()

  // ---- knobs ----------------------------------------------------------
  // what Lore searches. kind: "man" (page name), "md" (file path, ~ allowed) or "lua" (type stubs).
  // ~/.config/lore/sources.json, if present, replaces this list (same shape).
  property var    sources: [
    // man pages
    { kind: "man", name: "kitty.conf" },
    { kind: "man", name: "kitty" },
    { kind: "man", name: "hyprctl" },
    { kind: "man", name: "Hyprland" },
    { kind: "man", name: "tmux" },
    { kind: "man", name: "git" },
    { kind: "man", name: "fzf" },
    { kind: "man", name: "rg" },
    { kind: "man", name: "jq" },
    { kind: "man", name: "nvim" },
    { kind: "man", name: "zsh" },
    { kind: "man", name: "grim" },
    { kind: "man", name: "wtype" },
    // Omarchy guides (markdown)
    { kind: "md",  name: "omarchy",   path: "/usr/share/omarchy/default/agents/skills/omarchy/SKILL.md" },
    { kind: "md",  name: "hyprland",  path: "/usr/share/omarchy/default/agents/skills/omarchy/hyprland.md" },
    { kind: "md",  name: "plugins",   path: "/usr/share/omarchy/default/agents/skills/omarchy/plugins.md" },
    { kind: "md",  name: "theming",   path: "/usr/share/omarchy/default/agents/skills/omarchy/theming.md" },
    { kind: "md",  name: "hooks",     path: "/usr/share/omarchy/default/agents/skills/omarchy/hooks.md" },
    { kind: "md",  name: "capture",   path: "/usr/share/omarchy/default/agents/skills/omarchy/capture.md" },
    { kind: "md",  name: "shell",     path: "/usr/share/omarchy/shell/README.md" },
    { kind: "md",  name: "shell-plugins", path: "/usr/share/omarchy/shell/plugins/README.md" },
    { kind: "md",  name: "bar",       path: "/usr/share/omarchy/shell/plugins/bar/README.md" },
    { kind: "md",  name: "agents",    path: "/usr/share/omarchy/shell/plugins/agents/README.md" },
    // Hyprland Lua API types: config keys, window rule fields, events
    { kind: "lua", name: "hl",        path: "/usr/share/hypr/stubs/hl.meta.lua" },
  ]
  readonly property var docs: sources.map(function(s) { return s.name })   // names usable as a query prefix
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
  property int    maxResultsHeight: Style.space(560)   // results area grows to fit, up to this
  property int    enterMs: 160                      // empty -> results transition
  property bool   rememberQuery: false              // true: reopen with the last search; false: start cleared
  // ---------------------------------------------------------------------

  property var entries: []
  property var results: []
  property int selected: 0
  property string scopeDoc: ""                      // "" = search everything; else inside this doc only
  property var jump: null                           // the hit Enter was pressed on; the pane scrolls to it
  readonly property bool inDoc: scopeDoc !== ""
  readonly property int hitId: jump ? jump.id : current ? current.id : -1   // entry the pane scrolls to / marks
  readonly property bool hasResults: results.length > 0
  readonly property string queryDoc: inDoc ? "" : (Search.parseQuery(input.text, docs).doc || "")   // "kitty opacity" -> kitty
  property bool loading: true
  readonly property var current: hasResults ? results[Math.min(selected, results.length - 1)] : null
  readonly property var docEntries: inDoc ? entries.filter(function(e) { return e.doc === scopeDoc }) : []
  // what the pane renders: the whole doc, a whole markdown section, or just the hit
  readonly property var paneEntries: current === null ? []
    : inDoc || current.kind === "md" ? entries.filter(function(e) { return e.doc === current.doc && e.section === current.section })
    : [current]

  // results area: as tall as the taller of the two panes, capped
  readonly property int listNeeded: results.length * rowHeight + Style.spacing.lg * 2 + footer.height + Style.spacing.lg + 1
  readonly property int detailNeeded: detailCol.height + Style.spacing.huge * 2 + 1
  readonly property int resultsHeight: Math.min(maxResultsHeight, Math.max(listNeeded, detailNeeded))
  implicitHeight: search.height + (hasResults ? resultsHeight : 0)

  function focusSearch() {
    if (!root.rememberQuery) { input.text = ""; root.scopeDoc = ""; root.runSearch() }   // explicit: text may already be ""
    input.forceActiveFocus(); input.selectAll()
  }

  function runSearch() {
    if (root.inDoc && input.text.trim() === "")
      root.results = Search.toc(root.docEntries)                      // empty query: table of contents
    else
      root.results = Search.search(root.inDoc ? root.docEntries : root.entries, input.text, root.inDoc ? [] : root.docs, root.inDoc ? 40 : root.maxResults)
    root.selected = 0
    root.jump = null
    scrollToHit.restart()
  }

  function move(delta) {
    if (!hasResults) return
    root.selected = (root.selected + delta + results.length) % results.length
    list.positionViewAtIndex(root.selected, ListView.Contain)
    scrollToHit.restart()
  }

  function openDoc() {                               // Enter
    if (!root.current || root.inDoc) return
    var hit = root.current
    root.scopeDoc = hit.doc
    input.text = ""                                   // triggers runSearch -> table of contents
    for (var i = 0; i < root.results.length; i++)     // land on the hit's section
      if (root.results[i].section === hit.section) { root.selected = i; break }
    root.jump = hit
    scrollToHit.restart()
  }

  function back() {                                  // Backspace on an empty field inside a doc
    root.scopeDoc = ""; input.text = ""; root.runSearch()
  }

  Timer {                                            // after layout, scroll the pane to the hit
    id: scrollToHit
    interval: 30                                     // coalesces the yChanged burst from the Column
    onTriggered: {
      if (!root.inDoc) { detail.contentY = 0; return }
      for (var i = 0; i < paneRepeater.count; i++) {
        var item = paneRepeater.itemAt(i)
        if (item && item.entry.id === root.hitId) {
          detail.contentY = detailCol.y + item.y - Style.spacing.lg
          detail.returnToBounds()
          return
        }
      }
    }
  }

  // ---- description rendering (StyledText) ------------------------------
  function esc(t) { return t.replace(/&/g, "&amp;").replace(/</g, "&lt;") }
  function colorize(t) {                             // one pass over all terms so a later term can't match an inserted tag
    var terms = Search.parseQuery(input.text, root.inDoc ? [] : root.docs).terms
    if (!terms.length) return esc(t)
    var re = new RegExp("(" + terms.map(function(w) { return esc(w).replace(/[.*+?^${}()|[\]\\]/g, "\\$&") }).join("|") + ")", "gi")
    return esc(t).replace(re, "<b><font color='" + root.accent + "'>$1</font></b>")
  }
  // does the entry's second line carry the default value? ("dim_opacity 0.4")
  function hasDefault(e) { return e.header && e.lines.length > 1 && e.lines[1].indexOf(e.lines[0].split(/[ ,]/)[0]) === 0 }
  function title(e) { return e.header ? e.lines[0] : e.section }
  // paragraphs minus the lines already shown as title / default chip
  function paras(e) {
    var skip = e.header ? (hasDefault(e) ? 2 : 1) : 0, out = []
    for (var i = 0; i < e.paras.length; i++) {
      var lines = e.paras[i].lines.slice(skip); skip -= e.paras[i].lines.length - lines.length
      if (lines.length) out.push({ lines: lines, table: e.paras[i].table })
    }
    return out
  }
  function body(e) {
    return paras(e).map(function(p) {
      return p.table ? "<font color='" + root.dim + "'>" + p.lines.map(function(l) { return esc(l).replace(/ /g, "&nbsp;") }).join("<br>") + "</font>"
                     : colorize(p.lines.join(" "))
    }).join("<br><br>")
  }

  // ---- agent / CLI access: `omarchy-shell lore search "<query>" <limit>` ------
  function plain(e) { return paras(e).map(function(p) { return p.lines.join("\n") }).join("\n\n") }
  function query(q, limit) {
    if (root.loading) return JSON.stringify({ error: "lore: docs still loading, retry in a second" })
    var hits = Search.search(root.entries, q, root.docs, limit > 0 ? limit : 5)
    return JSON.stringify(hits.map(function(e) {
      return { doc: e.doc, section: e.section, title: root.title(e), "default": root.hasDefault(e) ? e.lines[1] : null, body: root.plain(e) }
    }))
  }

  Process {
    id: loader
    // Rendered man pages are cached in ~/.cache/lore (one text file per page) and re-rendered
    // only when the installed page is newer than the cache. Markdown is read directly.
    command: ["sh", "-c", "c=$HOME/.cache/lore; mkdir -p $c; " + root.sources.map(function(s) {
      return s.kind !== "man"
        ? "printf '\\037" + s.kind + ":%s\\n' '" + s.name + "'; cat " + s.path.replace(/^~/, "$HOME") + " 2>/dev/null"
        : "printf '\\037man:%s\\n' '" + s.name + "'; f=$c/" + s.name + ".txt; src=$(man -w '" + s.name + "' 2>/dev/null); "
          + "if [ ! -s \"$f\" ] || [ -n \"$src\" -a \"$src\" -nt \"$f\" ]; then "
          + "MANWIDTH=" + root.columns + " man --no-hyphenation --no-justification -P cat '" + s.name + "' 2>/dev/null | col -bx > \"$f\"; fi; cat \"$f\""
    }).join("; ")]
    stdout: StdioCollector { onStreamFinished: { root.entries = Search.parseDocs(this.text); root.loading = false; root.runSearch() } }
  }

  FileView {                                         // user source list, then start loading
    path: Quickshell.env("HOME") + "/.config/lore/sources.json"
    printErrors: false
    onLoaded: { try { root.sources = JSON.parse(text()) } catch (e) { console.warn("lore: bad sources.json, using defaults:", e) } loader.running = true }
    onLoadFailed: loader.running = true
  }

  Keys.onEscapePressed: root.closeRequested()

  // ---- search field: no border of its own, the card border is the border
  Item {
    id: search
    width: parent.width
    height: input.implicitHeight + root.padY * 2 + (status.visible ? status.height + Style.spacing.sm : 0)

    // scope chip: "kitty.conf ›" when searching inside one doc
    Text {
      id: scope
      x: root.padX; y: root.padY
      visible: root.inDoc
      text: root.scopeDoc + " ›  "
      color: root.accent
      font.family: root.mono
      font.pixelSize: root.px(Style.font.display)
    }
    TextInput {
      id: input
      x: root.padX + (root.inDoc ? scope.width : 0); y: root.padY
      width: parent.width - x - root.padX
      color: root.fg
      selectionColor: Util.alpha(root.accent, 0.35)
      selectedTextColor: root.fg
      font.family: root.mono
      font.pixelSize: root.px(Style.font.display)
      clip: true
      onTextChanged: root.runSearch()
      Keys.onReturnPressed: root.openDoc()
      Keys.onPressed: (ev) => { if (ev.key === Qt.Key_Backspace && root.inDoc && input.text === "") { root.back(); ev.accepted = true } }
      Keys.onDownPressed: root.move(1)
      Keys.onUpPressed: root.move(-1)
      Keys.onTabPressed: root.move(1)
      Keys.onBacktabPressed: root.move(-1)
    }
    Text {
      x: input.x; y: input.y; width: input.width
      visible: input.text === ""
      text: root.inDoc ? "Search inside" : "Search docs"
      elide: Text.ElideRight
      color: root.dim
      font: input.font
    }
    Text {
      id: status
      x: root.padX; y: input.y + input.height + Style.spacing.sm
      width: search.width - root.padX * 2
      visible: !root.inDoc && (root.loading || !root.hasResults)
      text: root.loading ? "Loading docs…" : input.text.trim() === "" ? root.docs.join("  ") : "No results"
      elide: Text.ElideRight
      color: root.dim
      font.family: root.mono
      font.pixelSize: root.px(Style.font.caption)
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

    // left: one line per hit (or per section when browsing a doc)
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
        TapHandler {
          onTapped: { root.selected = index; scrollToHit.restart() }
          onDoubleTapped: { root.selected = index; root.openDoc() }
        }

        Text {
          x: Style.spacing.xxl
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x - doc.width - Style.spacing.xxl * 2
          text: root.inDoc && input.text.trim() === "" ? modelData.section : root.title(modelData)   // contents vs hits
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
          text: root.inDoc ? "" : modelData.doc
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
      verticalAlignment: Text.AlignBottom
      text: root.inDoc && input.text.trim() === "" ? root.results.length + " sections   Backspace: back"
          : root.results.length + (root.results.length === 1 ? " result" : " results") + (root.queryDoc ? " in " + root.queryDoc : "") + (root.inDoc ? "   Backspace: back" : "   Enter: open doc")
      color: root.dim
      font.family: root.mono
      font.pixelSize: root.px(Style.font.caption)
    }

    // right: the hit in full, or the whole document
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
        }

        Repeater {
          id: paneRepeater
          model: root.paneEntries
          delegate: Entry { entry: modelData; view: root; width: detailCol.width; hit: root.inDoc && modelData.id === root.hitId
        onYChanged: if (hit) scrollToHit.restart() }
        }
      }
    }
  }
}

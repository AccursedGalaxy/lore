import QtQuick
import qs.Commons

// One entry in the detail pane: title, default-value chip, description.
Column {
  id: entry
  property var entry: null
  property bool hit: false                          // the entry the search landed on (expanded mode)
  property var view: null                           // the LoreView, set by the delegate
  spacing: Style.spacing.lg

  Text {
    text: entry.entry ? view.title(entry.entry) : ""
    color: entry.hit ? view.accent : view.fg
    font.family: view.mono
    font.pixelSize: view.px(Style.font.display)
    font.weight: Font.Bold
    wrapMode: Text.Wrap
    width: parent.width
  }

  Rectangle {
    visible: entry.entry && view.hasDefault(entry.entry)
    width: code.width + Style.spacing.xl * 2
    height: code.height + Style.spacing.sm * 2
    radius: Style.cornerRadius
    color: view.codeBg
    Text { id: code; anchors.centerIn: parent; text: entry.entry && view.hasDefault(entry.entry) ? entry.entry.lines[1] : ""; color: view.fg; font.family: view.mono; font.pixelSize: view.px(Style.font.subtitle) }
  }

  Text {
    text: entry.entry ? view.body(entry.entry) : ""
    textFormat: Text.StyledText
    color: Util.alpha(view.fg, 0.85)
    font.family: view.mono
    font.pixelSize: view.px(Style.font.title)
    lineHeight: 1.35
    wrapMode: Text.WordWrap
    width: parent.width
    bottomPadding: Style.spacing.huge
  }
}

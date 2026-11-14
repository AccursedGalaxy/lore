import QtQuick
import qs.Commons

// One entry in the detail pane: title, default-value chip, description.
Column {
  id: entry
  property var entry: null
  property bool hit: false                          // the entry the search landed on (expanded mode)
  property var root: parent.parent.parent.parent.parent   // LoreView (Column > Flickable > resultsArea > LoreView)
  spacing: Style.spacing.lg
  topPadding: entry.hit ? 0 : 0

  Text {
    text: entry.entry ? root.title(entry.entry) : ""
    color: entry.hit ? root.accent : root.fg
    font.family: root.mono
    font.pixelSize: root.px(Style.font.display)
    font.weight: Font.Bold
    wrapMode: Text.Wrap
    width: parent.width
  }

  Rectangle {
    visible: entry.entry && root.hasDefault(entry.entry)
    width: code.width + Style.spacing.xl * 2
    height: code.height + Style.spacing.sm * 2
    radius: Style.cornerRadius
    color: root.codeBg
    Text { id: code; anchors.centerIn: parent; text: entry.entry && root.hasDefault(entry.entry) ? entry.entry.lines[1] : ""; color: root.fg; font.family: root.mono; font.pixelSize: root.px(Style.font.subtitle) }
  }

  Text {
    text: entry.entry ? root.body(entry.entry) : ""
    textFormat: Text.StyledText
    color: Util.alpha(root.fg, 0.85)
    font.family: root.mono
    font.pixelSize: root.px(Style.font.title)
    lineHeight: 1.35
    wrapMode: Text.WordWrap
    width: parent.width
    bottomPadding: Style.spacing.huge
  }
}

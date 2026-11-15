// Parse man text into entries and rank them for a query. Plain JS, no Qt.
// An entry = one paragraph of a man page plus the section it sits in.

// raw is the output of `man -P cat` for several pages, each prefixed by a "\x1f<doc>\n" marker.
// keep inner spacing (tables), only strip the man indent
function table_safe_trim(l) { return l.replace(/^\s{0,8}/, "").replace(/\s+$/, "") }

// Markdown: "#" headings become sections, blank lines split paragraphs,
// code fences / lists / tables keep their lines.
function parseMd(entries, doc, lines) {
  var section = doc, para = [], fenced = false, cur = null
  function flush() {
    if (!para.length) return
    var keep = fenced || para.some(function(l) { return /^(\s*[-*]\s|\s*\d+\.\s|\|)/.test(l) })
    if (!cur) { cur = { doc: doc, section: section, header: false, kind: "md", paras: [], lines: [] }; entries.push(cur) }
    cur.paras.push({ lines: para, table: keep })
    cur.lines = cur.lines.concat(para)
    para = []
  }
  for (var i = 0; i < lines.length; i++) {
    var l = lines[i]
    if (/^```/.test(l)) { flush(); fenced = !fenced; continue }
    if (!fenced && /^#+\s/.test(l)) { flush(); section = l.replace(/^#+\s*/, ""); cur = null; continue }
    if (!fenced && l.trim() === "") { flush(); continue }
    para.push(fenced ? l.replace(/\s+$/, "") : l.trim())
  }
  flush()
}

// Lua type stubs (---@class / ---@alias blocks): one entry per class, its fields as a table.
function parseLuaStub(entries, doc, lines) {
  var cur = null
  function start(name, section) {
    cur = { doc: doc, section: section, header: true, kind: "lua", paras: [{ lines: [name], table: false }, { lines: [], table: true }], lines: [name] }
    entries.push(cur)
  }
  for (var i = 0; i < lines.length; i++) {
    var l = lines[i], m
    if ((m = l.match(/^---@class\s+(\S+)/))) { start(m[1], m[1]); continue }
    if ((m = l.match(/^---@alias\s+(\S+)/))) { start(m[1], m[1]); continue }
    if (!cur) continue
    if ((m = l.match(/^---@field\s+(.*)/)) || (m = l.match(/^---\|\s*(.*)/))) {
      var row = m[1].replace(/^\['([^']+)'\]/, "$1")      // ['input.foo'] -> input.foo
      cur.paras[1].lines.push(row); cur.lines.push(row)
    } else if (!/^---/.test(l)) cur = null                 // block ended
  }
}

function parseDocs(raw) {
  var entries = []
  var docs = raw.split("\x1f")
  for (var d = 1; d < docs.length; d++) {
    var nl = docs[d].indexOf("\n")
    var head = docs[d].slice(0, nl).split(":")        // "<kind>:<name>", kind = man | md
    var kind = head[0], doc = head[1]
    var lines = docs[d].slice(nl + 1).replace(/\s+$/, "").split("\n")
    if (kind === "md") { parseMd(entries, doc, lines); continue }
    if (kind === "lua") { parseLuaStub(entries, doc, lines); continue }
    var section = "", para = [], indent = 0, base = 99, cur = null
    // A header is a one-line paragraph at the section's base indent that is not a sentence
    // (e.g. "dim_opacity"). Everything after it attaches until the next header.
    // Prose paragraphs with no header become entries of their own (header: false).
    function flush() {
      if (!para.length) return
      var rest = para.slice(1).map(function(l) { return l.search(/\S/) })
      // a one-liner at the section's base indent ("dim_opacity"), or a line with its description
      // indented under it ("select(f)" in jq, "--flag" in mdoc pages)
      var header = para.length === 1 ? indent <= base && !/[.:]$/.test(para[0]) : indent < Math.min.apply(null, rest)
      var table = para.some(function(l) { return /[\u2500-\u257f]/.test(l) })   // box-drawing chars
      if (header || !cur) {
        cur = { doc: doc, section: section, header: header, paras: [], lines: [] }
        entries.push(cur)
      }
      cur.paras.push({ lines: para.map(table_safe_trim), table: table })
      cur.lines = cur.lines.concat(para.map(table_safe_trim))
      para = []
    }
    for (var i = 1; i < lines.length - 1; i++) {       // skip man header + footer line
      var l = lines[i]
      if (/^\S/.test(l)) { flush(); section = l.trim(); base = 99; cur = null; continue }
      if (l.trim() === "") { flush(); continue }
      if (!para.length) { indent = l.search(/\S/); base = Math.min(base, indent) }
      para.push(l)
    }
    flush()
  }
  for (var k = 0; k < entries.length; k++) entries[k].id = k   // QML copies objects; compare entries by id
  return entries
}

// "kitty opacity" -> { doc: "kitty", docs: ["kitty", "kitty.conf"], terms: ["opacity"] }
// when some loaded doc name starts with "kitty".
function parseQuery(q, docNames) {
  var words = q.trim().toLowerCase().split(/\s+/).filter(Boolean)
  var docs = words.length > 1 ? docNames.filter(function(n) { return n.toLowerCase().indexOf(words[0]) === 0 }) : []
  return { doc: docs.length ? words.shift() : null, docs: docs, terms: words }
}

// Every term must appear in the entry. Title hit beats body hit; title prefix beats both.
function score(entry, terms) {
  var title = (entry.header ? entry.lines[0] : entry.section).toLowerCase()
  var body = entry.lines.join(" ").toLowerCase()
  var s = 0
  for (var t = 0; t < terms.length; t++) {
    var at = title.indexOf(terms[t])
    if (at >= 0) s += at === 0 ? 3 : 2
    else if (body.indexOf(terms[t]) >= 0) s += 1
    else return -1
  }
  return s
}

function search(entries, q, docNames, limit) {
  var pq = parseQuery(q, docNames)
  if (!pq.terms.length) return []
  var hits = []
  for (var i = 0; i < entries.length; i++) {
    var e = entries[i]
    if (pq.doc && pq.docs.indexOf(e.doc) < 0) continue
    var s = score(e, pq.terms)
    if (s >= 0) hits.push({ entry: e, score: s })
  }
  hits.sort(function(a, b) { return b.score - a.score || a.entry.id - b.entry.id })   // ties: page order
  return hits.slice(0, limit).map(function(h) { return h.entry })
}

// Table of contents: the first entry of every section, in page order.
function toc(entries) {
  var out = [], seen = {}
  for (var i = 0; i < entries.length; i++) {
    var e = entries[i]
    if (seen[e.section]) continue
    seen[e.section] = true
    out.push(e)
  }
  return out
}

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

function parseDocs(raw) {
  var entries = []
  var docs = raw.split("\x1f")
  for (var d = 1; d < docs.length; d++) {
    var nl = docs[d].indexOf("\n")
    var head = docs[d].slice(0, nl).split(":")        // "<kind>:<name>", kind = man | md
    var kind = head[0], doc = head[1]
    var lines = docs[d].slice(nl + 1).replace(/\s+$/, "").split("\n")
    if (kind === "md") { parseMd(entries, doc, lines); continue }
    var section = "", para = [], indent = 0, base = 99, cur = null
    // A header is a one-line paragraph at the section's base indent that is not a sentence
    // (e.g. "dim_opacity"). Everything after it attaches until the next header.
    // Prose paragraphs with no header become entries of their own (header: false).
    function flush() {
      if (!para.length) return
      var header = para.length === 1 && indent <= base && !/[.:]$/.test(para[0])
      var table = para.some(function(l) { return /[\u2500-\u257f]/.test(l) })   // box-drawing chars
      if (header || !cur) {
        cur = { doc: doc, section: section, header: header, paras: [], lines: [] }
        entries.push(cur)
      }
      cur.paras.push({ lines: para, table: table })
      cur.lines = cur.lines.concat(para)
      para = []
    }
    for (var i = 1; i < lines.length - 1; i++) {       // skip man header + footer line
      var l = lines[i]
      if (/^\S/.test(l)) { flush(); section = l.trim(); base = 99; cur = null; continue }
      if (l.trim() === "") { flush(); continue }
      if (!para.length) { indent = l.search(/\S/); base = Math.min(base, indent) }
      para.push(table_safe_trim(l))
    }
    flush()
  }
  return entries
}

// "kitty opacity" -> { doc: "kitty", terms: ["opacity"] } when "kitty" names a loaded doc.
function parseQuery(q, docNames) {
  var words = q.trim().toLowerCase().split(/\s+/).filter(Boolean)
  var doc = null
  if (words.length > 1) {
    for (var i = 0; i < docNames.length; i++)
      if (docNames[i].toLowerCase().indexOf(words[0]) === 0) { doc = docNames[i]; words.shift(); break }
  }
  return { doc: doc, terms: words }
}

// "bgopac" matches "background_opacity": every char of the term appears in order.
// Returns a 0..1 tightness (1 = contiguous), or -1 when it does not match.
function fuzzy(term, text) {
  var ti = 0, first = -1, last = -1
  for (var i = 0; i < text.length && ti < term.length; i++) {
    if (text[i] === term[ti]) { if (first < 0) first = i; last = i; ti++ }
  }
  if (ti < term.length) return -1
  return term.length / (last - first + 1) + (first === 0 ? 0.3 : 0)   // prefer matches at the start
}

// Every term must appear somewhere in the entry, or fuzzy-match its title.
// Earlier + in the first line scores higher.
function score(entry, terms) {
  var head = entry.lines[0].toLowerCase()
  var title = (entry.header ? head : entry.section.toLowerCase())
  var body = entry.lines.join(" ").toLowerCase()
  var s = 0
  for (var t = 0; t < terms.length; t++) {
    var at = body.indexOf(terms[t])
    if (at >= 0) {
      s += head.indexOf(terms[t]) >= 0 ? 10 : 1
      s += Math.max(0, 5 - at / 40)                  // early hit in the paragraph
      continue
    }
    var f = fuzzy(terms[t], title)
    if (f < 0) return -1
    s += 6 * f                                       // fuzzy title hit: below an exact one
  }
  return s - entry.lines.length * 0.05                // shorter paragraphs win ties
}

var MIN_BODY = 60          // chars; shorter entries are skipped
var HEADER_BONUS = 4       // options ("dim_opacity") rank above prose

function search(entries, q, docNames, limit) {
  var pq = parseQuery(q, docNames)
  if (!pq.terms.length) return []
  var hits = []
  for (var i = 0; i < entries.length; i++) {
    var e = entries[i]
    if (pq.doc && e.doc !== pq.doc) continue
    if (e.lines.join(" ").length < MIN_BODY) continue       // a bare heading has nothing to show
    var s = score(e, pq.terms)
    if (s >= 0) hits.push({ entry: e, score: s + (e.header ? HEADER_BONUS : 0) })
  }
  hits.sort(function(a, b) { return b.score - a.score })
  return hits.slice(0, limit).map(function(h) { return h.entry })
}

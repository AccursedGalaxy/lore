# Lore

One search box over the docs on your machine. Man pages, Omarchy's own guides, and Hyprland's Lua API types, inside the Omarchy shell.

Press a key, type `opacity`, and get `background_opacity` from kitty.conf with its default value and description. Type `fzf preview` to search inside one page. Press Enter to open the page with a table of contents on the left.

## Install

```bash
omarchy plugin add https://github.com/AccursedGalaxy/lore.git --enable
```

Then bind a key. In `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + L", "Lore (docs)", "omarchy-shell shell toggle lore '{}'")
```

`bin/lore` in this repo is the same toggle as a script, if you want it on your PATH.

## Use

| Key | Action |
|---|---|
| Type | Search everything |
| `kitty.conf opacity` | Search inside one doc. The first word must match a doc name exactly |
| Up / Down, Tab / Shift+Tab | Move through results |
| Enter, or double-click | Open the doc. The left pane becomes its table of contents and the box searches inside it |
| Esc | Back out of the doc, then close |

Ranking is simple. A hit in an option name beats a hit in prose. An exact hit beats a fuzzy one, though fuzzy still works: `bgopac` finds `background_opacity`. When two entries tie, the shorter one comes first.

## Agents and scripts

The same index is reachable from the shell, so a coding agent can check an option before it edits a config file:

```bash
lore search kitty.conf opacity        # plain text, top 5
lore search --json -n 10 hyprland gaps
lore docs
```

`lore search` exits 1 when nothing matches or the shell is not running. Under the hood it calls `omarchy-shell lore search "<query>" <limit>`.

`agents/SKILL.md` tells Claude Code or Codex when to reach for it. Link it into your skills folder:

```bash
ln -s ~/.config/omarchy/plugins/lore/agents ~/.claude/skills/lore
```

## Add your own docs

Create `~/.config/lore/sources.json`. It replaces the built-in list, so copy what you want to keep from the top of `LoreView.qml`. Restart the shell afterwards with `omarchy restart shell`.

```json
[
  { "kind": "man", "name": "kitty.conf" },
  { "kind": "man", "name": "tmux" },
  { "kind": "md",  "name": "theming", "path": "/usr/share/omarchy/default/agents/skills/omarchy/theming.md" },
  { "kind": "md",  "name": "notes",   "path": "~/notes/cheatsheet.md" },
  { "kind": "lua", "name": "hl",      "path": "/usr/share/hypr/stubs/hl.meta.lua" }
]
```

Three kinds:

- `man`: a page name. Rendered once with `man` and cached in `~/.cache/lore`, re-rendered when the installed page changes.
- `md`: a markdown file. Headings become sections, paragraphs become entries.
- `lua`: a Lua type stub file with `---@class` blocks. One entry per class, fields as a table.

The `name` is what you type to scope a search, and what shows next to each result.

## How it works

- `Lore.qml`: the window. A pill that grows into a card.
- `LoreView.qml`: the search box, result list, and detail pane. Design knobs sit at the top of the file.
- `Search.js`: plain JavaScript. Parses the rendered text into entries and ranks them. No Qt in it, so you can run it under node to test ranking.

A man page is split into entries at each option name, meaning a one-line paragraph like `dim_opacity` or `--preview`. Everything below it until the next option belongs to that entry. Prose paragraphs with no option above them become entries of their own.

## License

MIT

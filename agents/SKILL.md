---
name: lore
description: Look up config options, defaults, and command flags from the docs installed on this machine (man pages, Omarchy guides, Hyprland Lua API) before editing config. Use when changing kitty, Hyprland, tmux, git, fzf, rg, jq, zsh or Omarchy settings, or when unsure of an option name or its default.
---

# Lore

Lore indexes the docs on this machine and answers from them. Use it instead of guessing an option name or default from memory.

## Commands

```bash
lore search <query>              # top 5 hits, plain text
lore search -n 10 <query>        # more hits
lore search --json <query>       # JSON: doc, section, title, default, body
lore docs                        # which docs are loaded
```

Put a doc name first to search inside one doc: `lore search kitty.conf opacity`. Doc names come from `lore docs`.

Fuzzy matching works on option names: `lore search bgopac` finds `background_opacity`.

## When to use it

- Before writing or editing a config key: confirm the exact name and the default.
- When a user asks "how do I set X in Y": search, then quote the entry.
- When a command flag is unclear: `lore search rg hidden`.

## Reading results

Each hit prints the doc and section, the option or heading, its default line if the page has one, and the description. Exit code 1 means no hits or the shell is not running. If the shell is not running, say so and fall back to `man`.

## Not covered

Lore only knows the docs in its source list. If `lore docs` does not list the page you need, use `man` directly or add the page to `~/.config/lore/sources.json`.

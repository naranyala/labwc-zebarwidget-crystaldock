# cliphist — Learning Material

> Source: `./sources/cliphist` | Upstream: https://github.com/sentriz/cliphist

---

## What is cliphist?

**cliphist** is a clipboard history manager for Wayland. It records everything copied into
a local SQLite database and lets you recall any past entry via a picker like fuzzel.
Both text and images are supported, preserved byte-for-byte.

In OCWS, cliphist is the clipboard history backend, with fuzzel as the picker UI.

---

## How It Works (pipe-based)

1. **Listen** — `wl-paste --watch cliphist store` stores each clipboard change
2. **List** — `cliphist list` prints `<id>\t<100-char preview>` per entry
3. **Pick** — pipe list through fuzzel/fzf/rofi
4. **Decode** — `cliphist decode` recovers the exact original bytes
5. **Copy** — pipe to `wl-copy`

---

## Usage

```bash
# Fuzzel picker (OCWS default)
cliphist list | fuzzel --dmenu | cliphist decode | wl-copy

# Hide the ID column
cliphist list | fuzzel --dmenu --with-nth 2 | cliphist decode | wl-copy

# fzf picker
cliphist list | fzf --no-sort | cliphist decode | wl-copy

# Delete a specific entry
cliphist list | fuzzel --dmenu | cliphist delete

# Delete by query
cliphist delete-query "secret token"

# Clear all history
cliphist wipe

# Compact database
cliphist compact
```

---

## Config File

`~/.config/cliphist/config`:

```
max-items 1000
max-dedupe-search 200
max-store-size 5MB
min-store-length 3
preview-width 100
```

| Option | Default | Description |
|--------|---------|-------------|
| `max-items` | 750 | Max history entries |
| `max-store-size` | 5MB | Skip items larger than this |
| `min-store-length` | 0 | Skip items shorter than N chars |
| `db-path` | `~/.cache/cliphist/db` | Database location |

---

## OCWS Integration

| File | Role |
|------|------|
| `dotfiles/labwc/autostart` | `wl-paste --watch cliphist store` daemons |
| `scripts/actions/clipboard.sh` | fuzzel picker → cliphist decode → wl-copy |
| `dotfiles/ocws/clipboard.widget` | zigshell-cairo-pango button launching the picker |

---

## Install

```bash
# From source (requires Go)
go install go.senan.xyz/cliphist@latest
```

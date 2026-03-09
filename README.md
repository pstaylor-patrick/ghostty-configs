# Ghostty Configs

Personal [Ghostty](https://ghostty.org) terminal configuration.

## What's included

- **`config`** — Ghostty config with `window-padding-y = 0,24` fix for macOS full-screen bottom padding
- **`scripts/theme-shuffle.sh`** — Contrast-aware random theme shuffler that applies a different color theme per terminal session via OSC escape sequences, with history tracking to avoid visually similar consecutive themes

## Install

```bash
git clone https://github.com/pstaylor-patrick/ghostty-configs.git
cd ghostty-configs
./install.sh
```

This backs up any existing configs and creates symlinks from `~/.config/ghostty/` to this repo.

Add the theme shuffler to your shell by adding this to `~/.zshrc`:

```bash
[ -f "$HOME/.config/ghostty/theme-shuffle.sh" ] && source "$HOME/.config/ghostty/theme-shuffle.sh"
```

## How the theme shuffler works

On each new terminal session, `theme-shuffle.sh` picks a random theme from Ghostty's built-in themes (and any custom themes in `~/.config/ghostty/themes/`). It uses RGB color distance to avoid picking visually similar themes back-to-back and maintains a history file (`.theme-history`, git-ignored) to prevent repeats across tabs.

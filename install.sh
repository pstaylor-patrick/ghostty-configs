#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
GHOSTTY_DIR="$HOME/.config/ghostty"

echo "Installing Ghostty configs from $REPO_DIR"

# Create config directory if needed
mkdir -p "$GHOSTTY_DIR"

# Symlink helper: backs up existing non-symlink files, then creates symlink
link_file() {
  local src="$1"
  local dest="$2"

  if [[ -L "$dest" ]]; then
    echo "  Updating symlink: $dest"
    rm "$dest"
  elif [[ -f "$dest" ]]; then
    echo "  Backing up existing file: $dest → ${dest}.bak"
    mv "$dest" "${dest}.bak"
  fi

  ln -s "$src" "$dest"
  echo "  Linked: $dest → $src"
}

link_file "$REPO_DIR/config" "$GHOSTTY_DIR/config"
link_file "$REPO_DIR/scripts/theme-shuffle.sh" "$GHOSTTY_DIR/theme-shuffle.sh"

echo ""
echo "Done! Make sure your ~/.zshrc contains:"
echo '  [ -f "$HOME/.config/ghostty/theme-shuffle.sh" ] && source "$HOME/.config/ghostty/theme-shuffle.sh"'

#!/bin/bash
set -euo pipefail

echo "======================================="
echo "Installing Nerd Fonts & Cursors"
echo "======================================="

mkdir -p ~/.local/share/fonts
mkdir -p ~/.local/share/icons

# 1. JetBrainsMono Nerd Font
echo "--> Downloading JetBrainsMono Nerd Font..."
TMPFILE=$(mktemp /tmp/jetbrains-XXXXXX.tar.xz)
wget -qO "$TMPFILE" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
tar -xJ -f "$TMPFILE" -C ~/.local/share/fonts/
rm "$TMPFILE"
echo "--> Rebuilding font cache..."
fc-cache -fv >/dev/null 2>&1

# 2. Bibata-Modern-Ice Cursor Theme
echo "--> Downloading Bibata-Modern-Ice cursor theme..."
TMPFILE=$(mktemp /tmp/bibata-XXXXXX.tar.xz)
wget -qO "$TMPFILE" "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz"
tar -xJ -f "$TMPFILE" -C ~/.local/share/icons/
rm "$TMPFILE"

echo ""
echo "Successfully installed!"
echo "Your desktop will now render icons and cursors correctly."

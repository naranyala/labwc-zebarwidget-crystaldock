#!/bin/bash
# Simple startup script for labwc - starts zigshell-cairo-pango with default config

export PATH="$HOME/.local/bin:$PATH"

CONFIG_FILE="$HOME/.config/zigshell-cairo-pango/zigshell-cairo-pango.config"
CSS_FILE="$HOME/.config/zigshell-cairo-pango/catppuccin-mocha.css"

CSS_ARG=""
CONFIG_ARG=""
[ -f "$CSS_FILE" ] && CSS_ARG="-c $CSS_FILE"
[ -f "$CONFIG_FILE" ] && CONFIG_ARG="-f $CONFIG_FILE"

zigshell-cairo-pango $CONFIG_ARG $CSS_ARG 2>/dev/null &
sleep 1
pgrep -x zigshell-cairo-pango && echo "zigshell-cairo-pango started" || echo "zigshell-cairo-pango failed to start"

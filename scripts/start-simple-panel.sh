#!/bin/bash
# Simple startup script for labwc - starts sfwbar with default config

export PATH="$HOME/.local/bin:$PATH"

CONFIG_FILE="$HOME/.config/sfwbar/sfwbar.config"
CSS_FILE="$HOME/.config/sfwbar/catppuccin-mocha.css"

CSS_ARG=""
CONFIG_ARG=""
[ -f "$CSS_FILE" ] && CSS_ARG="-c $CSS_FILE"
[ -f "$CONFIG_FILE" ] && CONFIG_ARG="-f $CONFIG_FILE"

sfwbar $CONFIG_ARG $CSS_ARG 2>/dev/null &
sleep 1
pgrep -x sfwbar && echo "sfwbar started" || echo "sfwbar failed to start"

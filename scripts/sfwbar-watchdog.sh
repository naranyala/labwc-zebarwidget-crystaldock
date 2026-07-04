#!/bin/sh

# Watchdog for sfwbar — restart if it crashes

export PATH="$HOME/.local/bin:$PATH"
export FONTCONFIG_FILE="$HOME/.config/fontconfig/fonts.conf"

CONFIG_FILE="$HOME/.config/sfwbar/sfwbar.config"
CSS_FILE="$HOME/.config/sfwbar/catppuccin-mocha.css"

CSS_ARG=""
CONFIG_ARG=""
[ -f "$CSS_FILE" ] && CSS_ARG="-c $CSS_FILE"
[ -f "$CONFIG_FILE" ] && CONFIG_ARG="-f $CONFIG_FILE"

while true; do
  if ! pgrep -x "sfwbar" > /dev/null; then
    if [ -n "$CONFIG_ARG" ]; then
      sfwbar $CONFIG_ARG $CSS_ARG > /dev/null 2>&1 &
      sleep 1
      pgrep -x sfwbar > /dev/null && echo "sfwbar restarted (PID: $(pgrep -x sfwbar))"
    fi
  fi
  sleep 5
done

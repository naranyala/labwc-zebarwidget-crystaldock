#!/bin/bash
# ocws-autorun — Launch autorun programs from config
# Config: ~/.config/labwc/autorun.conf
# Called by labwc autostart at compositor startup

set -euo pipefail

# Ensure local and package manager binaries are in PATH
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$HOME/.npm-global/bin:$HOME/.bun/bin:$PATH"

CFG="${1:-$HOME/.config/labwc/autorun.conf}"
LOG="${XDG_RUNTIME_DIR:-$HOME/.cache}/ocws-autorun.log"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

if [ ! -f "$CFG" ]; then
    log "No autorun config found at $CFG"
    exit 0
fi

log "=== Autorun starting ==="

while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and empty lines
    line="$(echo "$line" | sed 's/#.*//' | xargs)"
    [ -z "$line" ] && continue

    # Check for daemon: prefix (only run once)
    DAEMON=false
    if [[ "$line" == daemon:* ]]; then
        DAEMON=true
        line="${line#daemon:}"
        line="$(echo "$line" | xargs)"
    fi

    # Extract command name (first word) for pgrep check
    CMD_NAME="$(echo "$line" | awk '{print $1}')"

    if [ "$DAEMON" = true ]; then
        # Skip if already running
        if pgrep -x "$CMD_NAME" >/dev/null 2>&1; then
            log "Skip (already running): $CMD_NAME"
            continue
        fi
    fi

    log "Starting: $line"
    nohup sh -c "$line" >> "$LOG" 2>&1 &
    log "Started: $line (PID: $!)"

done < "$CFG"

log "=== Autorun complete ==="

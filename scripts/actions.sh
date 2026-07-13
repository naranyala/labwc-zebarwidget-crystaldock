#!/bin/bash
set -euo pipefail
# actions.sh — Dispatcher for modular action scripts

if [ -z "$1" ]; then
    echo "Usage: actions.sh <action_name> [args...]"
    exit 1
fi

ACTION="$1"
shift

# Search multiple paths for action scripts
SCRIPT=""
for dir in "$HOME/.local/bin/actions" "$HOME/.config/ocws/scripts/actions" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/actions"; do
    if [ -x "$dir/${ACTION}.sh" ]; then SCRIPT="$dir/${ACTION}.sh"; break; fi
    if [ -x "$dir/${ACTION}" ]; then SCRIPT="$dir/${ACTION}"; break; fi
done

if [ -n "$SCRIPT" ]; then
    exec "$SCRIPT" "$@"
else
    echo "Error: Action '$ACTION' not found"
    exit 1
fi

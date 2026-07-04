#!/bin/bash
# Simple emoji picker using fuzzel

EMOJI_FILE="$HOME/.cache/emojis.txt"
EMOJI_URL="https://unicode.org/Public/emoji/15.0/emoji-test.txt"

if [ ! -f "$EMOJI_FILE" ]; then
    mkdir -p "$(dirname "$EMOJI_FILE")"
    notify-send "Emoji Picker" "Downloading emoji list..." -i "face-smile"
    
    # Download and parse unicode emoji list
    if curl -sSL "$EMOJI_URL" | awk -F '#' '/fully-qualified/ {print $2}' | sed -E 's/^[[:space:]]+//' | grep -v 'fully-qualified' > "$EMOJI_FILE"; then
        notify-send "Emoji Picker" "Download complete!" -i "face-smile"
    else
        notify-send "Emoji Picker Error" "Failed to download emoji list" -i "dialog-error"
        rm -f "$EMOJI_FILE"
        exit 1
    fi
fi

if [ -f "$EMOJI_FILE" ]; then
    # fuzzel outputs the selected line
    selected=$(fuzzel -d -p "Emoji: " -w 80 -l 15 < "$EMOJI_FILE")
    
    if [ -n "$selected" ]; then
        # The emoji is the first character(s) before space
        emoji=$(echo "$selected" | awk '{print $1}')
        echo -n "$emoji" | wl-copy
        notify-send "Emoji Picker" "Copied $emoji to clipboard" -i "face-smile"
        
        # If wtype is installed, type it directly
        if command -v wtype &>/dev/null; then
            wtype "$emoji"
        fi
    fi
fi

#!/bin/bash
# OCWS Widget Test Suite
# Tests icon/text rendering and configuration integrity for zigshell-cairo-pango

set -e

OCWS_DIR="dotfiles/ocws"
FAILS=0

pass() { echo -e "\e[32m[PASS]\e[0m $1"; }
fail() { echo -e "\e[31m[FAIL]\e[0m $1"; FAILS=$((FAILS+1)); }
info() { echo -e "\e[34m[INFO]\e[0m $1"; }
warn() { echo -e "\e[33m[WARN]\e[0m $1"; }

info "Running Widget Integrity Tests..."

if [[ ! -d "$OCWS_DIR" ]]; then
    fail "Directory $OCWS_DIR not found. Run this from the project root."
    exit 1
fi

# 1. Check if all widgets in ocws.config are included in plugins.config
info "Checking Topbar Widget References..."
TOPBAR_WIDGETS=$(grep '^[[:space:]]*widget "' "$OCWS_DIR/ocws.config" | grep -o '"[^"]*"' | tr -d '"')

for w in $TOPBAR_WIDGETS; do
    # Check plugins.config
    if grep -q "include(\"$w.widget\")" "$OCWS_DIR/plugins.config" || grep -q "include(\"$w\")" "$OCWS_DIR/plugins.config"; then
        pass "Widget '$w' is included in plugins.config"
    else
        fail "Widget '$w' is used in ocws.config but MISSING from plugins.config"
    fi
    
    # 2. Check if the widget file exports the button correctly
    if [[ -f "$OCWS_DIR/$w.widget" ]]; then
        if grep -qE "export button *[\"']$w[\"']" "$OCWS_DIR/$w.widget"; then
            pass "Widget '$w' exports button correctly"
        else
            fail "Widget '$w.widget' does NOT export button '$w'"
        fi
    elif [[ "$w" == "tray" && -f "$OCWS_DIR/tray.widget" ]]; then
        # tray is a special built-in case in some versions, but let's check
        if grep -qE "export (button|tray|grid) *[\"']$w[\"']" "$OCWS_DIR/$w.widget"; then
            pass "Widget '$w' exports component correctly"
        else
            info "Widget '$w' is a system component or does not export standard button"
        fi
    else
        fail "Widget file '$w.widget' does not exist!"
    fi
done

# 3. Check for inline text rendering string validity
info "Checking inline text formatting in labels..."
for f in "$OCWS_DIR"/*.widget; do
    # Check for basic unbalanced quotes in label values
    if grep -Eq 'value[[:space:]]*=[[:space:]]*"[^"]*$' "$f"; then
        fail "Unterminated string in label value in $(basename "$f")"
    fi
    
    # Check if string concatenations have mismatched types or broken plus signs
    if grep -Eq 'value[[:space:]]*=.* \+ $' "$f"; then
        fail "Dangling concatenation operator in $(basename "$f")"
    fi
done

# 4. Icon rendering check - verify NerdFont unicode symbols are used
info "Checking for presence of icons in text widgets..."
TEXT_WIDGETS=$(ls "$OCWS_DIR"/*-text.widget 2>/dev/null || true)
for tw in $TEXT_WIDGETS; do
    # Check for non-ASCII characters which usually represent NerdFont icons
    if grep -q -P "[^\x00-\x7F]" "$tw"; then
        pass "Widget $(basename "$tw") uses graphical icons correctly"
    else
        warn "Widget $(basename "$tw") might be missing graphical icons"
    fi
done

if [[ $FAILS -gt 0 ]]; then
    echo -e "\n\e[31m$FAILS tests failed! Please fix widget configurations.\e[0m"
    exit 1
else
    echo -e "\n\e[32mAll widget rendering and integrity tests passed!\e[0m"
    exit 0
fi

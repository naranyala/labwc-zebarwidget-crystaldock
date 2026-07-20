#!/bin/bash
# ocws-validate - Check OCWS infrastructure health
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
fail=0

check() {
    if command -v "$1" &>/dev/null; then
        echo -e "  ${GREEN}OK${NC}   $1"
    else
        echo -e "  ${RED}MISS${NC} $1"
        fail=1
    fi
}

echo "=== OCWS Binary Validation ==="
for bin in ocws-clip ocws-emit ocws-lock ocws-kv ocws-brightness \
            ocws-volume ocws-color ocws-shot ocws-state ocws-style \
            ocws-sysmon ocws-search ocws-plugin ocws-player \
            ocws-network-bandwidth ocws-validate ocws-settings \
            ocws-welcome ocws-equalizer ocws-wallpaper ocws-notify \
            ocws-hypertile ocws-brokerd ocws-tray ocws-llm-runner \
            ocws-dotdesktop-mgr ocws-pkgmgr ocws-fonts-mgr \
            ocws-dock-mgr ocws-live-bg ocws-osd-notify \
            ocws-wallpaper-picker ocws-equalizer-gl ocws-waveform-gl \
            ocws-equalizer-qs ocws-waveform-qs ocws-recorder \
            ocws-gestured; do
    check "$bin"
done

echo
echo "=== Daemon Process Check ==="
if pgrep -x "zigshell-cairo-pango" &>/dev/null; then
    echo -e "  ${GREEN}RUNNING${NC} zigshell-cairo-pango"
else
    echo -e "  ${YELLOW}STOPPED${NC} zigshell-cairo-pango (not required for all modes)"
fi

if pgrep -x "labwc" &>/dev/null; then
    echo -e "  ${GREEN}RUNNING${NC} labwc"
else
    echo -e "  ${RED}STOPPED${NC} labwc"
    fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
    echo -e "${GREEN}All checks passed.${NC}"
else
    echo -e "${RED}Some checks failed. Reinstall missing binaries.${NC}"
fi
exit "$fail"

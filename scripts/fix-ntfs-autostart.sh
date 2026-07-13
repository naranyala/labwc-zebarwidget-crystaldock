#!/bin/bash
#
# fix-ntfs-autostart.sh — Auto-fix & mount all NTFS partitions at startup
#
# Designed to be called from labwc autostart or autorun.conf.
# Uses sudo -n (non-interactive) so it never blocks for a password.
# For this to work, set up passwordless sudo via:
#   sudo cp dotfiles/labwc/sudoers.d/10-fix-ntfs /etc/sudoers.d/10-fix-ntfs
#   sudo chmod 440 /etc/sudoers.d/10-fix-ntfs
#
# Logs are written to $XDG_RUNTIME_DIR/fix-ntfs-autostart.log (or /tmp).

LOG_DIR="${XDG_RUNTIME_DIR:-/tmp}"
LOG="$LOG_DIR/fix-ntfs-autostart.log"

echo "--- fix-ntfs-autostart: $(date) ---" >> "$LOG"

# Locate the actual fix script next to this one or in PATH
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
FIX_SCRIPT="$SCRIPT_DIR/fix-ntfs-rw.sh"

if [ ! -x "$FIX_SCRIPT" ]; then
  FIX_SCRIPT="$(command -v fix-ntfs-rw.sh)"
fi

if [ ! -x "$FIX_SCRIPT" ]; then
  echo "[!] fix-ntfs-rw.sh not found. Skipping NTFS fix." >> "$LOG"
  exit 0
fi

# Run with sudo -n (non-interactive, fails if password required)
sudo -n "$FIX_SCRIPT" >> "$LOG" 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "[+] NTFS fix completed successfully." >> "$LOG"
elif [ $EXIT_CODE -eq 1 ] && grep -qi "no ntfs" "$LOG"; then
  echo "[*] No NTFS partitions detected." >> "$LOG"
else
  echo "[!] NTFS fix exited with code $EXIT_CODE." >> "$LOG"
  echo "[!] Ensure passwordless sudo is set up for ntfsfix and mount." >> "$LOG"
fi

echo "" >> "$LOG"
exit 0

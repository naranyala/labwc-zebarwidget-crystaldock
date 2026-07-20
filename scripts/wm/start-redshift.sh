#!/bin/bash
#
# start-redshift.sh — Start redshift/gammastep for eye protection (always-on)
#
# Supports: redshift, gammastep (Wayland-native), gamma-randr
# Auto-detects available tool and runs in background.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}→${NC} $*"; }
pass()  { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
fail()  { echo -e "${RED}✗${NC} $*"; exit 1; }

# --- Configuration ---
# Day temp (Kelvin) — higher = cooler/bluer
DAY_TEMP="${REDSHIFT_DAY_TEMP:-6500}"
# Night temp (Kelvin) — lower = warmer/more orange
NIGHT_TEMP="${REDSHIFT_NIGHT_TEMP:-3500}"
# Gamma adjustment (0.0-1.0)
GAMMA="${REDSHIFT_GAMMA:-1.0}"
# Latitude/Longitude (auto-detected if geoclue available)
LAT="${REDSHIFT_LAT:-}"
LON="${REDSHIFT_LON:-}"
PID_FILE="${XDG_RUNTIME_DIR:-$HOME/.cache}/redshift.pid"

# --- Detect existing instance ---
REDshift_PID=""
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    REDshift_PID="$OLD_PID"
  fi
fi

# Check if redshift/gammastep is already running
EXISTING=""
for proc in redshift gammastep; do
  if pgrep -x "$proc" &>/dev/null; then
    EXISTING="$proc"
    break
  fi
done

if [ -n "$EXISTING" ]; then
  warn "$EXISTING is already running (PID: $(pgrep -x "$EXISTING"))"
  echo ""
  read -rp "Kill and restart with new settings? [y/N] " ans
  if [[ ! "$ans" =~ ^[Yy] ]]; then
    info "Keeping existing $EXISTING instance"
    exit 0
  fi
  pkill -x "$EXISTING" 2>/dev/null || true
  sleep 1
fi

# --- Auto-detect tool ---
TOOL=""
if command -v gammastep &>/dev/null; then
  TOOL="gammastep"
elif command -v redshift &>/dev/null; then
  TOOL="redshift"
elif command -v gamma-randr &>/dev/null; then
  TOOL="gamma-randr"
fi

if [ -z "$TOOL" ]; then
  fail "No screen protection tool found"
  info "Install one of:"
  info "  sudo apt install gammastep        # Wayland-native (recommended)"
  info "  sudo apt install redshift         # X11/Wayland"
  info "  sudo apt install gamma-randr      # Minimal"
fi

info "Using: $TOOL"

# --- Auto-detect location ---
if [ -z "$LAT" ] || [ -z "$LON" ]; then
  if command -v geoclue-2.0 &>/dev/null || command -v geoclue2 &>/dev/null; then
    info "Location will be auto-detected via geoclue"
  else
    # Fallback: use fixed location (London, UK as default)
    LAT="${LAT:-51.5074}"
    LON="${LON:--0.1278}"
    info "Using default location: $LAT, $LON (London, UK)"
    info "Set REDSHIFT_LAT and REDSHIFT_LON environment variables for your location"
  fi
fi

# --- Stop any existing instance ---
if [ -n "$EXISTING" ]; then
  pkill -x "$EXISTING" 2>/dev/null || true
  sleep 1
fi

# --- Launch ---
echo ""
echo "== Starting $TOOL (eye protection) =="
echo ""

case "$TOOL" in
  gammastep)
    GAMMASTEP_ARGS=(-m randr -v)
    if [ -n "$LAT" ] && [ -n "$LON" ]; then
      GAMMASTEP_ARGS+=(-l "$LAT:$LON")
    fi
    GAMMASTEP_ARGS+=(-t "$DAY_TEMP:$NIGHT_TEMP" -g "$GAMMA")

    info "Day temp:   ${DAY_TEMP}K"
    info "Night temp: ${NIGHT_TEMP}K"
    info "Gamma:      $GAMMA"
    info "Args:       ${GAMMASTEP_ARGS[*]}"
    echo ""

    gammastep "${GAMMASTEP_ARGS[@]}" &
    GAMMASTEP_PID=$!
    echo "$GAMMASTEP_PID" > "$PID_FILE"
    pass "gammastep started (PID: $GAMMASTEP_PID)"
    ;;

  redshift)
    REDSHIFT_ARGS=(-r -m randr -v)
    if [ -n "$LAT" ] && [ -n "$LON" ]; then
      REDSHIFT_ARGS+=(-l "$LAT:$LON")
    fi
    REDSHIFT_ARGS+=(-t "$DAY_TEMP:$NIGHT_TEMP" -g "$GAMMA")

    info "Day temp:   ${DAY_TEMP}K"
    info "Night temp: ${NIGHT_TEMP}K"
    info "Gamma:      $GAMMA"
    info "Args:       ${REDSHIFT_ARGS[*]}"
    echo ""

    redshift "${REDSHIFT_ARGS[@]}" &
    REDSHIFT_PID=$!
    echo "$REDSHIFT_PID" > "$PID_FILE"
    pass "redshift started (PID: $REDSHIFT_PID)"
    ;;

  gamma-randr)
    GAMMA_RANDR_ARGS=(-m randr)
    if [ -n "$LAT" ] && [ -n "$LON" ]; then
      GAMMA_RANDR_ARGS+=(-l "$LAT:$LON")
    fi
    GAMMA_RANDR_ARGS+=(-t "$DAY_TEMP:$NIGHT_TEMP")

    info "Day temp:   ${DAY_TEMP}K"
    info "Night temp: ${NIGHT_TEMP}K"
    info "Args:       ${GAMMA_RANDR_ARGS[*]}"
    echo ""

    gamma-randr "${GAMMA_RANDR_ARGS[@]}" &
    GAMMA_PID=$!
    echo "$GAMMA_PID" > "$PID_FILE"
    pass "gamma-randr started (PID: $GAMMA_PID)"
    ;;
esac

echo ""
echo "== Eye Protection Active =="
echo ""
echo "Status:     Running (auto-adjusts to time of day)"
echo "Day:        ${DAY_TEMP}K (cool/blue)"
echo "Night:      ${NIGHT_TEMP}K (warm/orange)"
echo ""
echo "Stop:       kill \$(cat "$PID_FILE")"
echo "Or:         pkill -x $TOOL"
echo ""
echo "To add to autostart, add to ~/.config/labwc/autostart:"
echo "  $0 &"

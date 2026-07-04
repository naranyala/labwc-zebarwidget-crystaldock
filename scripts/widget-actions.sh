#!/bin/bash
#
# widget-actions.sh — Standardized CLI actions for sfwbar widgets
#
# Widgets shell out to this for volume, brightness, media, network, power.
# All return JSON for easy parsing: {"status":"ok","value":...}

set -euo pipefail

SINK="@DEFAULT_SINK@"
SOURCE="@DEFAULT_SOURCE@"

case "${1:-help}" in
  # === Volume ===
  volume-up)
    wpctl set-volume "$SINK" "${2:-5}%+"
    wpctl get-volume "$SINK" | awk '{printf "{\"status\":\"ok\",\"value\":%.0f}\n", $2*100}'
    ;;
  volume-down)
    wpctl set-volume "$SINK" "${2:-5}%-"
    wpctl get-volume "$SINK" | awk '{printf "{\"status\":\"ok\",\"value\":%.0f}\n", $2*100}'
    ;;
  volume-set)
    wpctl set-volume "$SINK" "${2:-50}%"
    wpctl get-volume "$SINK" | awk '{printf "{\"status\":\"ok\",\"value\":%.0f}\n", $2*100}'
    ;;
  volume-mute)
    wpctl set-mute "$SINK" toggle
    muted=$(wpctl get-volume "$SINK" | grep -c 'MUTED' || true)
    echo "{\"status\":\"ok\",\"muted\":$muted}"
    ;;
  volume-get)
    wpctl get-volume "$SINK" | awk '{printf "{\"status\":\"ok\",\"value\":%.0f,\"muted\":%s}\n", $2*100, ($0~"MUTED"?"true":"false")}'
    ;;

  # === Microphone ===
  mic-mute)
    wpctl set-mute "$SOURCE" toggle
    muted=$(wpctl get-volume "$SOURCE" | grep -c 'MUTED' || true)
    echo "{\"status\":\"ok\",\"muted\":$muted}"
    ;;
  mic-get)
    wpctl get-volume "$SOURCE" | awk '{printf "{\"status\":\"ok\",\"muted\":%s}\n", ($0~"MUTED"?"true":"false")}'
    ;;

  # === Brightness ===
  brightness-up)
    brightnessctl set "${2:-5}%+" 2>/dev/null || light -A "${2:-5}" 2>/dev/null || busctl --user set-property org.clight.clight /org/clight/clight/Conf org.clight.clight.Conf Brightness i $(( $(brightnessctl get 2>/dev/null || echo 0) + 5 )) 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;
  brightness-down)
    brightnessctl set "${2:-5}%-" 2>/dev/null || light -U "${2:-5}" 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;
  brightness-get)
    val=$(brightnessctl get 2>/dev/null)
    max=$(brightnessctl max 2>/dev/null)
    if [ -n "$val" ] && [ -n "$max" ] && [ "$max" -gt 0 ]; then
      pct=$(( val * 100 / max ))
      echo "{\"status\":\"ok\",\"value\":$pct}"
    else
      echo "{\"status\":\"error\",\"message\":\"brightnessctl not available\"}"
    fi
    ;;

  # === Media ===
  media-play)
    playerctl play 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;
  media-pause)
    playerctl pause 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;
  media-play-pause)
    playerctl play-pause 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;
  media-next)
    playerctl next 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;
  media-prev)
    playerctl previous 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;
  media-stop)
    playerctl stop 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;
  media-get)
    status=$(playerctl status 2>/dev/null || echo "stopped")
    artist=$(playerctl metadata artist 2>/dev/null || echo "")
    title=$(playerctl metadata title 2>/dev/null || echo "")
    printf '{"status":"ok","state":"%s","artist":"%s","title":"%s"}\n' "$status" "$artist" "$title"
    ;;

  # === Network ===
  network-status)
    ssid=$(iwgetid -r 2>/dev/null || echo "")
    if [ -n "$ssid" ]; then
      echo "{\"status\":\"ok\",\"wifi\":true,\"ssid\":\"$ssid\"}"
    else
      echo "{\"status\":\"ok\",\"wifi\":false,\"ssid\":\"\"}"
    fi
    ;;
  network-toggle-wifi)
    if nmcli radio wifi 2>/dev/null | grep -q enabled; then
      nmcli radio wifi off
      echo "{\"status\":\"ok\",\"enabled\":false}"
    else
      nmcli radio wifi on
      echo "{\"status\":\"ok\",\"enabled\":true}"
    fi
    ;;

  # === Workspace (labwc) ===
  workspace-list)
    labwc-workspaces 2>/dev/null | awk 'BEGIN{printf "{\"status\":\"ok\",\"workspaces\":["} {printf "%s\"%s\"", sep, $0; sep=","} END{printf "]}\n"}'
    ;;
  workspace-go)
    labwc-set-workspace "${2:-1}" 2>/dev/null || wlr-ctl workspace "${2:-1}" 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;
  workspace-next)
    labwc-workspaces 2>/dev/null | awk '/\*/ {active=$1; next} {last=$1} END{print active+1 > last?1:active+1}' | xargs -r labwc-set-workspace 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;

  # === Power ===
  power-lock)
    swaylock 2>/dev/null || gtklock 2>/dev/null || loginctl lock-session 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;
  power-logout)
    labwc --exit 2>/dev/null || pkill -x labwc 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;
  power-sleep)
    systemctl suspend 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;
  power-reboot)
    systemctl reboot 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;
  power-shutdown)
    systemctl poweroff 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;

  # === Clipboard ===
  clipboard-copy)
    wl-copy "${2:-}" 2>/dev/null || true
    echo "{\"status\":\"ok\"}"
    ;;
  clipboard-paste)
    content=$(wl-paste 2>/dev/null || echo "")
    echo "{\"status\":\"ok\",\"content\":\"$content\"}"
    ;;
  clipboard-get)
    content=$(wl-paste 2>/dev/null || echo "")
    echo "{\"status\":\"ok\",\"content\":\"$content\"}"
    ;;

  # === Screenshot ===
  screenshot-screen)
    grim - | wl-copy 2>/dev/null
    echo "{\"status\":\"ok\",\"target\":\"clipboard\"}"
    ;;
  screenshot-area)
    grim -g "$(slurp 2>/dev/null)" - | wl-copy 2>/dev/null
    echo "{\"status\":\"ok\",\"target\":\"clipboard\"}"
    ;;
  screenshot-window)
    grim -g "$(swaymsg -t get_tree 2>/dev/null | jq -r '.. | select(.focused?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"' 2>/dev/null || slurp 2>/dev/null)" - | wl-copy 2>/dev/null
    echo "{\"status\":\"ok\",\"target\":\"clipboard\"}"
    ;;

  # === System Info ===
  uptime)
    up=$(uptime -p 2>/dev/null | sed 's/up //' || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
    echo "{\"status\":\"ok\",\"uptime\":\"${up}\"}"
    ;;
  date-iso)
    echo "{\"status\":\"ok\",\"date\":\"$(date +%Y-%m-%d)\",\"time\":\"$(date +%H:%M:%S)\",\"weekday\":\"$(date +%A)\"}"
    ;;

  # === Help ===
  help|--help|-h|*)
    echo ""
    echo "== Widget Actions =="
    echo ""
    echo "Volume:"
    echo "  volume-up [%]       volume-down [%]     volume-set [%]"
    echo "  volume-mute         volume-get"
    echo ""
    echo "Microphone:"
    echo "  mic-mute            mic-get"
    echo ""
    echo "Brightness:"
    echo "  brightness-up [%]   brightness-down [%] brightness-get"
    echo ""
    echo "Media:"
    echo "  media-play          media-pause         media-play-pause"
    echo "  media-next          media-prev          media-stop"
    echo "  media-get"
    echo ""
    echo "Network:"
    echo "  network-status      network-toggle-wifi"
    echo ""
    echo "Workspace:"
    echo "  workspace-list      workspace-go N      workspace-next"
    echo ""
    echo "Power:"
    echo "  power-lock          power-logout        power-sleep"
    echo "  power-reboot        power-shutdown"
    echo ""
    echo "Clipboard:"
    echo "  clipboard-copy      clipboard-paste      clipboard-get"
    echo ""
    echo "Screenshot:"
    echo "  screenshot-screen   screenshot-area      screenshot-window"
    echo ""
    echo "Info:"
    echo "  uptime              date-iso"
    echo ""
    echo "All commands return JSON. Example:"
    echo "  $(basename "$0") volume-get"
    echo "  {\"status\":\"ok\",\"value\":75,\"muted\":false}"
    echo ""
    ;;
esac

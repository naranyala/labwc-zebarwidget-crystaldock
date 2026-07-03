#!/bin/bash
# Simple text-based panel for testing

# Show text system information
refresh=1  # seconds

while true; do
  # Clear and display system info
  clear
  echo "=== Simple Text Panel ==="
  echo "Time: $(date '+%H:%M:%S')"
  echo "CPU: $(cat /proc/loadavg | awk '{print $1}')"
  echo "Memory: $(free -h | awk '/Mem:/ {print $3"/"$2}')"
  echo "Network: $(ip route show default 2>/dev/null | awk '{print $3}' || echo 'N/A')"
  echo "Load: $(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')"
  echo
  echo "Press Ctrl+C to exit"
  sleep $refresh
done

# Simple startup script for labwc - starts sfwbar with minimal config
# Disables task manager control

sfwbar --config /home/naranyala/.config/sfwbar/sfwbar-minimal-config 2>/dev/null &
sleep 2
ps aux | grep sfwbar

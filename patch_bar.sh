#!/bin/bash
set -euo pipefail
# Patch zigshell-cairo-pango bar.c for glassmorphism
sed -i 's/old_style/glassmorphism/' sources/zigshell-cairo-pango/src/gui/bar.c

# OCWS Architectural Abstractions: Moving from Bash to C

To achieve the ultimate vision of **OCWS (Our C-Written Shell)**, the platform must transition away from brittle shell-script integration towards robust, memory-safe, and highly concurrent C/Zig-native abstractions. 

Here are the key architectural abstractions we should evaluate and implement next:

## 1. The Centralized State Broker (C-Native Daemon)
**Current Paradigm:** `ocws-daemon.sh` spawns background subshells running `inotifywait`, `pactl subscribe`, and `playerctl -F`. It then pipes text output to `ocws-emit.sh`, which forks a new `zigshell-cairo-pango -R` process for every single UI update. This is incredibly inefficient and prone to injection vulnerabilities.
**The OCWS Abstraction:** 
- Build a native C daemon (`ocws-brokerd`) using `libdbus` or `sd-bus`.
- This daemon natively subscribes to Pipewire events, UPower properties, and MPRIS metadata without spawning sub-processes.
- It maintains a single, persistent Unix Domain Socket connection to the `zigshell-cairo-pango` IPC socket, writing structured JSON or binary state changes instantaneously.

## 2. Configuration Abstraction Layer (Single Source of Truth)
**Current Paradigm:** A user's desktop state is scattered across `catppuccin-mocha.ini` (colors), `rc.xml` (window rules), `fuzzel.ini` (launcher), and `ocws.config` (panel). `theme-engine.sh` uses `sed` and `.tmpl` files to bridge the gap.
**The OCWS Abstraction:**
- Abstract all configuration into a single declarative file: `~/.config/ocws/config.json` or `config.yaml`.
- Create a C-binary called `ocws-config` that parses this unified file.
- The `ocws-config` binary natively generates the required XML, INI, and CSS outputs dynamically in memory, then writes them atomically to `~/.cache/ocws/`, completely replacing the bash templating engine.

## 3. The Unified UI Component API
**Current Paradigm:** Panel components (like volume or battery) are scattered `.widget` files loaded via `#include`. They have hardcoded layouts and duplicate logic.
**The OCWS Abstraction:**
- Abstract the panel into a generic "Component Container". 
- Create an API where C-native utilities (like `ocws-sysmon` or `ocws-battery`) can dynamically inject their own UI representations into the panel using GTK/Wayland protocols, rather than being statically defined in `ocws.config`.
- This allows the panel to adapt to exactly what binaries are installed on the system at runtime.

## 4. Key-Value Persistence API
**Current Paradigm:** `ocws-kv` reads/writes flat text files. Notification history and theme states are manually saved/loaded via bash scripts checking file existence.
**The OCWS Abstraction:**
- Abstract state persistence behind a lightweight embedded database (like SQLite or a fast C-native binary format).
- Create a shared C library (`libocws-state.so`) that any `ocws-*` binary can link against.
- This allows instant, transactional state reads/writes for themes, notifications, and DND modes without parsing text files.

## 5. Event-Driven IPC Framework
**Current Paradigm:** `ocws-emit.sh` requires manual escaping of string values (which previously caused IPC command injection bugs). 
**The OCWS Abstraction:**
- Create a standardized C header (`ocws_ipc.h`). 
- Binaries use `ocws_emit_string("Media.Title", title_str)` or `ocws_emit_int("System.Volume", 75)`.
- The library handles type safety, string sanitization, and socket connections under the hood, completely eliminating shell formatting bugs.

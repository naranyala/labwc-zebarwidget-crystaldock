# DankMaterialShell on OpenMandriva Linux — Manual Build & Install Guide

> **Why this guide exists:** DankMaterialShell (DMS) has no OpenMandriva package. The
> official one-liner installer (`curl -fsSL https://install.danklinux.com | sh`) only
> knows Arch / Fedora / Debian / openSUSE / Gentoo, so on OpenMandriva you must build the
> two native components yourself:
>
> 1. **Quickshell** (`quickshell` / `qs`) — the C++17/Qt6 QML runtime the shell runs on.
> 2. **DMS core** (`dms`) — the Go backend/CLI that launches Quickshell with the DMS config.
>
> The third piece — the QML shell config in `DankMaterialShell/quickshell/` — is just
> copied into place; no compilation needed.

Tested on OpenMandriva Cooker with Qt 6.9.0, Go 1.24, gcc 14.2 / clang 19.

---

## 0. Prerequisites

You need `sudo`, `git`, and a network connection (the build fetches `cpptrace` unless you
disable the crash handler — see Troubleshooting).

```bash
sudo dnf install -y git
```

---

## 1. Install build dependencies

OpenMandriva package names differ from Arch/Fedora. Use this single `dnf` command:

```bash
sudo dnf install -y \
  cmake extra-cmake-modules pkgconf \
  gcc-c++ clang \
  golang \
  lib64Qt6Core-devel lib64Qt6Gui-devel lib64Qt6Qml-devel lib64Qt6Quick-devel \
  lib64Qt6QuickControls2-devel lib64Qt6DBus-devel lib64Qt6Network-devel \
  lib64Qt6Svg lib64Qt6Svg-devel lib64Qt6ShaderTools-devel \
  lib64Qt6WaylandClient-devel lib64Qt6WaylandCompositor-devel \
  lib64Qt6OpenGL-devel lib64Qt6Widgets-devel lib64Qt6Multimedia-devel \
  lib64wayland-devel wayland-protocols-devel wayland-tools \
  libdrm-devel vulkan-headers libxkbcommon-devel \
  lib64spirv-tools-devel cli11-devel lib64jemalloc-devel \
  lib64pipewire-devel lib64pam-devel lib64polkit1-devel lib64glib2.0-devel
```

Notes:

- `wayland-tools` provides `/usr/bin/wayland-scanner` (required by Quickshell's build).
- `lib64Qt6Svg` is needed or SVG icons won't render.
- The Qt **private** headers Quickshell requires ship inside the `-devel` packages above
  (no separate `*-private-headers` package on OpenMandriva), so the default build is fine.

---

## 2. Build & install Quickshell

Clone or use the already-checked-out tree under `sources/quickshell`:

```bash
cd sources/quickshell

cmake -B build -S . \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DDISTRIBUTOR="OpenMandriva (manual)"

cmake --build build -j"$(nproc)"

sudo cmake --install build
```

This installs `quickshell` and a `qs` symlink into `/usr/local/bin`. Verify:

```bash
qs --version        # -> Quickshell 0.3.x
```

> **Crash handler / cpptrace:** the default build enables `-DCRASH_HANDLER=ON`, which
> downloads `cpptrace` via FetchContent at build time (needs internet). To build fully
> offline, add `-DCRASH_HANDLER=OFF` to the `cmake -B` line.

---

## 3. Build & install DMS core (`dms`)

The Go backend lives in `DankMaterialShell/core`:

```bash
cd sources/DankMaterialShell/core

make                 # builds ./bin/dms
sudo make install    # installs /usr/local/bin/dms
```

`make install` puts `dms` in `/usr/local/bin`. If you prefer a user-local install:

```bash
make
install -D -m 755 bin/dms ~/.local/bin/dms
```

Verify:

```bash
dms --help           # shows the ASCII banner + command list
```

(`dankinstall`, the interactive installer, is optional — `make dankinstall` builds it, but
for a manual setup you only need the `dms` binary.)

---

## 4. Deploy the QML shell config

`dms run` launches `qs -p <config>` where the config is the directory containing
`shell.qml`. DMS searches these locations (first hit wins):

```
~/.config/quickshell/dms/
/usr/local/share/quickshell/dms/
/usr/share/quickshell/dms/
/etc/xdg/quickshell/dms/
```

Copy the shell sources there (user-local is simplest and survives partial reinstalls):

```bash
mkdir -p ~/.config/quickshell/dms
cp -r sources/DankMaterialShell/quickshell/. ~/.config/quickshell/dms/
```

Confirm the entry point exists:

```bash
ls ~/.config/quickshell/dms/shell.qml
```

---

## 5. Run it

From a Wayland session (e.g. labwc):

```bash
dms run                 # foreground, logs to terminal
dms run -d              # daemon mode (background)
dms run --session      # when launched as a session/systemd unit
```

Restart the shell after config edits:

```bash
dms restart             # or send SIGUSR1 to the dms process
```

Quit: `Ctrl-C` in foreground, or `pkill dms`.

---

## 6. Autostart under labwc

Add DMS to `~/.config/labwc/autostart` so it starts at login. Insert before any
`lxqt-panel`/`zigshell-cairo-pango` lines if you run those too:

```sh
# ~/.config/labwc/autostart
dms run -d &
```

For a systemd-user unit instead, use the bundled template:

```bash
mkdir -p ~/.config/systemd/user
cp sources/DankMaterialShell/assets/systemd/dms.service ~/.config/systemd/user/
sed -i 's|ExecStart=.*|ExecStart=/usr/local/bin/dms run --session|' \
  ~/.config/systemd/user/dms.service
systemctl --user enable --now dms.service
```

> DMS needs a Wayland compositor that supports `wlr-layer-shell-unstable-v1`
> (labwc does). No extra env vars are required — `dms run` sets `QT_QPA_PLATFORM` and
> `WAYLAND_DISPLAY` handling itself.

---

## 7. Updating / rebuilding

```bash
# Quickshell
cd sources/quickshell && git pull && cmake --build build -j"$(nproc)" && sudo cmake --install build

# DMS core
cd sources/DankMaterialShell && git pull
cd core && make && sudo make install

# Shell config (always re-copy — it changes often)
cp -r sources/DankMaterialShell/quickshell/. ~/.config/quickshell/dms/
dms restart
```

> Because Quickshell links against Qt **private** APIs, rebuild it after any Qt upgrade,
> or it will crash with an ABI mismatch.

---

## 8. Troubleshooting

| Symptom | Cause / Fix |
|---|---|
| `qs: command not found` | Quickshell didn't install, or `/usr/local/bin` not on `PATH`. Re-run `sudo cmake --install build`. |
| `Could not find DMS config (shell.qml)` | Step 4 copy missed `shell.qml`, or it landed in the wrong dir. Re-copy `quickshell/` into `~/.config/quickshell/dms/`. |
| `wayland-scanner: command not found` during Quickshell build | Install `wayland-tools`. |
| Build fails fetching `cpptrace` (no internet) | Add `-DCRASH_HANDLER=OFF` to the Quickshell `cmake -B` line. |
| Quickshell crashes right after a Qt upgrade | Rebuild Quickshell (Step 7) — private Qt ABI changed. |
| Blank/garbled icons | Install `lib64Qt6Svg` (and `librsvg` if missing). |
| `dms run` starts but nothing shows on labwc | Ensure labwc provides layer-shell; check `dms run` stderr / `~/.cache/dms` logs. |

---

## 9. Uninstall

```bash
sudo cmake --build sources/quickshell/build --target uninstall 2>/dev/null || \
  sudo rm -f /usr/local/bin/quickshell /usr/local/bin/qs
sudo rm -f /usr/local/bin/dms
rm -rf ~/.config/quickshell/dms
```

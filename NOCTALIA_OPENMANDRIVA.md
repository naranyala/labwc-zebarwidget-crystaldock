# Noctalia on OpenMandriva Linux — Manual Build & Install Guide

> **Why this guide exists:** Noctalia has no OpenMandriva package. The project ships no
> distro-agnostic one-liner installer, so on OpenMandriva you build it yourself from source.
>
> Noctalia is a **native Wayland desktop shell** (bars, launcher, notifications, lock screen,
> wallpaper, control center) built directly on Wayland + OpenGL ES with no Qt/GTK dependency.
> It speaks `wlr-layer-shell-unstable-v1` and has a dedicated **labwc** workspace backend, so
> it works on labwc out of the box.

Tested on OpenMandriva Cooker with gcc 14.2 (C++23), meson 1.7, ninja 1.12, Qt-free toolchain.

---

## 0. Prerequisites

You need `sudo`, `git`, and a C++23-capable compiler (gcc ≥ 13 or clang ≥ 16 — OpenMandriva's
gcc 14.2 is fine).

```bash
sudo dnf install -y git
```

---

## 1. Install build dependencies

OpenMandriva package names differ from Arch/Fedora. One `dnf` command:

```bash
sudo dnf install -y \
  meson ninja pkgconf gcc-c++ \
  lib64wayland-devel wayland-protocols-devel wayland-tools \
  lib64glvnd-devel lib64EGL_mesa-devel \
  lib64freetype6-devel lib64fontconfig-devel \
  lib64cairo-devel lib64pango1.0-devel lib64pangocairo1.0-devel \
  lib64pangoft2_1.0-devel lib64harfbuzz-devel \
  lib64rsvg2-devel libxkbcommon-devel lib64glib2.0-devel \
  lib64polkit1-devel lib64pipewire-devel lib64wireplumber-devel \
  lib64curl-devel lib64qalculate-devel lib64xml2-devel \
  lib64md4c-devel nlohmann_json-devel lib64tomlplusplus-devel \
  lib64pam-devel lib64jemalloc-devel lib64webp-devel
```

Notes:

- `wayland-tools` provides `/usr/bin/wayland-scanner` (used to generate the Wayland protocol bindings).
- `lib64glvnd-devel` is what actually provides the `egl` and `glesv2` pkg-config files Noctalia links against; `lib64EGL_mesa-devel` adds the Mesa EGL bits.
- The `stb` image headers Noctalia needs are **vendored** in the repo (`third_party/`), so no `stb` package is required.
- Optional convenience runner `just` is **not** needed — the commands below use `meson`/`ninja` directly.

---

## 2. Clone & build

```bash
git clone --depth=1 --branch main https://github.com/noctalia-dev/noctalia.git sources/noctalia
cd sources/noctalia

# Configure a release build (C++23, LTO on)
meson setup build-release \
  --buildtype=release \
  -Dcpp_std=c++23 \
  -Db_lto=true \
  --prefix=/usr/local

# Compile (this is large + LTO is slow — see note)
meson compile -C build-release

# Install
sudo meson install -C build-release
```

> **Build time note:** `-Db_lto=true` (the default for release) makes linking *very* slow
> (expect 30–90+ min on the final LTO link for the full binary). For a much faster,
> non-LTO debug-ish build use:
> ```bash
> meson setup build-fast --buildtype=release -Dcpp_std=c++23 -Db_lto=false --prefix=/usr/local
> meson compile -C build-fast
> sudo meson install -C build-fast
> ```
> You can reconfigure an existing dir with `meson setup build-release --reconfigure`.

Verify the binary:

```bash
noctalia --version     # -> noctalia v5.0.0 (...)
```

This installs `noctalia` to `/usr/local/bin`, plus assets in `/usr/local/share/noctalia`,
the desktop file in `/usr/local/share/applications`, and the icon in
`/usr/local/share/icons/hicolor/scalable/apps`.

---

## 3. Run it

From a Wayland session (labwc, Hyprland, Sway, …):

```bash
noctalia            # foreground
noctalia -d         # daemon mode (background)
```

On first launch Noctalia writes its config to `~/.config/noctalia/` (auto-generated with
sensible defaults — you don't need to pre-create it).

IPC / control from the command line:

```bash
noctalia msg --help     # send commands to a running instance
noctalia theme <img>    # generate a palette from an image
noctalia config --help  # validate / replay config
```

Restart after editing config: quit and re-run, or `noctalia msg` if your instance supports it.

---

## 4. Autostart under labwc

Add Noctalia to `~/.config/labwc/autostart` so it starts at login (put it alongside any
`lxqt-panel`/`zigshell-cairo-pango` lines you already have):

```sh
# ~/.config/labwc/autostart
noctalia -d &
```

For a systemd-user unit instead:

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/noctalia.service <<'EOF'
[Unit]
Description=Noctalia Wayland shell
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/local/bin/noctalia -d
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF
systemctl --user enable --now noctalia.service
```

> No special env vars are required under labwc — Noctalia auto-detects the compositor and
> selects its `labwc` workspace backend. It needs a compositor that provides layer-shell.

---

## 5. Updating / rebuilding

```bash
cd sources/noctalia
git pull
meson compile -C build-release        # rebuilds only changed files
sudo meson install -C build-release   # re-deploys binary + assets
```

If you pulled a large change and the build dir gets confused:

```bash
meson setup build-release --reconfigure
```

---

## 6. Troubleshooting

| Symptom | Cause / Fix |
|---|---|
| `noctalia: command not found` | Install step didn't run, or `/usr/local/bin` not on `PATH`. Re-run `sudo meson install -C build-release`. |
| `ERROR: C++23 ... not supported` | Compiler too old. Install `gcc-c++` (≥ 13) and reconfigure. |
| `Dependency 'glesv2' not found` | Install `lib64glvnd-devel`. |
| `Program 'wayland-scanner' not found` | Install `wayland-tools`. |
| Build dies on the final link (OOM) | LTO link is memory-heavy. Use `-Db_lto=false` (Step 2 note) or add swap. |
| Shell doesn't appear on labwc | Ensure labwc provides layer-shell; check `noctalia --version` and `~/.config/noctalia` logs. |
| Blank/garbled icons or images | Install `lib64rsvg2-devel` + `lib64webp-devel` (runtime libs pull in automatically). |

---

## 7. Uninstall

```bash
sudo meson install -C build-release --reconfigure 2>/dev/null
sudo ninja -C build-release uninstall 2>/dev/null || \
  sudo rm -f /usr/local/bin/noctalia
sudo rm -rf /usr/local/share/noctalia \
            /usr/local/share/applications/dev.noctalia.Noctalia.desktop \
            /usr/local/share/icons/hicolor/scalable/apps/noctalia.svg
# optional: rm -rf ~/.config/noctalia
```

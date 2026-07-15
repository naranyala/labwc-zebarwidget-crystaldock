# Installing Noctalia Shell on OpenMandriva Linux

A complete guide for building and installing [Noctalia Shell](https://gitlab.com/noctalia-dev/noctalia-shell) on OpenMandriva Linux, where it is not available as a package and must be built from source with manual patches.

## Overview

Noctalia Shell is a modern, minimalist Wayland shell built with C++23 and Qt6. It provides a bar, dock, notifications, OSD, lock screen, and desktop widgets — all in a single binary.

**What we're building:**
1. **Noctalia Shell** — the full shell binary (from source, ~920 build targets)
2. **Missing dependencies** — patched or built from source for OpenMandriva compatibility

**Time estimate:** ~20-40 minutes depending on your hardware.

---

## Prerequisites

### System Requirements
- OpenMandriva Lx 6.0 (Vanadium Rock) or newer
- A Wayland compositor (labwc, Hyprland, sway, etc.)
- ~3GB free disk space for build artifacts
- Internet connection
- Clang 19+ or GCC 14+ (for C++23 support)

### Required Packages

Install the build toolchain and development packages:

```bash
# Build tools
sudo dnf install -y \
    cmake meson ninja-build gcc-c++ clang lld \
    pkgconf-pkg-config git just

# Qt6 development packages
sudo dnf install -y \
    lib64Qt6Core-devel lib64Qt6Gui-devel lib64Qt6Qml-devel \
    lib64Qt6Quick-devel lib64Qt6QuickControls2-devel \
    lib64Qt6Widgets-devel lib64Qt6ShaderTools-devel \
    lib64Qt6WaylandClient-devel lib64Qt6DBus-devel \
    lib64Qt6Network-devel lib64Qt6Test-devel \
    lib64Qt6Svg-devel lib64Qt6Multimedia-devel

# Wayland dependencies
sudo dnf install -y \
    lib64wayland-devel wayland-protocols-devel \
    lib64vulkan-devel spirv-tools glslang

# System libraries
sudo dnf install -y \
    lib64sdbus-cpp-devel lib64jemalloc-devel \
    lib64pipewire-devel lib64pam-devel \
    lib64freetype-devel lib64fontconfig-devel \
    lib64libinput-devel lib64libudev-devel \
    lib64wlroots-devel
```

> **Note:** If `just` is not in the repos, install it manually:
> ```bash
> curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin
> ```

---

## Step 1: Patch Missing Dependencies

Noctalia needs two things that OpenMandriva doesn't ship yet:

### 1.1 Install `stb_image_resize2.h` (v2)

OpenMandriva's `stb-devel` only ships v1. Noctalia needs v2:

```bash
# Download stb_image_resize2.h v2.18 from upstream
sudo curl -fsSL -o /usr/include/stb/stb_image_resize2.h \
    https://raw.githubusercontent.com/nothings/stb/master/stb_image_resize2.h
```

### 1.2 Install `ext-background-effect-v1.xml` Wayland protocol

This staging protocol isn't in OpenMandriva's `wayland-protocols` package yet:

```bash
# Create directory
sudo mkdir -p /usr/share/wayland-protocols/staging/ext-background-effect

# Download the protocol XML
sudo curl -fsSL -o /usr/share/wayland-protocols/staging/ext-background-effect/ext-background-effect-v1.xml \
    https://gitlab.freedesktop.org/wayland/wayland-protocols/-/raw/main/staging/ext-background-effect/ext-background-effect-v1.xml
```

---

## Step 2: Clone Noctalia Source

```bash
mkdir -p ~/sources
cd ~/sources
git clone --depth=1 https://gitlab.com/noctalia-dev/noctalia-shell.git noctalia
cd noctalia
```

---

## Step 3: Configure the Build

Noctalia uses Meson. Configure a release build:

```bash
meson setup build \
    --prefix=/usr/local \
    --buildtype=release \
    -Dcpp_std=c++23 \
    -Dclang=true
```

**If you prefer GCC instead of Clang:**
```bash
meson setup build \
    --prefix=/usr/local \
    --buildtype=release \
    -Dcpp_std=c++23 \
    -Dclang=false
```

**If configuration fails**, check the error output. Common fixes:
- Missing `sdbus-c++`: `sudo dnf install lib64sdbus-cpp-devel`
- Missing `stb_image_resize2.h`: see Step 1.1
- Missing `ext-background-effect-v1.xml`: see Step 1.2

---

## Step 4: Build Noctalia

This is the longest step — ~920 build targets, takes 15-30 minutes:

```bash
ninja -C build -j$(nproc)
```

**If the build gets killed** (OOM or timeout), reduce parallelism:
```bash
ninja -C build -j2
```

**If a specific file fails to compile**, check the error and ensure all dependencies are installed.

---

## Step 5: Install Noctalia

```bash
# Using just (recommended)
just install

# Or manually with ninja
sudo ninja -C build install
```

This installs the `noctalia` binary to `/usr/local/bin/noctalia`.

---

## Step 6: Verify Installation

```bash
noctalia --version
```

You should see something like:
```
Noctalia Shell v5.0.0
```

---

## Step 7: Configure Noctalia

### 7.1 Create the configuration directory

```bash
mkdir -p ~/.config/noctalia
```

### 7.2 Deploy the default configuration

Copy the OCWS default config:

```bash
cp /path/to/labwc-fuzzel-zigshell-cairo-pango/dotfiles/noctalia/config.toml \
   ~/.config/noctalia/config.toml
```

Or create a minimal config:

```bash
cat > ~/.config/noctalia/config.toml << 'EOF'
[shell]
ui_scale = 1.0

[bar.main]
position = "top"
thickness = 34

[theme]
mode = "dark"
source = "builtin"
builtin = "Noctalia"
EOF
```

---

## Step 8: Launch Noctalia

### 8.1 Start Noctalia

```bash
noctalia &
```

### 8.2 Kill Noctalia (if needed)

```bash
pkill noctalia
```

### 8.3 Restart Noctalia

```bash
pkill noctalia; sleep 0.5; noctalia &
```

---

## Step 9: Autostart (Optional)

To auto-launch Noctalia when your Wayland compositor starts:

### For labwc

Edit `~/.config/labwc/autostart`:

```bash
# Noctalia Shell
if command -v noctalia >/dev/null 2>&1; then
    noctalia &
fi
```

### For Hyprland

Add to `~/.config/hypr/hyprland.conf`:

```
exec-once = noctalia
```

---

## Troubleshooting

### "noctalia: command not found"

Noctalia was installed to `/usr/local/bin/`. Make sure this is in your PATH:

```bash
export PATH="/usr/local/bin:$PATH"
```

Add this to `~/.bashrc` or `~/.zshrc` permanently.

### Build fails with "stb_image_resize2.h not found"

OpenMandriva's `stb-devel` only has v1. Install v2 manually (see Step 1.1).

### Build fails with "ext-background-effect-v1.xml not found"

The staging protocol isn't packaged yet. Install it manually (see Step 1.2).

### Build fails with "sdbus-c++ not found"

```bash
sudo dnf install lib64sdbus-cpp-devel
```

### Build fails with "just not found"

```bash
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin
```

### Build gets killed (OOM)

Reduce parallelism:
```bash
ninja -C build -j2
```

### Noctalia starts but shows a blank bar

1. Check the terminal output for errors
2. Verify the config file exists:
   ```bash
   ls ~/.config/noctalia/config.toml
   ```
3. Try running with verbose output:
   ```bash
   noctalia --verbose
   ```

### Noctalia doesn't auto-hide the bar

Check your config:
```toml
[bar.main]
auto_hide = true
```

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `noctalia &` | Start Noctalia |
| `pkill noctalia` | Stop Noctalia |
| `noctalia --version` | Check version |
| `noctalia --verbose` | Run with verbose output |
| `noctalia msg <command>` | Send IPC command |

### IPC Commands

```bash
noctalia msg launcher toggle      # Toggle app launcher
noctalia msg control-center toggle # Toggle control center
noctalia msg session lock          # Lock screen
noctalia msg notification-clear    # Clear notifications
noctalia msg clipboard-clear       # Clear clipboard
noctalia msg wallpaper-next        # Next wallpaper
noctalia msg theme-toggle          # Toggle dark/light theme
```

---

## File Locations

| File | Path |
|------|------|
| Noctalia binary | `/usr/local/bin/noctalia` |
| Configuration | `~/.config/noctalia/config.toml` |
| Theme cache | `~/.config/noctalia/theme.json` |
| Wallpapers | `~/Pictures/Wallpapers/` |

---

## Credits

- [Noctalia Shell](https://gitlab.com/noctalia-dev/noctalia-shell) by Noctalia Dev
- OCWS integration by the OCWS project

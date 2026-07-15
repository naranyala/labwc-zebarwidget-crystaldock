# Installing DankMaterialShell on OpenMandriva Linux

A complete guide for building and installing [DankMaterialShell (DMS)](https://github.com/DankShrine/dms) on OpenMandriva Linux, where quickshell and DMS are not available as packages and must be built from source.

## Overview

DankMaterialShell is a Material Design 3 shell for Wayland compositors. It runs on top of [quickshell](https://github.com/quickshell-mirror/quickshell), a Qt6/QML-based shell framework. OpenMandriva does not package either tool, so both must be built from source.

**What we're building:**
1. **quickshell** — the QML shell runtime (from source)
2. **DankMaterialShell (DMS)** — the Material 3 shell (from source)

**Time estimate:** ~15-30 minutes depending on your hardware.

---

## Prerequisites

### System Requirements
- OpenMandriva Lx 6.0 (or newer)
- A Wayland compositor (labwc, Hyprland, sway, etc.)
- ~2GB free disk space for build artifacts
- Internet connection

### Required Packages

Install the build toolchain and Qt6 development packages first:

```bash
# Build tools
sudo dnf install -y cmake ninja-build gcc-c++ g++ pkgconf-pkg-config git

# Qt6 development packages
sudo dnf install -y \
    lib64Qt6Core-devel lib64Qt6Gui-devel lib64Qt6Qml-devel \
    lib64Qt6Quick-devel lib64Qt6QuickControls2-devel \
    lib64Qt6Widgets-devel lib64Qt6ShaderTools-devel \
    lib64Qt6WaylandClient-devel lib64Qt6DBus-devel \
    lib64Qt6Network-devel lib64Qt6Test-devel

# Wayland and Vulkan dependencies
sudo dnf install -y \
    lib64wayland-devel wayland-protocols-devel \
    lib64vulkan-devel spirv-tools

# Miscellaneous dependencies
sudo dnf install -y \
    lib64jemalloc-devel lib64pipewire-devel \
    lib64pam-devel
```

> **Note:** If some `lib64*` packages are not found, try the non-lib64 variants (e.g., `Qt6Core-devel` instead of `lib64Qt6Core-devel`). OpenMandriva sometimes uses different naming conventions across releases.

---

## Step 1: Build quickshell from Source

### 1.1 Clone the repository

```bash
mkdir -p ~/sources
cd ~/sources
git clone --depth=1 https://github.com/quickshell-mirror/quickshell.git
cd quickshell
```

### 1.2 Configure the build

```bash
cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DDISTRIBUTOR="OCWS" \
    -DCMAKE_PREFIX_PATH=/usr/local \
    -DVENDOR_CPPTRACE=ON \
    -DNO_PCH=ON
```

**Optional flags** (enable/disable based on what you have):
```bash
# Disable crash handler if cpptrace is not available
-DCRASH_HANDLER=OFF

# Disable PipeWire if not needed
-DSERVICE_PIPEWIRE=OFF
```

### 1.3 Build and install

```bash
# Build (adjust -j to match your CPU cores)
cmake --build build -j$(nproc)

# Install (requires root)
sudo cmake --install build
```

### 1.4 Verify

```bash
quickshell --version
```

You should see something like:
```
quickshell 0.1.0 (or similar version string)
```

### 1.5 Remove old package (if installed)

If you previously installed quickshell from OpenMandriva repos, remove it to avoid conflicts:

```bash
sudo dnf remove quickshell
```

---

## Step 2: Build DankMaterialShell from Source

### 2.1 Clone the repository

```bash
cd ~/sources
git clone --depth=1 https://github.com/DankShrine/dms.git
cd dms
```

### 2.2 Build DMS

DMS uses a simple Makefile:

```bash
make -j$(nproc)
```

### 2.3 Install DMS

```bash
sudo make install
```

This installs the `dms` binary to `/usr/local/bin/dms`.

### 2.4 Verify

```bash
dms --version
```

You should see the DMS version number.

---

## Step 3: Configure DMS

### 3.1 Create the configuration directory

DMS looks for its QML shell files in `~/.local/share/quickshell/dms/`:

```bash
mkdir -p ~/.local/share/quickshell/dms
mkdir -p ~/.config/quickshell
```

### 3.2 Deploy DMS files

The `make install` step should have installed the QML files to `~/.local/share/quickshell/dms/`. Verify:

```bash
ls ~/.local/share/quickshell/dms/shell.qml
```

If the file exists, create a symlink so `dms run` can find it:

```bash
ln -sf ~/.local/share/quickshell/dms ~/.config/quickshell/dms
```

### 3.3 Deploy settings (optional)

If you have a custom `settings.json`, deploy it:

```bash
cp settings.json ~/.local/share/quickshell/dms/settings.json
```

Or use the OCWS default settings:

```bash
cp /path/to/labwc-fuzzel-zigshell-cairo-pango/dotfiles/DankMaterialShell/settings.json \
   ~/.local/share/quickshell/dms/settings.json
```

---

## Step 4: Fix the AppId Pragma Issue

**This is the most common issue on OpenMandriva.** The DMS `shell.qml` file contains a pragma that older quickshell versions don't recognize:

```
//@ pragma AppId com.danklinux.dms
```

If you see this error:
```
ERROR: Unrecognized pragma 'AppId com.danklinux.dms'
ERROR go: quickshell exited: exit status 255
```

### Solution: Comment out the pragma

```bash
sed -i 's|^//@ pragma AppId|// //@ pragma AppId|' \
    ~/.local/share/quickshell/dms/shell.qml
```

Or manually edit `~/.local/share/quickshell/dms/shell.qml` and comment out line 10:

```qml
// //@ pragma AppId com.danklinux.dms
```

> **Note:** This pragma is only needed for app ID matching on supported quickshell versions. Commenting it out has no functional impact on DMS.

---

## Step 5: Launch DMS

### 5.1 Start DMS

```bash
dms run &
```

### 5.2 Kill DMS (if needed)

```bash
dms kill
```

### 5.3 Restart DMS

```bash
dms kill && sleep 0.5 && dms run &
```

---

## Step 6: Autostart (Optional)

To auto-launch DMS when your Wayland compositor starts, add it to your autostart file.

For **labwc**, edit `~/.config/labwc/autostart`:

```bash
# DankMaterialShell
if command -v dms >/dev/null 2>&1; then
    nohup dms run >/dev/null 2>&1 &
fi
```

For **Hyprland**, add to `~/.config/hypr/hyprland.conf`:

```
exec-once = dms run
```

---

## Troubleshooting

### "dms: command not found"

DMS was installed to `/usr/local/bin/`. Make sure this is in your PATH:

```bash
export PATH="/usr/local/bin:$PATH"
```

Add this to `~/.bashrc` or `~/.zshrc` permanently.

### "quickshell: command not found"

Same as above — quickshell is installed to `/usr/local/bin/`.

### DMS starts but shows a blank bar

1. Check that DMS found its QML files:
   ```bash
   dms kill
   dms run  # watch the terminal output for errors
   ```

2. Verify the symlink exists:
   ```bash
   ls -la ~/.config/quickshell/dms
   ```

3. Check that `shell.qml` exists:
   ```bash
   ls ~/.local/share/quickshell/dms/shell.qml
   ```

### "Module not found" errors in QML

DMS may need additional QML modules. Install them:

```bash
sudo dnf install -y lib64Qt6QuickControls2-devel
```

Or build the missing module from source if not packaged.

### Permission errors during build

Make sure you have sudo access. The `cmake --install` and `make install` steps require root.

### Build fails with "Qt6 not found"

Ensure all Qt6 development packages are installed:

```bash
sudo dnf install -y lib64Qt6Core-devel lib64Qt6Gui-devel lib64Qt6Qml-devel
```

### DMS theme not applying

DMS uses [matugen](https://github.com/InboxDev/matugen) for Material You color extraction. Install it:

```bash
# From AUR or build from source
cargo install matugen
```

Or disable matugen in DMS settings:
```json
{
  "runUserMatugenTemplates": false
}
```

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `dms run` | Start DMS |
| `dms kill` | Stop DMS |
| `dms kill && dms run` | Restart DMS |
| `quickshell --version` | Check quickshell version |
| `dms --version` | Check DMS version |

---

## File Locations

| File | Path |
|------|------|
| DMS binary | `/usr/local/bin/dms` |
| quickshell binary | `/usr/local/bin/quickshell` |
| DMS QML files | `~/.local/share/quickshell/dms/` |
| DMS config symlink | `~/.config/quickshell/dms` → `~/.local/share/quickshell/dms` |
| DMS settings | `~/.local/share/quickshell/dms/settings.json` |
| DMS entry point | `~/.local/share/quickshell/dms/shell.qml` |

---

## Credits

- [DankMaterialShell](https://github.com/DankShrine/dms) by DankShrine
- [quickshell](https://github.com/quickshell-mirror/quickshell) by quickshell-mirror
- OCWS (Open Compositor Widget Shell) integration by the OCWS project

# Noctalia Shell Installation Guide for OpenMandriva Linux

This document provides a comprehensive procedure for compiling and installing the Noctalia Shell on OpenMandriva Linux. As Noctalia Shell is not currently distributed as a pre-compiled package for this distribution, it must be built from the source code, requiring specific manual patching to resolve dependency discrepancies.

## 1. Overview

Noctalia Shell is an advanced, minimalist Wayland shell developed using C++23 and Qt6. It consolidates several desktop components—including a status bar, application dock, notification daemon, on-screen display (OSD), lock screen, and desktop widgets—into a single binary executable.

**Objectives of this Guide:**
1. **Compile Noctalia Shell:** Build the comprehensive shell binary from source (comprising approximately 920 build targets).
2. **Resolve Dependencies:** Manually patch or compile missing dependencies required for OpenMandriva compatibility.

**Estimated Duration:** 20 to 40 minutes, contingent upon system specifications.

---

## 2. Prerequisites

### 2.1 System Requirements
- Operating System: OpenMandriva Lx 6.0 (Vanadium Rock) or later.
- Display Server: A Wayland-compatible compositor (e.g., labwc, Hyprland, sway).
- Storage: Minimum 3 GB of available disk space for build artifacts.
- Network: Active internet connection.
- Compiler: Clang 19+ or GCC 14+ (to ensure C++23 standard support).

### 2.2 Required Packages

Execute the following commands to install the necessary build toolchain and development libraries:

```bash
# Install core build tools
sudo dnf install -y \
    cmake meson ninja-build gcc-c++ clang lld \
    pkgconf-pkg-config git just

# Install Qt6 development frameworks
sudo dnf install -y \
    lib64Qt6Core-devel lib64Qt6Gui-devel lib64Qt6Qml-devel \
    lib64Qt6Quick-devel lib64Qt6QuickControls2-devel \
    lib64Qt6Widgets-devel lib64Qt6ShaderTools-devel \
    lib64Qt6WaylandClient-devel lib64Qt6DBus-devel \
    lib64Qt6Network-devel lib64Qt6Test-devel \
    lib64Qt6Svg-devel lib64Qt6Multimedia-devel

# Install Wayland and Vulkan dependencies
sudo dnf install -y \
    lib64wayland-devel wayland-protocols-devel \
    lib64vulkan-devel spirv-tools glslang

# Install essential system libraries
sudo dnf install -y \
    lib64sdbus-cpp-devel lib64jemalloc-devel \
    lib64pipewire-devel lib64pam-devel \
    lib64freetype-devel lib64fontconfig-devel \
    lib64libinput-devel lib64libudev-devel \
    lib64wlroots-devel
```

**Note:** If the `just` command runner is unavailable in the standard repositories, it can be installed manually:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin
```

---

## 3. Dependency Patching

Noctalia requires specific components that are not currently provided by OpenMandriva's default repositories.

### 3.1 Install `stb_image_resize2.h` (Version 2)

The OpenMandriva `stb-devel` package includes version 1. Noctalia requires version 2:

```bash
# Download stb_image_resize2.h v2.18 directly from the upstream repository
sudo curl -fsSL -o /usr/include/stb/stb_image_resize2.h \
    https://raw.githubusercontent.com/nothings/stb/master/stb_image_resize2.h
```

### 3.2 Install `ext-background-effect-v1.xml` Protocol

This Wayland staging protocol is absent from the current `wayland-protocols` package:

```bash
# Create the requisite directory structure
sudo mkdir -p /usr/share/wayland-protocols/staging/ext-background-effect

# Download the protocol XML specification
sudo curl -fsSL -o /usr/share/wayland-protocols/staging/ext-background-effect/ext-background-effect-v1.xml \
    https://gitlab.freedesktop.org/wayland/wayland-protocols/-/raw/main/staging/ext-background-effect/ext-background-effect-v1.xml
```

---

## 4. Source Code Acquisition

Clone the Noctalia source repository:

```bash
mkdir -p ~/sources
cd ~/sources
git clone --depth=1 https://gitlab.com/noctalia-dev/noctalia-shell.git noctalia
cd noctalia
```

---

## 5. Build Configuration

Noctalia utilizes the Meson build system. Configure the project for a release build:

```bash
meson setup build \
    --prefix=/usr/local \
    --buildtype=release \
    -Dcpp_std=c++23 \
    -Dclang=true
```

**Alternative Configuration (GCC):**
If GCC is preferred over Clang, use the following configuration:
```bash
meson setup build \
    --prefix=/usr/local \
    --buildtype=release \
    -Dcpp_std=c++23 \
    -Dclang=false
```

**Configuration Troubleshooting:**
Should the configuration fail, review the error log. Common resolutions include:
- Missing `sdbus-c++`: Execute `sudo dnf install lib64sdbus-cpp-devel`.
- Missing `stb_image_resize2.h`: Refer to Section 3.1.
- Missing `ext-background-effect-v1.xml`: Refer to Section 3.2.

---

## 6. Compilation

Initiate the compilation process. This operation involves approximately 920 targets and may take 15 to 30 minutes.

```bash
ninja -C build -j$(nproc)
```

**Mitigating Resource Exhaustion:**
If the build process terminates unexpectedly (e.g., due to Out-Of-Memory conditions), reduce the concurrency level:
```bash
ninja -C build -j2
```

---

## 7. Installation

Deploy the compiled binaries to the system:

```bash
# Using the 'just' command runner (recommended)
just install

# Alternatively, using ninja directly
sudo ninja -C build install
```

This procedure installs the executable to `/usr/local/bin/noctalia`.

---

## 8. Verification

Confirm the successful installation by checking the application version:

```bash
noctalia --version
```

The output should resemble:
```
Noctalia Shell v5.0.0
```

---

## 9. Configuration Deployment

### 9.1 Initialize Configuration Directory

```bash
mkdir -p ~/.config/noctalia
```

### 9.2 Deploy Default Configuration

Copy the default configuration file:

```bash
cp /path/to/labwc-fuzzel-zigshell-cairo-pango/dotfiles/noctalia/config.toml \
   ~/.config/noctalia/config.toml
```

Alternatively, create a minimal configuration:

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

## 10. Operational Guidelines

### 10.1 Initialization

```bash
noctalia &
```

### 10.2 Termination

```bash
pkill noctalia
```

### 10.3 Service Restart

```bash
pkill noctalia; sleep 0.5; noctalia &
```

---

## 11. Autostart Configuration

To initialize Noctalia automatically with the Wayland compositor:

### 11.1 labwc Integration

Append the following to `~/.config/labwc/autostart`:

```bash
# Noctalia Shell Initialization
if command -v noctalia >/dev/null 2>&1; then
    noctalia &
fi
```

### 11.2 Hyprland Integration

Append the following to `~/.config/hypr/hyprland.conf`:

```
exec-once = noctalia
```

---

## 12. Troubleshooting Reference

### 12.1 "Command Not Found" Error
Ensure `/usr/local/bin/` is included in the system PATH:
```bash
export PATH="/usr/local/bin:$PATH"
```
Append this line to `~/.bashrc` or `~/.zshrc` for persistence.

### 12.2 Blank Interface Rendering
1. Inspect the terminal output for initialization errors.
2. Verify the configuration file exists: `ls ~/.config/noctalia/config.toml`.
3. Execute with verbose logging: `noctalia --verbose`.

### 12.3 Auto-hide Malfunction
Verify the configuration directive:
```toml
[bar.main]
auto_hide = true
```

---

## 13. Command Reference

| Command | Description |
|---------|-------------|
| `noctalia &` | Initialize the shell process |
| `pkill noctalia` | Terminate the shell process |
| `noctalia --version` | Display application version |
| `noctalia --verbose` | Execute with detailed diagnostic logging |
| `noctalia msg <command>` | Transmit Inter-Process Communication (IPC) command |

### 13.1 IPC Directives

```bash
noctalia msg launcher toggle      # Toggle application launcher visibility
noctalia msg control-center toggle # Toggle control center visibility
noctalia msg session lock          # Secure current session
noctalia msg notification-clear    # Purge notification history
noctalia msg clipboard-clear       # Clear clipboard buffer
noctalia msg wallpaper-next        # Advance desktop background
noctalia msg theme-toggle          # Alternate visual theme
```

---

## 14. File Architecture

| Component | Path |
|-----------|------|
| Executable Binary | `/usr/local/bin/noctalia` |
| Primary Configuration | `~/.config/noctalia/config.toml` |
| Theme Cache Data | `~/.config/noctalia/theme.json` |
| Wallpaper Directory | `~/Pictures/Wallpapers/` |

# Deployment Guide: DankMaterialShell on OpenMandriva Linux

This document provides a comprehensive procedure for the compilation and installation of [DankMaterialShell (DMS)](https://github.com/DankShrine/dms) within an OpenMandriva Linux environment. Due to the absence of pre-compiled packages for both `quickshell` and DMS in the standard OpenMandriva repositories, manual compilation from source is required.

## Executive Summary

DankMaterialShell is a Material Design 3 interface for Wayland compositors, operating on the [quickshell](https://github.com/quickshell-mirror/quickshell) Qt6/QML framework. As neither component is packaged for OpenMandriva, this guide details the build process for both.

**Deployment Objectives:**
1. **quickshell**: The foundational QML shell runtime (compiled from source).
2. **DankMaterialShell (DMS)**: The Material 3 shell interface (compiled from source).

**Estimated Execution Time:** Approximately 15 to 30 minutes, contingent upon hardware capabilities.

---

## Prerequisites

### System Specifications
- OpenMandriva Lx 6.0 (or subsequent releases).
- A functioning Wayland compositor (e.g., `labwc`, Hyprland, sway).
- A minimum of 2GB of available disk space to accommodate build artifacts.
- An active internet connection for repository access.

### Dependency Provisioning

Deploy the necessary build toolchain and Qt6 development libraries prior to compilation:

```bash
# Provision build utilities
sudo dnf install -y cmake ninja-build gcc-c++ g++ pkgconf-pkg-config git

# Provision Qt6 development libraries
sudo dnf install -y \
    lib64Qt6Core-devel lib64Qt6Gui-devel lib64Qt6Qml-devel \
    lib64Qt6Quick-devel lib64Qt6QuickControls2-devel \
    lib64Qt6Widgets-devel lib64Qt6ShaderTools-devel \
    lib64Qt6WaylandClient-devel lib64Qt6DBus-devel \
    lib64Qt6Network-devel lib64Qt6Test-devel

# Provision Wayland and Vulkan libraries
sudo dnf install -y \
    lib64wayland-devel wayland-protocols-devel \
    lib64vulkan-devel spirv-tools

# Provision supplementary libraries
sudo dnf install -y \
    lib64jemalloc-devel lib64pipewire-devel \
    lib64pam-devel
```

> **Note:** Should the `lib64*` packages be unresolvable, substitute them with their non-lib64 equivalents (e.g., utilize `Qt6Core-devel` in place of `lib64Qt6Core-devel`). OpenMandriva's nomenclature conventions may vary across release versions.

---

## Phase 1: Compilation of quickshell

### 1.1 Repository Acquisition

```bash
mkdir -p ~/sources
cd ~/sources
git clone --depth=1 https://github.com/quickshell-mirror/quickshell.git
cd quickshell
```

### 1.2 Build Configuration

```bash
cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DDISTRIBUTOR="OCWS" \
    -DCMAKE_PREFIX_PATH=/usr/local \
    -DVENDOR_CPPTRACE=ON \
    -DNO_PCH=ON
```

**Optional Compilation Flags** (adjust based on specific system requirements):
```bash
# Deactivate the crash handler if cpptrace is unavailable
-DCRASH_HANDLER=OFF

# Deactivate PipeWire integration if unnecessary
-DSERVICE_PIPEWIRE=OFF
```

### 1.3 Compilation and Installation

```bash
# Execute the build process (adjust the -j parameter to match available CPU cores)
cmake --build build -j$(nproc)

# Execute the installation process (requires elevated privileges)
sudo cmake --install build
```

### 1.4 Verification Protocol

```bash
quickshell --version
```

Expected output format:
```text
quickshell 0.1.0 (or equivalent version identifier)
```

### 1.5 Legacy Package Removal

If `quickshell` was previously installed via OpenMandriva repositories, it must be removed to prevent system conflicts:

```bash
sudo dnf remove quickshell
```

---

## Phase 2: Compilation of DankMaterialShell

### 2.1 Repository Acquisition

```bash
cd ~/sources
git clone --depth=1 https://github.com/DankShrine/dms.git
cd dms
```

### 2.2 Compilation

DMS utilizes a standard Makefile process:

```bash
make -j$(nproc)
```

### 2.3 Installation

```bash
sudo make install
```

This procedure installs the `dms` binary directly to `/usr/local/bin/dms`.

### 2.4 Verification Protocol

```bash
dms --version
```

The system should return the installed DMS version identifier.

---

## Phase 3: System Configuration

### 3.1 Directory Structure Initialization

DMS requires a specific directory structure for its QML shell files:

```bash
mkdir -p ~/.local/share/quickshell/dms
mkdir -p ~/.config/quickshell
```

### 3.2 Asset Deployment

The `make install` command deploys the requisite QML files to `~/.local/share/quickshell/dms/`. Verify successful deployment:

```bash
ls ~/.local/share/quickshell/dms/shell.qml
```

Upon verification, establish a symbolic link to ensure the `dms run` command can locate the necessary assets:

```bash
ln -sf ~/.local/share/quickshell/dms ~/.config/quickshell/dms
```

### 3.3 Settings Deployment

If a custom `settings.json` file is available, deploy it to the appropriate directory:

```bash
cp settings.json ~/.local/share/quickshell/dms/settings.json
```

Alternatively, provision the default OCWS settings:

```bash
cp /path/to/labwc-fuzzel-zigshell-cairo-pango/dotfiles/DankMaterialShell/settings.json \
   ~/.local/share/quickshell/dms/settings.json
```

---

## Phase 4: Resolution of the AppId Pragma Compatibility Issue

**This represents the most frequently encountered issue on OpenMandriva.** The DMS `shell.qml` file incorporates a pragma that is unsupported by legacy versions of quickshell:

```text
//@ pragma AppId com.danklinux.dms
```

If the following error is generated:
```text
ERROR: Unrecognized pragma 'AppId com.danklinux.dms'
ERROR go: quickshell exited: exit status 255
```

### Corrective Action: Pragma Commentation

Execute the following `sed` command to comment out the incompatible pragma:

```bash
sed -i 's|^//@ pragma AppId|// //@ pragma AppId|' \
    ~/.local/share/quickshell/dms/shell.qml
```

Alternatively, manually edit `~/.local/share/quickshell/dms/shell.qml` and modify line 10:

```qml
// //@ pragma AppId com.danklinux.dms
```

> **Note:** This specific pragma is utilized strictly for application ID matching on supported quickshell iterations. Modifying it has no functional detriment to DMS operation.

---

## Phase 5: Operational Procedures

### 5.1 Service Initialization

```bash
dms run &
```

### 5.2 Service Termination

```bash
dms kill
```

### 5.3 Service Restart

```bash
dms kill && sleep 0.5 && dms run &
```

---

## Phase 6: Automated Initialization

To configure DMS to launch automatically upon compositor initialization, append the relevant commands to your autostart configuration.

For **labwc**, append to `~/.config/labwc/autostart`:

```bash
# Initialize DankMaterialShell
if command -v dms >/dev/null 2>&1; then
    nohup dms run >/dev/null 2>&1 &
fi
```

For **Hyprland**, append to `~/.config/hypr/hyprland.conf`:

```text
exec-once = dms run
```

---

## Diagnostics and Troubleshooting

### "dms: command not found"

The DMS binary is located in `/usr/local/bin/`. Ensure this directory is included in your system PATH:

```bash
export PATH="/usr/local/bin:$PATH"
```

Append this declaration to your `~/.bashrc` or `~/.zshrc` to ensure persistence.

### "quickshell: command not found"

Ensure `/usr/local/bin/` is in your PATH, as detailed above.

### DMS Initializes Without Rendering Interface Elements

1. Confirm DMS successfully located the QML files:
   ```bash
   dms kill
   dms run  # Monitor terminal output for related error messages.
   ```

2. Validate the integrity of the symbolic link:
   ```bash
   ls -la ~/.config/quickshell/dms
   ```

3. Confirm the presence of the primary QML file:
   ```bash
   ls ~/.local/share/quickshell/dms/shell.qml
   ```

### QML Module Resolution Failures

DMS may require supplementary QML modules. Provision them via:

```bash
sudo dnf install -y lib64Qt6QuickControls2-devel
```

If the requisite module remains unpackaged, manual compilation from source is necessary.

### Permission Denied During Compilation

Ensure all administrative commands (`sudo cmake --install` and `sudo make install`) are executed with the appropriate privileges.

### Build Failure: "Qt6 not found"

Verify the installation of all fundamental Qt6 development packages:

```bash
sudo dnf install -y lib64Qt6Core-devel lib64Qt6Gui-devel lib64Qt6Qml-devel
```

### Theme Application Failures

DMS relies on [matugen](https://github.com/InboxDev/matugen) to facilitate Material You color extraction. Proceed to install it:

```bash
# Provision via Cargo
cargo install matugen
```

Alternatively, disable `matugen` integration within the DMS configuration:
```json
{
  "runUserMatugenTemplates": false
}
```

---

## Command Reference

| Command | Function |
|---------|----------|
| `dms run` | Initializes the DMS service. |
| `dms kill` | Terminates the DMS service. |
| `dms kill && dms run` | Restarts the DMS service. |
| `quickshell --version` | Outputs the installed quickshell version. |
| `dms --version` | Outputs the installed DMS version. |

---

## Infrastructure Pathways

| Asset | Absolute Pathway |
|-------|------------------|
| DMS Executable | `/usr/local/bin/dms` |
| quickshell Executable | `/usr/local/bin/quickshell` |
| DMS QML Directory | `~/.local/share/quickshell/dms/` |
| DMS Configuration Link | `~/.config/quickshell/dms` → `~/.local/share/quickshell/dms` |
| DMS Configuration File | `~/.local/share/quickshell/dms/settings.json` |
| DMS Primary Interface File | `~/.local/share/quickshell/dms/shell.qml` |

---

## Acknowledgments

- [DankMaterialShell](https://github.com/DankShrine/dms) developed by DankShrine.
- [quickshell](https://github.com/quickshell-mirror/quickshell) developed by quickshell-mirror.
- Systems integration facilitated by the Open Compositor Widget Shell (OCWS) project.

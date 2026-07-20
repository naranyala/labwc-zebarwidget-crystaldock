# Package Availability Across Distributions

This document provides a comprehensive mapping of all runtime dependencies—including shell mode scripts, autostart daemons, action scripts, and widget configurations—required by the Open Compositor Widget Shell (OCWS) to their respective distribution repositories.

## Availability Legend

| Designation | Description |
|-------------|-------------|
| Yes | Available within default distribution repositories. |
| AUR / COPR / OBS | Available in unofficial user repositories; installation is semi-automated. |
| Stable / Testing | Not available in the specified branch. |
| Build | Not packaged; requires compilation from source. |
| No | Not available for the specified distribution. |

## Core Infrastructure

| Binary | Arch Linux | Debian / Ubuntu | Fedora | openSUSE |
|--------|------------|-----------------|--------|----------|
| labwc | Community | Backports+ | No | No |
| zigshell-cairo-pango | Community | Stable / Testing | COPR | No |
| rofi-wayland | Community | No | No | No |
| fuzzel | Community | Stable / Testing | No | No |
| foot | Community | Backports+ | No | No |
| mako | Community | (mako-notifier) | No | No |

## Clipboard and Screen Capture

| Binary | Arch Linux | Debian / Ubuntu | Fedora | openSUSE |
|--------|------------|-----------------|--------|----------|
| wl-clipboard | Yes | Yes | Yes | Yes |
| cliphist | Community | LTS / Testing+ | No | No |
| grim / slurp | Yes | Yes | Yes | Yes |

## Display and Input Management

| Binary | Arch Linux | Debian / Ubuntu | Fedora | openSUSE |
|--------|------------|-----------------|--------|----------|
| swaybg | Yes | Yes | Yes | Yes |
| swayidle | Yes | Yes | Yes | Yes |
| swaylock | Yes | Yes | Yes | Yes |
| gammastep | Yes | Yes | Yes | Yes |
| brightnessctl | Yes | Yes | Yes | Yes |
| wlr-randr | Yes | Yes | Yes | Yes |

## Media and System Utilities

| Binary | Arch Linux | Debian / Ubuntu | Fedora | openSUSE |
|--------|------------|-----------------|--------|----------|
| playerctl | Yes | Yes | Yes | Yes |
| wireplumber | Yes | Yes | Yes | Yes |
| NetworkManager (nmcli) | Yes | Yes | Yes | Yes |
| bluez (bluetoothctl) | Yes | Yes | Yes | Yes |
| libnotify (notify-send) | Yes | (libnotify-bin) | Yes | Yes |

## General Utilities

| Binary | Arch Linux | Debian / Ubuntu | Fedora | openSUSE |
|--------|------------|-----------------|--------|----------|
| jq | Yes | Yes | Yes | Yes |
| crudini | Yes | Yes | Yes | Yes |
| libxml2 (xmllint) | Yes | (libxml2-utils) | Yes | (libxml2-tools) |
| inotify-tools | Yes | Yes | Yes | Yes |
| qt6ct | Yes | Yes | Yes | Yes |

## Typography

| Font Family | Arch Linux | Debian / Ubuntu | Fedora | openSUSE |
|-------------|------------|-----------------|--------|----------|
| Noto Sans / Mono | noto-fonts | fonts-noto | google-noto-sans-fonts | google-noto-sans-fonts |
| DejaVu Sans | ttf-dejavu | fonts-dejavu-core | dejavu-sans-fonts | dejavu-fonts |
| FiraCode Nerd Font | AUR ttf-firacode-nerd | fonts-firacode (unstable) | COPR fira-code-nerd-fonts | Download |

## Compilation Requirements

### Mixed Availability Packages

| Component | Distributions Requiring Compilation |
|-----------|-------------------------------------|
| zigshell-cairo-pango | Debian / Ubuntu Stable (absent from repositories) |
| fuzzel | Debian / Ubuntu Stable (absent from repositories) |
| FiraCode Nerd Font | Fedora, openSUSE; all non-Arch Linux distributions for the Nerd variant |

### Distribution-Specific Build Dependencies

```bash
# Arch Linux
sudo pacman -S base-devel gtk3 json-c

# Debian / Ubuntu
sudo apt install build-essential cmake libgtk-3-dev

# Fedora
sudo dnf install gcc make pkg-config gtk3-devel json-c-devel

# openSUSE
sudo zypper install gcc make pkg-config gtk3-devel libjson-c-devel
```

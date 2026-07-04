# Configuration Reference

Complete reference for labwc, sfwbar, and fuzzel configuration.

---

## labwc Configuration

labwc uses five config files in ~/.config/labwc/:

| File | Purpose |
|------|---------|
| rc.xml | Keybindings, window rules, mouse bindings, menus |
| autostart | Shell script run at compositor startup |
| environment | Environment variables set before labwc starts |
| menu.xml | Right-click desktop menu |
| themerc-override | Window decoration theme overrides |

### rc.xml

Main configuration file. Handles keybindings, window rules, mouse bindings, and menus.

#### Key Format

| Modifier | Key |
|----------|-----|
| A- | Alt |
| W- | Super (Windows key) |
| S- | Shift |
| C- | Ctrl |

Combine modifiers: C-A-Left = Ctrl+Alt+Left, S-W-1 = Shift+Super+1.

#### System Keybindings

| Key | Action |
|-----|--------|
| A-r | Reload config |
| A-q | Close window |
| A-F4 | Close window |
| W-m | Exit labwc |

#### Launcher Keybindings

| Key | Action |
|-----|--------|
| W-Return | foot terminal |
| A-Return | foot terminal |
| A-a | fuzzel app launcher |
| A-c | Calculator (fuzzel+bc) |
| A-period | Emoji picker (fuzzel) |
| A-F5 | Power menu (actions/power-menu.sh) |
| A-F6 | Maintenance menu (actions/maintenance.sh) |
| A-S-F12 | Theme picker |
| A-F12 | Theme next |

#### Window Management Keybindings

| Key | Action |
|-----|--------|
| A-f | Toggle fullscreen |
| W-a | Toggle maximize |
| A-space | Root menu |
| A-Tab | Next window |
| A-S-Tab | Previous window |
| A-Left | Focus previous window |
| A-Right | Focus next window |

#### Snapping Keybindings

| Key | Action |
|-----|--------|
| S-A-Left | Snap to left edge |
| S-A-Right | Snap to right edge |
| S-A-Up | Snap to top edge |
| S-A-Down | Snap to bottom edge |

#### Resize Keybindings

| Key | Action |
|-----|--------|
| W-Left | Resize left (-40px) |
| W-Right | Resize right (+40px) |
| W-Up | Resize up (-40px) |
| W-Down | Resize down (+40px) |

#### Workspace Keybindings

| Key | Action |
|-----|--------|
| W-1 to W-9 | Switch to desktop 1-9 |
| S-W-1 to S-W-9 | Send window to desktop 1-9 |
| C-A-Left | Previous desktop |
| C-A-Right | Next desktop |

#### Media Keybindings

| Key | Action |
|-----|--------|
| XF86AudioRaiseVolume | Volume up (wpctl set-volume @DEFAULT_SINK@ 5%+) |
| XF86AudioLowerVolume | Volume down (wpctl set-volume @DEFAULT_SINK@ 5%-) |
| XF86AudioMute | Toggle mute (wpctl set-mute @DEFAULT_SINK@ toggle) |
| XF86AudioPlay | Play/pause (playerctl play-pause) |
| XF86AudioNext | Next track (playerctl next) |
| XF86AudioPrev | Previous track (playerctl previous) |
| XF86MonBrightnessUp | Brightness up (brightnessctl set +10%) |
| XF86MonBrightnessDown | Brightness down (brightnessctl set 10%-) |

#### Screenshot Keybindings

| Key | Action |
|-----|--------|
| Print | Area screenshot (grim + slurp, copy to clipboard) |
| A-Print | Full screenshot (grim, copy to clipboard) |
| S-Print | Full screenshot (grim, copy to clipboard) |
| C-Print | Window screenshot (grim -g, copy to clipboard) |
| S-A-Print | Area screenshot with annotation (satty/swappy) |
| S-C-Print | Full screenshot with annotation (satty/swappy) |

#### Clipboard Keybinding

| Key | Action |
|-----|--------|
| W-v | Clipboard history (cliphist list | fuzzel -d | cliphist decode | wl-copy) |

#### Mouse Bindings

| Context | Button | Action |
|---------|--------|--------|
| Frame | A-Left | Drag to move |
| Titlebar | Left Press | Focus + Raise |
| Titlebar | Left Drag | Move window |
| Titlebar | Left DoubleClick | Toggle maximize |
| Client | A-Left | Drag to move |
| Client | A-Right | Drag to resize |
| Root | Left Press | Show root menu |

#### Window Rules

```xml
<applications>
  <application class="sfwbar">
    <skip_taskbar>yes</skip_taskbar>
    <skip_pager>yes</skip_pager>
  </application>
  <application class="crystal-dock">
    <skip_taskbar>yes</skip_taskbar>
    <skip_pager>yes</skip_pager>
    <fixed_position>yes</fixed_position>
  </application>
</applications>
```

#### Desktops

```xml
<desktops>
  <number>9</number>
  <firstdesk>1</firstdesk>
</desktops>
```

Must match sfwbar pager pins. If sfwbar pins 1-9, desktops must be 9.

### autostart

Shell script executed once at compositor startup. Runs sequentially (no backgrounding for critical services).

Startup order:
1. PATH export
2. DBus activation environment update
3. Touchpad natural scroll (gsettings)
4. Component config loading (status.json)
5. Wallpaper (wallpaper random or swaybg)
6. Statusbar (sfwbar via relaunch-status-bars.sh)
7. Crystal-dock (if configured)
8. Notification daemon (mako or dunst)
9. Clipboard manager (cliphist + wl-paste)
10. Screen protection (gammastep or redshift)
11. Natural scroll (gsettings)
12. Polkit agent (lxpolkit or polkit-gnome)
13. XDG portal restart
14. Tray applets (nm-applet, blueman-applet, udiskie)
15. GNOME keyring
16. Idle management (swayidle)

### environment

Environment variables set before labwc starts. Never hardcode WAYLAND_DISPLAY -- GDM assigns dynamically.

Required variables:
```
XDG_CURRENT_DESKTOP=labwc
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=labwc
```

Optional variables:
```
WLR_NO_HARDWARE_CURSORS=1        # Fixes click alignment bugs on some GPUs
GDK_BACKEND=wayland               # Force GTK Wayland backend
QT_QPA_PLATFORM=wayland           # Force Qt Wayland backend
XCURSOR_SIZE=24                   # Cursor size
```

### themerc-override

Openbox theme overrides for window decorations:

```
activetextfont=sans 10
activebg=#2d2d2d
activetext=#d4d4d4
inactivetextfont=sans 10
inactivebg=#1e1e2e
inactivetext=#a6adc8
border.width=1
border.color=#3c3c3c
titlebar.height=28
```

---

## sfwbar Configuration

sfwbar is the sole statusbar. Config files in ~/.config/sfwbar/.

### Launch Flags

sfwbar requires -f (config) and -c (CSS) flags:

```bash
sfwbar -f ~/.config/sfwbar/sfwbar.config -c ~/.config/sfwbar/catppuccin-mocha.css
```

The Css = "..." config directive is not supported.

### Config Structure

sfwbar configs use #Api2 header. Key sections:

```
#Api2
Theme = "Adwaita-dark"
Set ImagePath = "icons/misc:icons/weather"
Set ThicknessHint = "34px"

switcher { disable = true }
Function SfwbarInit() {}

bar "name:position" {
  edge = "top|bottom"
  layer = "top"
  mirror = "*"
  exclusive_zone = "auto"

  widget "file.widget"
  taskbar { ... }
  pager { ... }
  tray { ... }
  label { css = "..." }
}

#CSS
window#sfwbar { ... }
```

### Bar Definitions

Each bar creates a separate GTK window. Bar name can include position suffix:

```
bar "topbar:top" { ... }      # Top edge
bar "bottombar:bottom" { ... } # Bottom edge
```

### Widget Types

| Type | Description |
|------|-------------|
| taskbar | Window list with icons and labels |
| pager | Workspace indicator with dots/buttons |
| tray | System tray icons |
| label | Text label (can use css for spacing) |
| button | Clickable button |
| scale | Progress bar (horizontal/vertical) |
| chart | Time series plot |
| image | Static image |
| grid | Container for child widgets |

### Widget Files

Widget files use #Api2 header. Pattern:

```
#Api2
export button "name" {
  style = "module"
  class = "module"
  value = "icon-name"
  tooltip = "Description"
  action = PopUp("PopupName")
}

PopUp("PopupName") {
  style = "detail_popup"
  grid {
    style = "detail_grid"
    label { value = "Title" style = "detail_header" }
    # ... content ...
  }
}

#CSS
button.module { ... }
```

### Workspace Switching

sfwbar uses its built-in pager widget with WorkspaceActivate() action:

```
pager {
  style = "pager"
  rows = 1
  pins = "1","2","3","4","5","6","7","8","9"
  preview = true
  primary_axis = rows
  action[Drag] = WorkspaceActivate()
}
```

Do not use labwc -e 'GoToDesktop N' -- labwc has no CLI IPC flag.

### CSS

sfwbar CSS uses standard GTK CSS syntax. Key selectors:

```
window#sfwbar          # Bar window background
grid#topbar            # Top bar grid
grid#bottombar         # Bottom bar grid
button.module          # Module buttons in bar
button#taskbar_item    # Taskbar window items
button#pager_item      # Workspace pager dots
button#tray_item       # System tray icons
label#clock            # Clock label
window.detail_popup    # Popup window background
grid.detail_grid       # Popup content grid
```

### CSS Theme Variables

Theme engine generates sfwbar CSS from INI profiles:

```
@define-color bg_color {{COLOR_BG}};
@define-color fg_color {{COLOR_FG}};
@define-color accent {{COLOR_ACCENT}};
@define-color urgent {{COLOR_URGENT}};
@define-color surface1 {{COLOR_SURFACE}};
```

---

## fuzzel Configuration

fuzzel is the primary application launcher. Config in ~/.config/fuzzel/fuzzel.ini.

### INI Sections

| Section | Purpose |
|---------|---------|
| [main] | Font, anchor, width, lines, dpi-aware |
| [colors] | Background, text, match, selection, border |
| [border] | Width, radius (color goes in [colors]) |
| [layout] | Horizontal/vertical padding |
| [dmenu] | Dmenu mode settings |

### Common Settings

```ini
[main]
font=Noto Sans:size=12
dpi-aware=auto
anchor=top-left
width=30
lines=12

[colors]
background=1e1e2eff
text=cdd6f4ff
match=89b4faff
selection=45475aff
border=585b70ff

[border]
width=2
radius=8

[layout]
padding=10
```

### Theme Engine

fuzzel config is generated from INI profiles via templates/fuzzel.ini.tmpl:

```
[colors]
background={{COLOR_BG}}ff
text={{COLOR_FG}}ff
match={{COLOR_ACCENT}}ff
selection={{COLOR_SURFACE}}ff
border={{COLOR_BORDER}}ff
```

---

## GTK Configuration

### settings.ini

GTK3 and GTK4 settings in ~/.config/gtk-3.0/settings.ini and ~/.config/gtk-4.0/settings.ini:

```ini
[Settings]
gtk-font-name=Noto Sans 10
gtk-monospace-font-name=Noto Sans Mono 10
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-cursor-size=24
gtk-application-prefer-dark-theme=1
gtk-color-scheme=prefer-dark
```

### Common Bugs

- gtk-font-name corrupted to "0": External processes can overwrite this. Run fix-gtk-fonts.sh.
- Comma format "Noto Sans, 10": Some GTK versions require space-separated "Noto Sans 10".

### Fontconfig

Font rendering config in ~/.config/fontconfig/fonts.conf:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias><family>sans-serif</family><prefer><family>Noto Sans</family></prefer></alias>
  <alias><family>monospace</family><prefer><family>Noto Sans Mono</family></prefer></alias>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
  </match>
</fontconfig>
```

---

## Validation

### validate.sh

Runs 25+ checks across 11 sections:

1. Binaries (required: labwc, sfwbar; optional: 20+ tools)
2. labwc config files (rc.xml, autostart, environment)
3. Autostart (executable, sfwbar present, screen protection, no gsettings GTK sync)
4. rc.xml (XML syntax, Client context, unescaped &, desktop count, keybinds, script paths)
5. Environment (no hardcoded WAYLAND_DISPLAY, XDG vars, software cursors)
6. GTK Fonts (gtk-font-name corruption, comma format, monospace, fontconfig)
7. SFWBar (config exists, missing widget refs, missing include refs, CSS theme)
8. Fuzzel (config exists, invalid border color option)
9. Permissions (config dirs, scripts executable)
10. Display (WAYLAND_DISPLAY, XDG_SESSION_TYPE, PATH)
11. Desktop count (rc.xml desktops vs sfwbar pins)

Exit code = number of errors.

### fix.sh

15 auto-fix sections with --dry-run support:

1. Create missing directories
2. Fix permissions (autostart, scripts)
3. Remove broken symlinks
4. Install missing labwc configs
5. Fix rc.xml Client context (remove Left Press)
6. Fix unescaped & in rc.xml
7. Fix broken script paths in rc.xml
8. Fix environment (remove hardcoded WAYLAND_DISPLAY, add XDG vars)
9. Fix GTK fonts (corruption, comma, monospace, fontconfig)
10. Install missing sfwbar widgets/configs
11. Install fuzzel config, fix border bug
12. Sync desktop count (rc.xml <-> sfwbar pins)
13. Fix PATH
14. Create labwc.desktop session file
15. Remove stale files

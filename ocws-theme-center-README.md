# OCWS Theme Center - Complete Guide

`ocws-theme-center` is a comprehensive GTK-based theme management application for the OCWS desktop environment, providing extensive theming capabilities across all desktop surfaces including Labwc compositor, GTK applications, SFWBar panels, launcher systems, and more.

## 🎨 Core Features

### 1. Theme Browser & Navigation
- **Visual Theme Cards** — Grid display with theme previews, descriptions, authors, and version info
- **Smart Filtering** — Browse themes by category (Design Aesthetic, Functionality, Technology Stack)
- **Live Preview** — Real-time theme selection with immediate visual feedback across all desktop surfaces
- **Metadata Display** — Theme version, author, and detailed description on each card

### 2. Advanced Theme Preview System
- **Multi-Surface Visualization** — Preview how themes apply to:
  - **Labwc Compositor** — Window borders, titlebars, OSD panels, workspace switchers
  - **GTK3/GTK4 Applications** — Theme files, icon themes, cursor themes, font rendering
  - **SFWBar Panels** — Top status bars, bottom dock/taskbars, panel widgets
  - **Launcher Systems** — Rofi, Fuzzel, Qt applications, notification systems
  - **Typography** — Interface, document, and monospace fonts
  - **Cursors** — Theme-adaptive cursor sets and sizes

### 3. Interactive Theme Editor
- **Color Mixer Tool** — HSL-based color selection with live preview
- **Custom Overrides** — Modify individual theme values with instant feedback
- **Semantic Color Groups** — Organized color categories (Primary, Background, Text, Accents)
- **Multi-Channel Editing** — Edit colors for different UI components simultaneously

### 4. Comprehensive Theme Management
- **Import/Export** — Load custom `.ini` theme files or save configurations
- **Theme Synchronization** — Apply themes consistently across all supported surfaces
- **Configuration Backup** — Create versioned backups of complete desktop configurations
- **Theme Validation** — Automatic syntax and compatibility checking
- **Theme Comparison** — Side-by-side theme difference analysis

## 🎯 Themgeing Capabilities

### 1. Color Systems & Palettes

#### **Primary Theme Collections**

**Design Aesthic Categories:**
- **Catppuccin Series** (12+ variants) — Modern pastel palettes with excellent contrast ratios
  - `catppuccin-mocha` — Warm dark theme with pleasant aesthetics
  - `catppuccin-macchiato` — Richer dark theme with deeper accents
  - `catppuccin-frappe` — Neutral dark theme with balanced colors
  - `catppuccin-latte` — Light mode version with soft pastels

**Developer & Productivity Themes:**
- **Dracula** — Vampire black, optimized for coding
- **Tokyo Night** — Elevated dark theme for power users
- **Nord** — Arctic blue palette for productivity
- **Solarized Dark** — High contrast for readability

**Nature-Inspired Themes:**
- **Everforest** — Forest greens and autumn browns
- **Kanagawa** — Minimalist, calming color scheme
- **Rose Pine** — Sophisticated dark theme with warm accents

**Minimalist Options:**
- **Flexoki** — Clean, reduced color palette for focus
- **One Dark** — Classic developer theme

#### **Semantic Color Architecture**
Every theme defines a complete semantic color system:

```ini
[colors]
# Base Palette
base=#1e1e2e           # Main background
mantle=#181825          # Secondary background
mantle=#11111b          # Tertiary background
surface0=#313244        # Higher contrast elements
surface1=#45475a        # Card/panel backgrounds
surface2=#585b70        # Borders/dividers
overlay0=#6c7086        # Less prominent text
subtext0=#7f849c        # Secondary text
subtext1=#9399b2        # Tertiary text
text=#cdd6f4            # Primary text (72% contrast)

# Accent Colors
accent=#89b4fa           # Primary blue
lavender=#b4befe         # Light blue
sky=#89dceb             # Cyan/teal
teal=#94e2d5             # Teal green
green=#a6e3a1           # Success green
yellow=#f9e2af           # Warning yellow
peach=#fab387           # Orange
maroon=#eba0ac           # Pink/red
red=#f38ba8             # Error red
mauve=#cba6f7           # Purple
pink=#f5c2e7             # Light pink
flamingo=#f2cdcd          # Warm pink
rosewater=#f5e0dc         # Soft pink/warmth

# Semantic Mapping
color_bg=${base}
color_fg=${text}
color_accent=${accent}
color_urgent=${red}
color_warning=${yellow}
color_ok=${green}
color_surface=${surface1}
color_border=${surface2}
color_muted=${overlay0}
```

### 2. Configuration Surfaces

#### **Labwc Compositor Configuration**
```ini
[labwc]
themerc_active_bg=${surface0}      # Active window background
themerc_inactive_bg=${mantle}        # Inactive window background
themerc_active_text=${text}          # Active window text
themerc_inactive_text=${overlay0}    # Inactive window text
themerc_border=${surface1}           # Window borders
themerc_font=sans 10                  # Window font
themerc_height=28                     # Titlebar height
cornerRadius=8                        # Window corner radius
border_width=1                        # Window border width
titlebar_layout=icon:iconify,max,close # Titlebar button layout
osd_bg=${base}                        # OSD panel background
osd_border=${surface1}                # OSD panel borders
osd_text=${text}                      # OSD panel text
osd_accent=${accent}                   # OSD accent color
osd_inactive=${overlay0}              # Inactive OSD
osd_switcher_width=600                # Window switcher width
osd_switcher_padding=8                # Window switcher padding
```

#### **GTK Theme Configuration**
```ini
[gtk3]
[gtk4]
# Theme Selection
gtk_theme=Catppuccin-Mocha-Standard-Dark

# Icon Theme Management
icon_theme=Papirus-Dark

# Cursor Theme Setup
cursor_theme=Catppuccin-Mocha-Dark
cursor_size=24

# Shell Integration
button_layout=close,minimize,maximize:menu
color_scheme=prefer-dark
gtk_application_prefer_dark_theme=true

# Visual Preferences
gtk_enable_animations=true
gtk_shell_shows_app_menu=false
gtk_shell_shows_menu_bar=false
gtk_menu_images=true
gtk_button_images=true

# Toolbar Configuration
gtk_toolbar_style=GTK_TOOLBAR_BOTH_HORIZ
gtk_decoration_layout=:menu

# Font Rendering
xft_antialias=1
xft_hinting=1
xft_hintstyle=hintfull
xft_rgba=rgb
```

#### **Font & Typography**
```ini
[fonts]
interface=Noto Sans 10     # System UI (menus, dialogs, titles)
document=Noto Sans 10      # Content text (articles, documents)
monospace=Noto Sans Mono 10 # Code/fonts (terminal, editors)
```

#### **SFWBar Panel Configuration**
```ini
[sfwbar]
# Panel Styling
bar_bg=${base}              # Bar background
bar_bg_alpha=0.92           # Bar transparency
bar_fg=${text}              # Bar text
bar_active=${accent}        # Active element background
bar_urgent=${red}           # Urgent element background
bar_border=${surface1}      # Bar borders
bar_height=32               # Bar height
bar_radius=0                # Bar corner radius

# Module Styling
module_bg=${surface1}       # Module background
module_bg_alpha=0.4         # Module transparency
module_fg=${text}           # Module text
module_radius=5            # Module corner radius
module_padding_h=8         # Module horizontal padding
module_padding_v=2         # Module vertical padding

# Typography
font_size=12               # Normal module text size
font_size_small=10          # Small module text size
```

#### **Launcher Theme (Rofi)**
```ini
[rofi]
# Panel Background
bg=${base}                  # Main panel background
bg_alt=${surface0}           # Alternative background

# Text Colors
fg=${text}                  # Primary text
fg_alt=${subtext0}          # Secondary text

# Interactive Elements
accent=${accent}             # Accent color
urgent=${red}               # Urgent/warning color
error=${red}                # Error state
selected=${surface1}        # Selected item background
border_color=${accent}       # Selection border
border_width=2               # Selection border width
border_radius=12             # Panel border radius
font=Noto Sans 12           # Panel font
icon_theme=Papirus-Dark     # Icon set
terminal=foot              # Terminal emulator
```

### 3. Configuration Templates

OCWS Theme Center supports **14 different output configuration files** covering all desktop surfaces:

| Template File | Output Path | Purpose |
|---------------|-------------|---------|
| `tokens.css.tmpl` | `ocws/tokens.css` | CSS color token system |
| `ocws.css.tmpl` | `ocws/ocws.css` | OCWS glassmorphism styling |
| `sfwbar.css.tmpl` | `ocws/theme.css` | SFWBar panel styling |
| `themerc-override.tmpl` | `labwc/themerc-override` | Labwc theme overrides |
| `environment.tmpl` | `labwc/environment` | Labwc environment configuration |
| `gtk.css.tmpl` | `gtk-3.0/gtk.css` | GTK3 theme |
| `gtk3-settings.ini.tmpl` | `gtk-3.0/settings.ini` | GTK3 application settings |
| `gtk4-settings.ini.tmpl` | `gtk-4.0/settings.ini` | GTK4 application settings |
| `rofi.rasi.tmpl` | `rofi/config.rasi` | Rofi launcher theme |
| `fuzzel.ini.tmpl` | `fuzzel/fuzzel.ini` | Fuzzel terminal launcher |
| `foot.ini.tmpl` | `foot/foot.ini` | Foot terminal emulator |
| `mako.ini.tmpl` | `mako/config` | Mako notification daemon |
| `qt6ct.conf.tmpl` | `qt6ct/qt6ct.conf` | Qt6CT configuration |

## 🔧 Shell Mode Integration

### **Enhanced Dual Panel Strategy**
```bash
# Apply comprehensive enhanced dual panel mode
sfwbar -c ~/.config/ocws/modes/enhanced-doublepanel.mode

# This includes both top and bottom panels with full feature set
```

### **Single Top Panel Strategy**
```bash
# Apply modern single top panel mode (crystal-dock compatible)
sfwbar -f ~/.config/ocws/single-top-sfwbar.config

# This provides a single optimized top bar
```

## 🎯 Predefined Theme Categories

### **Design Aesthetic Categories**

| Theme | Author | Style | Best For |
|-------|--------|-------|----------|
| `catppuccin-mocha` | Catppuccin | Modern pastel | General purpose, long-term use |
| `catppuccin-macchiato` | Catppuccin | Rich dark | Application development |
| `dracula` | Dracula | Vampire black | Coding, minimal eye strain |
| `tokyo-night` | Tokyo Night | Elevated dark | Power users, professional |
| `nord` | Nord | Arctic blue | Productivity, focus |
| `solarized-dark` | Stephen Hart | High contrast | Reading, accessibility |
| `gruvbox` | aruffnell | Retro warm | Classic aesthetic, comfort |
| `everforest` | sjaakdeenen | Nature | Organic, calming |
| `rose-pine` | rosepinetheme | Sophisticated | Minimalist, elegant |

### **Technical Categories**

| Theme | Style | Features | Use Case |
|-------|-------|----------|----------|
| `one-dark` | Developer | Syntax highlighting | Code editors, IDEs |
| `flexoki` | Minimalist | Focus | Workspaces, productivity |
| `kanagawa` | Clean | Speed | Performance, low resources |

## 📋 Theme Selection Criteria

### **For General Users**
- **Catppuccin Mocha** — Perfect balance of aesthetics and functionality
- **Dracula** — Excellent for coding and low eye strain
- **Nord** — Great for productivity and focus

### **For Developers**
- **One Dark** — Classic developer theme with excellent contrast
- **Tokyo Night** — Modern, power-user oriented
- **Solarized Dark** — High contrast for extended reading

### **For Designers/Creators**
- **Rose Pine** — Sophisticated, elegant aesthetic
- **Everforest** — Natural, calming colors
- **Kanagawa** — Clean, focused workspace

### **For Performance**
- **Flexoki** — Minimal resource usage
- **One Dark** — Lightweight, fast rendering
- **Minimal variants** — Essential-only configuration

## 🚀 Quick Start Guide

### **Installation**
```bash
# Build from source
make

# or using zig builder
zig build

# Run theme center
./ocws-theme-center
```

### **Basic Usage**

1. **Launch Theme Center**
   ```bash
   ./ocws-theme-center
   ```

2. **Browse Themes**
   - Use category filters to browse themes
   - Search themes by name, author, or description
   - View theme cards with previews and metadata

3. **Preview Theme**
   - Click on theme cards for live preview
   - See how themes apply across all desktop surfaces
   - Adjust preview settings as needed

4. **Apply Theme**
   - Click "Apply" to apply theme to all surfaces
   - Use "Quick Apply" for standard application
   - Use "Custom Apply" for selective application

5. **Manage Themes**
   - Import `.ini` files using "Import" button
   - Export themes using "Export" button
   - Backup current configuration regularly

## 🔧 Advanced Usage

### **Theme Customization**
1. **Color Editing**
   - Use the "Edit" tab for interactive color modifications
   - Adjust individual color values using HSL color picker
   - See changes reflected immediately in preview

2. **Surface Selection**
   - Toggle specific surfaces for application
   - Preview themes on individual surfaces
   - Compare theme effects across surfaces

3. **Configuration Management**
   - Create theme packages with all dependencies
   - Maintain theme versions and changelog
   - Share custom themes with community

## 🛠️ Technical Architecture

### **Core Data Structures**
```c
typedef struct {
    char name[MAX_KEY_LEN];     // Theme name
    char description[256];      // Theme description
    char author[128];           // Theme author
    ThemeSection sections[16];  // Configuration sections
    char colors[MAX_COLORS][2][MAX_VAL_LEN]; // Color definitions
} Theme;
```

### **INI File Structure**
```ini
[meta]
name=Theme Name
description=A comprehensive theme
author=Theme Author
version=2.0

[colors]
# Complete color palette with semantic mappings

[labwc]
# Window manager configuration

[gtk3]
# GTK3 theme settings

[gtk4]
# GTK4 theme settings

[fonts]
# Typography configuration

[rofi]
# Launcher theme configuration

[sfwbar]
# Panel system configuration
```

### **Output Configuration Processing**
```c
// Maps template files to destination paths
static const char *output_files[][2] = {
    {"tokens.css.tmpl",    "ocws/tokens.css"},
    {"ocws.css.tmpl",      "ocws/ocws.css"},
    {"sfwbar.css.tmpl",    "ocws/theme.css"},
    {"themerc-override.tmpl", "labwc/themerc-override"},
    {"environment.tmpl",   "labwc/environment"},
    {"gtk.css.tmpl",       "gtk-3.0/gtk.css"},
    {"gtk3-settings.ini.tmpl", "gtk-3.0/settings.ini"},
    {"gtk4-settings.ini.tmpl", "gtk-4.0/settings.ini"},
    {"rofi.rasi.tmpl",     "rofi/config.rasi"},
    {"fuzzel.ini.tmpl",    "fuzzel/fuzzel.ini"},
    {"foot.ini.tmpl",      "foot/foot.ini"},
    {"rofi.rasi.tmpl",     "rofi/config.rasi"},
    {"mako.ini.tmpl",      "mako/config"},
    {"qt6ct.conf.tmpl",    "qt6ct/qt6ct.conf"},
};
```

## ⚡ Performance Considerations

### **Memory Usage**
- **Theme Cache** : Up to 64 themes loaded simultaneously
- **Preview Rendering** : Real-time rendering uses significant memory
- **Configuration Parsing** : INI parsing during theme selection

### **Rendering Optimization**
- **Hardware Acceleration** : Utilizes GTK3 GPU rendering
- **Caching** : Previews and color schemes cached for performance
- **Lazy Loading** : Resources loaded on-demand

### **System Requirements**
- **Minimum** : 4GB RAM, integrated GPU support
- **Recommended** : 8GB+ RAM, dedicated GPU
- **Optimal** : 16GB+ RAM, high-performance GPU

## 📚 Community & Resources

### **Theme Repository**
- **Built-in Themes** : `/path/to/themes/` (12+ themes)
- **Community Themes** : User-contributed themes
- **Official Themes** : Maintained by OCWS team

### **Documentation**
- **Theme Specification** : `.ini` file format guide
- **Configuration Reference** : Surface-specific documentation
- **API Documentation** : Programmatic theme manipulation

### **Support Channels**
- **Bug Reports** : GitHub issue tracker
- **Feature Requests** : Community suggestions
- **Discussions** : User collaboration and theme sharing

## 🏆 Theme Guidelines

### **Quality Standards**
- **Color Contrast** : Minimum 4.5:1 for text elements
- **Semantic Consistency** : Logical color grouping and relationships
- **Surface Coverage** : Complete application across all supported surfaces
- **Performance Optimization** : Resource-efficient theming

### **Theme Submission Criteria**
- **Complete Configuration** : Full application across all surfaces
- **Valid Syntax** : Proper INI file structure
- **Comprehensive Preview** : Works correctly in all UI contexts
- **Documentation** : Clear description and usage instructions

## 🎯 Conclusion

OCWS Theme Center provides comprehensive theming capabilities for the OCWS desktop environment, supporting an extensive range of themes across all desktop configuration surfaces. The system combines powerful preview capabilities with intuitive management tools, enabling users to create personalized desktop experiences that are both functional and aesthetically pleasing.

The theme system continues to evolve with new features, enhanced preview capabilities, and expanded theme support, making it the central hub for OCWS desktop personalization and customization.

# Theme Engine — Learning Material

> Script: `scripts/theme-engine.sh` | Templates: `./templates/` | Themes: `./themes/`

---

## What is the Theme Engine?

The OCWS Theme Engine is a custom shell script responsible for achieving the system-wide glassmorphic UI. It parses configuration variables from `.ini` theme files and dynamically compiles multiple dotfile templates into their final rendered states.

Because tools like `foot`, `zigshell-cairo-pango`, and `labwc` all use entirely different configuration formats (INI, XML, Custom), the theme engine acts as the unified bridge linking them to a single color palette.

---

## How It Works

1. **The Theme File (`themes/catppuccin-mocha.ini`)**
   This file uses INI sections with key=value pairs:
   ```ini
   [meta]
   name=Catppuccin Mocha
   author=Catppuccin

   [colors]
   base=1e1e2e
   surface=313244
   accent=89b4fa

   [zigshell-cairo-pango]
   blur=0.75
   opacity=0.92

   [labwc]
   border_color=89b4fa
   border_width=1
   ```

2. **The Template Files (`templates/*.tmpl`)**
   The templates are copies of the actual application configuration files, with `{{VARIABLE}}` placeholders:
   ```ini
   # templates/foot.ini.tmpl
   [colors]
   background={{colors.base}}
   foreground={{colors.accent}}
   ```

3. **The Rendering Process (`scripts/theme-engine.sh`)**
   When the theme engine is run, it performs the following:
   * **Parses** the INI theme file, loading all `[section]` groups into associative arrays.
   * **Finds** all `.tmpl` files in the `templates/` directory.
   * **Replaces** all `{{section.key}}` placeholders with actual values using `sed`.
   * **Writes** the final rendered config files to `~/.config/` (foot, zigshell-cairo-pango, labwc, fuzzel, etc.).
   * **Triggers** live reloads: `killall -USR1 foot`, `zigshell-cairo-pango -R`.

---

## Modifying the Theme

To tweak colors, borders, or opacities globally:
1. Open your current theme file in `themes/`.
2. Modify the variables.
3. Run `scripts/theme-engine.sh themes/your_theme.ini`.

To add a new tool to the theme engine:
1. Copy the tool's config file to `templates/name.tmpl`.
2. Replace hardcoded colors with `{{YOUR_VAR_NAME}}`.
3. Add the target path logic to the `case` statement at the bottom of `scripts/theme-engine.sh`.

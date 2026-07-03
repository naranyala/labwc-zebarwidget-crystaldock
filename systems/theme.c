/* systems/theme.c - Cross-component theme management */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "widget.h"

/* ============================================================================
 * Theme System
 * ============================================================================ */

#define MAX_THEME_PROFILES 64

typedef enum {
    THEME_TYPE_BAR,
    THEME_TYPE_WIDGET,
    THEME_TYPE_DOCK,
    THEME_TYPE_PANEL,
    THEME_TYPE_GLOBAL
} theme_target_t;

typedef struct {
    const char *name;
    widget_theme_t theme;
    bool active;
    theme_target_t target;
    char *path;
} theme_t;

typedef struct {
    theme_t *themes;
    int theme_count;
    int max_themes;
    theme_t *active_theme;
    char *theme_name;
} theme_system_t;

static theme_system_t theme_system;

/* ============================================================================
 * Theme API
 * ============================================================================ */

/* Initialize theme system */
void init_theme_system(int max_themes) {
    theme_system.max_themes = max_themes;
    theme_system.theme_count = 0;
    theme_system.themes = calloc(max_themes, sizeof(theme_t));
    theme_system.active_theme = NULL;
    theme_system.theme_name = NULL;
}

/* Load theme from data */
theme_t* load_theme(const char *name, const widget_theme_t *theme_data, theme_target_t target, const char *path) {
    if (theme_system.theme_count >= theme_system.max_themes) return NULL;
    if (!name || !theme_data) return NULL;
    
    theme_t *theme = &theme_system.themes[theme_system.theme_count++];
    theme->name = strdup(name);
    theme->active = false;
    theme->target = target;
    theme->path = (path ? strdup(path) : NULL);
    
    /* Copy theme data */
    memcpy(&theme->theme, theme_data, sizeof(widget_theme_t));
    
    return theme;
}

/* Load theme from file */
bool load_theme_from_file(const char *name, const char *path, theme_target_t target) {
    if (theme_system.theme_count >= theme_system.max_themes) return false;
    if (!name || !path) return false;
    
    FILE *f = fopen(path, "r");
    if (!f) return false;
    
    widget_theme_t theme_data;
    memset(&theme_data, 0, sizeof(widget_theme_t));
    
    /* Simple INI parsing for theme files */
    char line[256];
    char current_section[64] = "";
    
    while (fgets(line, sizeof(line), f)) {
        char line_copy[256];
        strcpy(line_copy, line);
        
        /* Remove newline */
        line_copy[strcspn(line_copy, "\r\n")] = '\0';
        
        /* Skip comments and empty lines */
        if (line_copy[0] == '#' || line_copy[0] == ';' || line_copy[0] == '\0') continue;
        
        /* Section header */
        if (line_copy[0] == '[') {
            char *end = strchr(line_copy, ']');
            if (end) {
                *end = '\0';
                strcpy(current_section, line_copy + 1);
            }
            continue;
        }
        
        /* Key = value */
        char *eq = strchr(line_copy, '=');
        if (!eq) continue;
        
        *eq = '\0';
        char *key = line_copy;
        char *value = eq + 1;
        
        /* Trim key */
        while (*key == ' ' || *key == '\t') key++;
        char *key_end = key + strlen(key) - 1;
        while (key_end > key && (*key_end == ' ' || *key_end == '\t')) *key_end-- = 0;
        
        /* Trim value */
        while (*value == ' ' || *value == '\t') value++;
        char *val_end = value + strlen(value) - 1;
        while (val_end > value && (*val_end == ' ' || *val_end == '\t')) *val_end-- = 0;
        
        /* Load color values */
        if (strcmp(current_section, "colors") == 0) {
            if (strcmp(key, "bg") == 0 || strcmp(key, "base") == 0) {
                strncpy(theme_data.bg, value, sizeof(theme_data.bg) - 1);
            } else if (strcmp(key, "fg") == 0 || strcmp(key, "text") == 0) {
                strncpy(theme_data.fg, value, sizeof(theme_data.fg) - 1);
            } else if (strcmp(key, "accent") == 0 || strcmp(key, "blue") == 0) {
                strncpy(theme_data.accent, value, sizeof(theme_data.accent) - 1);
            } else if (strcmp(key, "red") == 0) {
                strncpy(theme_data.red, value, sizeof(theme_data.red) - 1);
            } else if (strcmp(key, "green") == 0) {
                strncpy(theme_data.green, value, sizeof(theme_data.green) - 1);
            } else if (strcmp(key, "yellow") == 0) {
                strncpy(theme_data.yellow, value, sizeof(theme_data.yellow) - 1);
            } else if (strcmp(key, "surface") == 0 || strcmp(key, "surface1") == 0) {
                strncpy(theme_data.surface, value, sizeof(theme_data.surface) - 1);
            } else if (strcmp(key, "border") == 0) {
                strncpy(theme_data.border, value, sizeof(theme_data.border) - 1);
            }
        }
    }
    
    fclose(f);
    
    return load_theme(name, &theme_data, target, path) != NULL;
}

/* Apply theme to widget */
void apply_theme_to_widget(theme_t *theme, widget_context_t *ctx) {
    if (!theme || !ctx) return;
    
    /* Copy theme to widget context */
    memcpy(&ctx->theme, &theme->theme, sizeof(widget_theme_t));
}

/* Apply theme to cairo rendering */
void apply_theme_to_cairo(cairo_t *cr, const widget_theme_t *theme) {
    if (!cr || !theme) return;
    
    /* Cache theme colors */
    static widget_theme_t cached_theme;
    static double cached_r = -1.0, cached_g = -1.0, cached_b = -1.0, cached_a = -1.0;
    static char cached_bg[32] = {0};
    
    /* Check if theme changed */
    if (strcmp(cached_theme.bg, theme->bg) != 0 || cached_theme.bg_alpha != theme->bg_alpha) {
        /* Update cached theme */
        strcpy(cached_theme.bg, theme->bg);
        cached_theme.bg_alpha = theme->bg_alpha;
        
        /* Parse colors */
        hex_to_rgba(theme->bg, &cached_r, &cached_g, &cached_b, &cached_a);
        
        strcpy(cached_bg, theme->bg);
    }
    
    /* Set background */
    cairo_set_source_rgba(cr, cached_r, cached_g, cached_b, theme->bg_alpha);
}

/* Activate theme */
bool activate_theme(const char *name) {
    for (int i = 0; i < theme_system.theme_count; i++) {
        if (strcmp(theme_system.themes[i].name, name) == 0) {
            /* Deactivate current theme */
            if (theme_system.active_theme) {
                theme_system.active_theme->active = false;
            }
            
            /* Activate new theme */
            theme_system.themes[i].active = true;
            theme_system.active_theme = &theme_system.themes[i];
            theme_system.theme_name = strdup(name);
            
            return true;
        }
    }
    return false;
}

/* Get active theme */
theme_t* get_active_theme() {
    return theme_system.active_theme;
}

/* Get theme by name */
theme_t* get_theme_by_name(const char *name) {
    for (int i = 0; i < theme_system.theme_count; i++) {
        if (strcmp(theme_system.themes[i].name, name) == 0) {
            return &theme_system.themes[i];
        }
    }
    return NULL;
}

/* Check if theme exists */
bool has_theme(const char *name) {
    return get_theme_by_name(name) != NULL;
}

/* List all themes */
void list_themes() {
    printf("Available themes:\n");
    for (int i = 0; i < theme_system.theme_count; i++) {
        printf("  %s%s\n", theme_system.themes[i].name, 
               (theme_system.themes[i].active ? " (active)" : ""));
        printf("    Target: %s\n", theme_target_name(theme_system.themes[i].target));
    }
}

/* Get theme target name */
const char* theme_target_name(theme_target_t target) {
    switch (target) {
        case THEME_TYPE_BAR: return "bar";
        case THEME_TYPE_WIDGET: return "widget";
        case THEME_TYPE_DOCK: return "dock";
        case THEME_TYPE_PANEL: return "panel";
        case THEME_TYPE_GLOBAL: return "global";
        default: return "unknown";
    }
}

/* Apply theme to all components */
void apply_theme_to_all(theme_t *theme) {
    if (!theme) return;
    
    /* Theme would be applied to all registered systems here */
    /* For example: bar systems, widgets, dock, etc. */
}

/* Initialize default themes */
void init_default_themes() {
    widget_theme_t catppuccin_mocha = {0};
    strcpy(catppuccin_mocha.bg, "#1e1e2e");
    strcpy(catppuccin_mocha.fg, "#cdd6f4");
    strcpy(catppuccin_mocha.accent, "#89b4fa");
    strcpy(catppuccin_mocha.green, "#a6e3a1");
    strcpy(catppuccin_mocha.red, "#f38ba8");
    strcpy(catppuccin_mocha.yellow, "#f9e2af");
    strcpy(catppuccin_mocha.surface, "#45475a");
    strcpy(catppuccin_mocha.border, "#585b70");
    catppuccin_mocha.bg_alpha = 0.92;
    
    load_theme("catppuccin-mocha", &catppuccin_mocha, THEME_TYPE_GLOBAL, NULL);
    
    widget_theme_t nord = {0};
    strcpy(nord.bg, "#2e3440");
    strcpy(nord.fg, "#d8dee9");
    strcpy(nord.accent, "#88c0d0");
    strcpy(nord.green, "#a3be8c");
    strcpy(nord.red, "#bf616a");
    strcpy(nord.yellow, "#ebcb8b");
    strcpy(nord.surface, "#3b4252");
    strcpy(nord.border, "#4c566a");
    nord.bg_alpha = 0.95;
    
    load_theme("nord", &nord, THEME_TYPE_GLOBAL, NULL);
    
    widget_theme_t dracula = {0};
    strcpy(dracula.bg, "#282a36");
    strcpy(dracula.fg, "#f8f8f2");
    strcpy(dracula.accent, "#bd93f9");
    strcpy(dracula.green, "#50fa7b");
    strcpy(dracula.red, "#ff5555");
    strcpy(dracula.yellow, "#f1fa8c");
    strcpy(dracula.surface, "#44475a");
    strcpy(dracula.border, "#6272a4");
    dracula.bg_alpha = 0.96;
    
    load_theme("dracula", &dracula, THEME_TYPE_GLOBAL, NULL);
}

/* Cleanup theme system */
void cleanup_theme_system() {
    for (int i = 0; i < theme_system.theme_count; i++) {
        free(theme_system.themes[i].name);
        free(theme_system.themes[i].path);
    }
    
    free(theme_system.themes);
    free(theme_system.theme_name);
}

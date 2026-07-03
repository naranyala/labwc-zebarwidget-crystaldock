/* shared/base-theme.c - Shared theme initialization
 *
 * Provides default themes and theme loading utilities.
 * Used by all widgets and statusbars.
 */

#include "widget.h"

/* Catppuccin Mocha (default) */
static const widget_theme_t theme_catppuccin_mocha = {
    .bg = "#1e1e2e",
    .fg = "#cdd6f4",
    .accent = "#89b4fa",
    .green = "#a6e3a1",
    .red = "#f38ba8",
    .yellow = "#f9e2af",
    .surface = "#45475a",
    .border = "#585b70",
    .bg_alpha = 0.92,
};

/* Nord */
static const widget_theme_t theme_nord = {
    .bg = "#2e3440",
    .fg = "#d8dee9",
    .accent = "#88c0d0",
    .green = "#a3be8c",
    .red = "#bf616a",
    .yellow = "#ebcb8b",
    .surface = "#3b4252",
    .border = "#434c5e",
    .bg_alpha = 0.92,
};

/* Dracula */
static const widget_theme_t theme_dracula = {
    .bg = "#282a36",
    .fg = "#f8f8f2",
    .accent = "#bd93f9",
    .green = "#50fa7b",
    .red = "#ff5555",
    .yellow = "#f1fa8c",
    .surface = "#44475a",
    .border = "#6272a4",
    .bg_alpha = 0.92,
};

/* Tokyo Night */
static const widget_theme_t theme_tokyo_night = {
    .bg = "#1a1b26",
    .fg = "#c0caf5",
    .accent = "#7aa2f7",
    .green = "#9ece6a",
    .red = "#f7768e",
    .yellow = "#e0af68",
    .surface = "#24283b",
    .border = "#414868",
    .bg_alpha = 0.92,
};

/* Get theme by name */
const widget_theme_t *theme_get_by_name(const char *name) {
    if (!name) return &theme_catppuccin_mocha;

    if (strcmp(name, "catppuccin-mocha") == 0) return &theme_catppuccin_mocha;
    if (strcmp(name, "nord") == 0) return &theme_nord;
    if (strcmp(name, "dracula") == 0) return &theme_dracula;
    if (strcmp(name, "tokyo-night") == 0) return &theme_tokyo_night;

    return &theme_catppuccin_mocha;
}

/* Get available theme names */
const char **theme_get_available(int *count) {
    static const char *themes[] = {
        "catppuccin-mocha",
        "nord",
        "dracula",
        "tokyo-night",
        NULL
    };

    if (count) {
        *count = 4;
    }

    return themes;
}

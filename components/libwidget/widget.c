/* widget.c - Core widget implementation */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <time.h>
#include "widget.h"

/* ============================================================================
 * Widget Context
 * ============================================================================ */

widget_context_t *widget_context_create(const widget_ops_t *ops, int width, int height) {
    if (!ops) return NULL;

    widget_context_t *ctx = calloc(1, sizeof(widget_context_t));
    if (!ctx) return NULL;

    ctx->widget = calloc(1, sizeof(widget_t));
    if (!ctx->widget) {
        free(ctx);
        return NULL;
    }

    ctx->widget->ops = ops;
    ctx->widget->width = width;
    ctx->widget->height = height;
    ctx->widget->visible = true;
    ctx->widget->needs_redraw = true;

    ctx->width = width;
    ctx->height = height;

    /* Initialize default theme */
    theme_init_default(&ctx->theme);

    return ctx;
}

void widget_context_destroy(widget_context_t *ctx) {
    if (!ctx) return;

    if (ctx->widget) {
        if (ctx->widget->ops && ctx->widget->ops->destroy) {
            ctx->widget->ops->destroy(ctx);
        }
        free(ctx->widget->priv);
        free(ctx->widget);
    }

    if (ctx->surface) {
        cairo_surface_destroy(ctx->surface);
    }
    if (ctx->layout) {
        g_object_unref(ctx->layout);
    }

    free(ctx);
}

int widget_init(widget_context_t *ctx) {
    if (!ctx || !ctx->widget || !ctx->widget->ops) return -1;

    if (ctx->widget->ops->init) {
        return ctx->widget->ops->init(ctx);
    }
    return 0;
}

void widget_update(widget_context_t *ctx) {
    if (!ctx || !ctx->widget || !ctx->widget->ops) return;

    if (ctx->widget->ops->update) {
        ctx->widget->ops->update(ctx);
    }
    ctx->widget->needs_redraw = true;
}

void widget_render(widget_context_t *ctx) {
    if (!ctx || !ctx->widget || !ctx->widget->ops) return;
    if (!ctx->widget->needs_redraw) return;

    if (ctx->widget->ops->render) {
        ctx->widget->ops->render(ctx, NULL, ctx->width, ctx->height);
    }
    ctx->widget->needs_redraw = false;
}

void widget_resize(widget_context_t *ctx, int width, int height) {
    if (!ctx) return;

    ctx->width = width;
    ctx->height = height;
    ctx->widget->width = width;
    ctx->widget->height = height;
    ctx->widget->needs_redraw = true;
}

/* ============================================================================
 * Provider System
 * ============================================================================ */

widget_provider_t *provider_create(provider_type_t type) {
    widget_provider_t *provider = calloc(1, sizeof(widget_provider_t));
    if (!provider) return NULL;

    provider->type = type;
    provider->active = true;
    provider->data.type = type;

    return provider;
}

void provider_destroy(widget_provider_t *provider) {
    if (!provider) return;
    free(provider->priv);
    free(provider);
}

int provider_update(widget_provider_t *provider) {
    if (!provider || !provider->active) return -1;

    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    provider->data.timestamp = ts.tv_sec * 1000 + ts.tv_nsec / 1000000;

    switch (provider->type) {
        case PROVIDER_CPU:
            return provider_update_cpu(provider);
        case PROVIDER_MEMORY:
            return provider_update_memory(provider);
        case PROVIDER_NETWORK:
            return provider_update_network(provider);
        case PROVIDER_BATTERY:
            return provider_update_battery(provider);
        case PROVIDER_VOLUME:
            return provider_update_volume(provider);
        case PROVIDER_DATE:
            return provider_update_date(provider);
        default:
            return -1;
    }
}

const provider_data_t *provider_get_data(widget_provider_t *provider) {
    if (!provider) return NULL;
    return &provider->data;
}

/* ============================================================================
 * Theme
 * ============================================================================ */

void theme_init_default(widget_theme_t *theme) {
    if (!theme) return;

    /* Catppuccin Mocha */
    strcpy(theme->bg, "#1e1e2e");
    strcpy(theme->fg, "#cdd6f4");
    strcpy(theme->accent, "#89b4fa");
    strcpy(theme->green, "#a6e3a1");
    strcpy(theme->red, "#f38ba8");
    strcpy(theme->yellow, "#f9e2af");
    strcpy(theme->surface, "#45475a");
    strcpy(theme->border, "#585b70");
    theme->bg_alpha = 0.92;
}

int theme_load_from_ini(widget_theme_t *theme, const char *path) {
    if (!theme || !path) return -1;

    FILE *f = fopen(path, "r");
    if (!f) return -1;

    char line[256];
    char current_section[64] = "";

    while (fgets(line, sizeof(line), f)) {
        /* Remove newline */
        line[strcspn(line, "\r\n")] = 0;

        /* Skip empty lines and comments */
        if (line[0] == 0 || line[0] == '#' || line[0] == ';') continue;

        /* Section header */
        if (line[0] == '[') {
            char *end = strchr(line, ']');
            if (end) {
                *end = 0;
                strcpy(current_section, line + 1);
            }
            continue;
        }

        /* Key = value */
        char *eq = strchr(line, '=');
        if (!eq) continue;

        *eq = 0;
        char *key = line;
        char *value = eq + 1;

        /* Trim key */
        while (*key == ' ' || *key == '\t') key++;
        char *key_end = key + strlen(key) - 1;
        while (key_end > key && (*key_end == ' ' || *key_end == '\t')) *key_end-- = 0;

        /* Trim value */
        while (*value == ' ' || *value == '\t') value++;
        char *val_end = value + strlen(value) - 1;
        while (val_end > value && (*val_end == ' ' || *val_end == '\t')) *val_end-- = 0;

        /* Apply to theme if in [panel] or [colors] section */
        if (strcmp(current_section, "panel") == 0 || strcmp(current_section, "colors") == 0) {
            if (strcmp(key, "bar_bg") == 0 || strcmp(key, "base") == 0) {
                strncpy(theme->bg, value, sizeof(theme->bg) - 1);
            } else if (strcmp(key, "bar_text") == 0 || strcmp(key, "text") == 0) {
                strncpy(theme->fg, value, sizeof(theme->fg) - 1);
            } else if (strcmp(key, "bar_active") == 0 || strcmp(key, "blue") == 0) {
                strncpy(theme->accent, value, sizeof(theme->accent) - 1);
            } else if (strcmp(key, "bar_urgent") == 0 || strcmp(key, "red") == 0) {
                strncpy(theme->red, value, sizeof(theme->red) - 1);
            } else if (strcmp(key, "green") == 0) {
                strncpy(theme->green, value, sizeof(theme->green) - 1);
            } else if (strcmp(key, "yellow") == 0) {
                strncpy(theme->yellow, value, sizeof(theme->yellow) - 1);
            } else if (strcmp(key, "surface0") == 0 || strcmp(key, "surface1") == 0) {
                strncpy(theme->surface, value, sizeof(theme->surface) - 1);
            } else if (strcmp(key, "surface2") == 0) {
                strncpy(theme->border, value, sizeof(theme->border) - 1);
            }
        }
    }

    fclose(f);
    return 0;
}

void theme_apply_to_css(const widget_theme_t *theme, char *css, size_t len) {
    if (!theme || !css) return;

    snprintf(css, len,
        ":root {\n"
        "  --bg: %s;\n"
        "  --fg: %s;\n"
        "  --accent: %s;\n"
        "  --green: %s;\n"
        "  --red: %s;\n"
        "  --yellow: %s;\n"
        "  --surface: %s;\n"
        "  --border: %s;\n"
        "  --bg-alpha: %.2f;\n"
        "}\n",
        theme->bg, theme->fg, theme->accent,
        theme->green, theme->red, theme->yellow,
        theme->surface, theme->border,
        theme->bg_alpha);
}

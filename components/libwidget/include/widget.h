/* libwidget - Shared widget library for Wayland-native widgets
 *
 * Provides:
 * - Widget interface and lifecycle management
 * - Wayland layer-shell integration
 * - System data providers (CPU, memory, network, etc.)
 * - Cairo/Pango rendering helpers
 */

#ifndef LIBWIDGET_H
#define LIBWIDGET_H

#include <stdint.h>
#include <stdbool.h>
#include <cairo.h>
#include <pango/pangocairo.h>

/* Forward declarations */
typedef struct widget_t widget_t;
typedef struct widget_context_t widget_context_t;
typedef struct widget_provider_t widget_provider_t;
typedef struct widget_config_t widget_config_t;

/* ============================================================================
 * Widget Interface
 * ============================================================================ */

/* Widget operations - implement these in your widget */
typedef struct widget_ops_t {
    const char *name;
    const char *description;

    /* Lifecycle */
    int  (*init)(widget_context_t *ctx);
    void (*destroy)(widget_context_t *ctx);

    /* Update (called on timer or event) */
    void (*update)(widget_context_t *ctx);

    /* Render (called after update) */
    void (*render)(widget_context_t *ctx, cairo_t *cr, int width, int height);

    /* Optional: handle input events */
    void (*on_click)(widget_context_t *ctx, int x, int y);
    void (*on_scroll)(widget_context_t *ctx, int delta);
} widget_ops_t;

/* Widget instance */
struct widget_t {
    const widget_ops_t *ops;
    void *priv;  /* Private data for the widget */
    int x, y, width, height;
    bool visible;
    bool needs_redraw;
};

/* ============================================================================
 * Widget Context
 * ============================================================================ */

/* Theme colors */
typedef struct widget_theme_t {
    char bg[32];
    char fg[32];
    char accent[32];
    char green[32];
    char red[32];
    char yellow[32];
    char surface[32];
    char border[32];
    double bg_alpha;
} widget_theme_t;

/* Widget context - passed to all widget operations */
struct widget_context_t {
    widget_t *widget;
    widget_theme_t theme;

    /* Wayland state (internal) */
    void *wayland;

    /* Render state */
    cairo_surface_t *surface;
    PangoLayout *layout;
    int width, height;

    /* Provider data */
    void *provider_data;

    /* User data */
    void *user_data;
};

/* ============================================================================
 * Widget Provider System
 * ============================================================================ */

/* Provider types */
typedef enum {
    PROVIDER_CPU,
    PROVIDER_MEMORY,
    PROVIDER_NETWORK,
    PROVIDER_BATTERY,
    PROVIDER_VOLUME,
    PROVIDER_DATE,
    PROVIDER_WEATHER,
} provider_type_t;

/* CPU data */
typedef struct provider_cpu_t {
    double usage;
    int cores;
    double temperature;
} provider_cpu_t;

/* Memory data */
typedef struct provider_memory_t {
    double usage;
    uint64_t total;
    uint64_t used;
    uint64_t free;
    double swap_usage;
} provider_memory_t;

/* Network data */
typedef struct provider_network_t {
    bool connected;
    char ssid[64];
    char interface[16];
    double signal_strength;
    bool is_wifi;
    bool is_ethernet;
} provider_network_t;

/* Battery data */
typedef struct provider_battery_t {
    double charge_percent;
    bool is_charging;
    bool is_present;
    int time_to_empty;  /* seconds */
    int time_to_full;   /* seconds */
} provider_battery_t;

/* Volume data */
typedef struct provider_volume_t {
    double level;
    bool muted;
    char sink_name[64];
} provider_volume_t;

/* Date data */
typedef struct provider_date_t {
    int year, month, day;
    int hour, minute, second;
    char formatted[64];
    char time_only[16];
    char date_only[32];
} provider_date_t;

/* Provider data union */
typedef struct provider_data_t {
    provider_type_t type;
    union {
        provider_cpu_t cpu;
        provider_memory_t memory;
        provider_network_t network;
        provider_battery_t battery;
        provider_volume_t volume;
        provider_date_t date;
    };
    uint64_t timestamp;  /* Last update time in ms */
} provider_data_t;

/* Provider handle */
struct widget_provider_t {
    provider_type_t type;
    bool active;
    provider_data_t data;
    void *priv;
};

/* ============================================================================
 * Core API
 * ============================================================================ */

/* Create a widget context */
widget_context_t *widget_context_create(const widget_ops_t *ops, int width, int height);

/* Destroy a widget context */
void widget_context_destroy(widget_context_t *ctx);

/* Initialize the widget */
int widget_init(widget_context_t *ctx);

/* Update widget data */
void widget_update(widget_context_t *ctx);

/* Render widget to surface */
void widget_render(widget_context_t *ctx);

/* Resize widget */
void widget_resize(widget_context_t *ctx, int width, int height);

/* ============================================================================
 * Provider API
 * ============================================================================ */

/* Create a provider */
widget_provider_t *provider_create(provider_type_t type);

/* Destroy a provider */
void provider_destroy(widget_provider_t *provider);

/* Update provider data */
int provider_update(widget_provider_t *provider);

/* Get provider data */
const provider_data_t *provider_get_data(widget_provider_t *provider);

/* ============================================================================
 * Theme API
 * ============================================================================ */

/* Initialize default theme (Catppuccin Mocha) */
void theme_init_default(widget_theme_t *theme);

/* Load theme from INI file */
int theme_load_from_ini(widget_theme_t *theme, const char *path);

/* Apply theme to CSS variables */
void theme_apply_to_css(const widget_theme_t *theme, char *css, size_t len);

/* ============================================================================
 * Wayland Integration
 * ============================================================================ */

/* Wayland display context */
typedef struct wayland_display_t wayland_display_t;

/* Create Wayland display */
wayland_display_t *wayland_display_create(void);

/* Destroy Wayland display */
void wayland_display_destroy(wayland_display_t *display);

/* Create layer surface */
typedef struct wayland_surface_t wayland_surface_t;

/* Layer shell anchor */
typedef enum {
    LAYER_ANCHOR_TOP    = 1,
    LAYER_ANCHOR_BOTTOM = 2,
    LAYER_ANCHOR_LEFT   = 4,
    LAYER_ANCHOR_RIGHT  = 8,
    LAYER_ANCHOR_ALL    = 15,
} layer_anchor_t;

/* Layer shell layer */
typedef enum {
    LAYER_BACKGROUND = 0,
    LAYER_BOTTOM     = 1,
    LAYER_TOP        = 2,
    LAYER_OVERLAY    = 3,
} layer_layer_t;

/* Create layer surface */
wayland_surface_t *wayland_surface_create(
    wayland_display_t *display,
    layer_layer_t layer,
    layer_anchor_t anchor,
    int exclusive_zone,
    int width,
    int height);

/* Destroy layer surface */
void wayland_surface_destroy(wayland_surface_t *surface);

/* Get surface width/height */
void wayland_surface_get_size(wayland_surface_t *surface, int *width, int *height);

/* Set surface title */
void wayland_surface_set_title(wayland_surface_t *surface, const char *title);

/* Commit surface (after rendering) */
void wayland_surface_commit(wayland_surface_t *surface);

/* Get cairo surface for rendering */
cairo_surface_t *wayland_surface_get_cairo(wayland_surface_t *surface);

/* Run Wayland event loop */
int wayland_display_run(wayland_display_t *display);

/* Stop Wayland event loop */
void wayland_display_stop(wayland_display_t *display);

/* ============================================================================
 * Render Helpers
 * ============================================================================ */

/* Create Pango layout */
PangoLayout *render_create_layout(cairo_t *cr, const char *font, int size);

/* Render text */
void render_text(cairo_t *cr, PangoLayout *layout,
                 int x, int y, const char *text,
                 const char *color, int font_size);

/* Render icon (nerd font) */
void render_icon(cairo_t *cr, PangoLayout *layout,
                 int x, int y, const char *icon,
                 const char *color, int font_size);

/* Render rounded rectangle */
void render_rounded_rect(cairo_t *cr,
                         double x, double y, double w, double h,
                         double radius, const char *color, double alpha);

/* Render progress bar */
void render_progress_bar(cairo_t *cr,
                         double x, double y, double w, double h,
                         double progress, const char *bg_color, const char *fg_color);

/* Convert hex color to RGBA */
void hex_to_rgba(const char *hex, double *r, double *g, double *b, double *a);

#endif /* LIBWIDGET_H */

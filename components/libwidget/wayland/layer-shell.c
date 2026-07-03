/* wayland/layer-shell.c - Wayland layer-shell integration
 *
 * Provides Wayland surface management using wlr-layer-shell protocol.
 * This allows widgets to be displayed as panels, overlays, etc.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>
#include "widget.h"

/* Include generated protocol headers */
#include "wlr-layer-shell-unstable-v1-client-protocol.h"

/* ============================================================================
 * Internal Structures
 * ============================================================================ */

struct wayland_display_t {
    struct wl_display *display;
    struct wl_registry *registry;
    struct wl_compositor *compositor;
    struct zwlr_layer_shell_v1 *layer_shell;

    /* Output tracking */
    struct wl_output *output;
    int output_width, output_height;
    int output_scale;

    /* Event loop */
    int running;
    int poll_fd;
};

struct wayland_surface_t {
    wayland_display_t *display;
    struct wl_surface *surface;
    struct zwlr_layer_surface_v1 *layer_surface;

    /* State */
    layer_layer_t layer;
    layer_anchor_t anchor;
    int exclusive_zone;
    int width, height;
    int scale;
    bool configured;

    /* Buffer */
    struct wl_buffer *buffer;
    cairo_surface_t *cairo_surface;
    uint8_t *data;
    size_t data_size;
};

/* ============================================================================
 * Wayland Callbacks
 * ============================================================================ */

static void registry_global(void *data, struct wl_registry *registry,
                            uint32_t name, const char *interface, uint32_t version) {
    wayland_display_t *display = data;

    if (strcmp(interface, wl_compositor_interface.name) == 0) {
        display->compositor = wl_registry_bind(registry, name,
                                               &wl_compositor_interface, 4);
    } else if (strcmp(interface, zwlr_layer_shell_v1_interface.name) == 0) {
        display->layer_shell = wl_registry_bind(registry, name,
                                                &zwlr_layer_shell_v1_interface, 4);
    } else if (strcmp(interface, wl_output_interface.name) == 0) {
        display->output = wl_registry_bind(registry, name,
                                           &wl_output_interface, 4);
    }
}

static void registry_global_remove(void *data, struct wl_registry *registry, uint32_t name) {
    /* Handle output removal if needed */
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

/* Layer surface callbacks */
static void layer_surface_configure(void *data,
                                    struct zwlr_layer_surface_v1 *surface,
                                    uint32_t serial,
                                    uint32_t width, uint32_t height) {
    wayland_surface_t *ws = data;
    ws->width = width;
    ws->height = height;
    ws->configured = true;

    /* Acknowledge configure */
    zwlr_layer_surface_v1_ack_configure(surface, serial);

    /* Recreate buffer if needed */
    if (ws->cairo_surface) {
        cairo_surface_destroy(ws->cairo_surface);
        ws->cairo_surface = NULL;
    }
}

static void layer_surface_closed(void *data,
                                 struct zwlr_layer_surface_v1 *surface) {
    wayland_surface_t *ws = data;
    ws->configured = false;
}

static const struct zwlr_layer_surface_v1_listener layer_surface_listener = {
    .configure = layer_surface_configure,
    .closed = layer_surface_closed,
};

/* ============================================================================
 * Display Management
 * ============================================================================ */

wayland_display_t *wayland_display_create(void) {
    wayland_display_t *display = calloc(1, sizeof(wayland_display_t));
    if (!display) return NULL;

    display->display = wl_display_connect(NULL);
    if (!display->display) {
        fprintf(stderr, "Failed to connect to Wayland display\n");
        free(display);
        return NULL;
    }

    display->registry = wl_display_get_registry(display->display);
    wl_registry_add_listener(display->registry, &registry_listener, display);

    /* Roundtrip to get globals */
    wl_display_roundtrip(display->display);

    if (!display->compositor || !display->layer_shell) {
        fprintf(stderr, "Missing Wayland interfaces (compositor: %p, layer-shell: %p)\n",
                display->compositor, display->layer_shell);
        wl_display_disconnect(display->display);
        free(display);
        return NULL;
    }

    display->running = true;

    return display;
}

void wayland_display_destroy(wayland_display_t *display) {
    if (!display) return;

    if (display->layer_shell) {
        zwlr_layer_shell_v1_destroy(display->layer_shell);
    }
    if (display->compositor) {
        wl_compositor_destroy(display->compositor);
    }
    if (display->registry) {
        wl_registry_destroy(display->registry);
    }
    if (display->display) {
        wl_display_disconnect(display->display);
    }

    free(display);
}

int wayland_display_run(wayland_display_t *display) {
    if (!display) return -1;

    while (display->running && wl_display_dispatch(display->display) != -1) {
        /* Event loop - callbacks handle everything */
    }

    return 0;
}

void wayland_display_stop(wayland_display_t *display) {
    if (display) {
        display->running = false;
    }
}

/* ============================================================================
 * Surface Management
 * ============================================================================ */

static void create_buffer(wayland_surface_t *ws) {
    if (ws->buffer) {
        wl_buffer_destroy(ws->buffer);
    }
    if (ws->data) {
        free(ws->data);
    }

    int scale = ws->scale > 0 ? ws->scale : 1;
    int width = ws->width * scale;
    int height = ws->height * scale;

    /* Cairo ARGB format */
    int stride = cairo_format_stride_for_width(CAIRO_FORMAT_ARGB32, width);
    ws->data_size = stride * height;
    ws->data = calloc(1, ws->data_size);

    /* Create wl_buffer */
    struct wl_shm *shm = NULL;  /* Would need to get this from registry */
    if (!shm) {
        fprintf(stderr, "Warning: wl_shm not available, buffer creation skipped\n");
        return;
    }

    /* TODO: Create SHM pool and buffer */
    /* For now, we'll use a simple approach */
}

wayland_surface_t *wayland_surface_create(
    wayland_display_t *display,
    layer_layer_t layer,
    layer_anchor_t anchor,
    int exclusive_zone,
    int width,
    int height)
{
    if (!display || !display->compositor || !display->layer_shell) {
        return NULL;
    }

    wayland_surface_t *ws = calloc(1, sizeof(wayland_surface_t));
    if (!ws) return NULL;

    ws->display = display;
    ws->layer = layer;
    ws->anchor = anchor;
    ws->exclusive_zone = exclusive_zone;
    ws->width = width;
    ws->height = height;
    ws->scale = 1;

    /* Create Wayland surface */
    ws->surface = wl_compositor_create_surface(display->compositor);
    if (!ws->surface) {
        fprintf(stderr, "Failed to create Wayland surface\n");
        free(ws);
        return NULL;
    }

    /* Create layer surface */
    uint32_t wlr_layer;
    switch (layer) {
        case LAYER_BACKGROUND: wlr_layer = ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND; break;
        case LAYER_BOTTOM:     wlr_layer = ZWLR_LAYER_SHELL_V1_LAYER_BOTTOM; break;
        case LAYER_TOP:        wlr_layer = ZWLR_LAYER_SHELL_V1_LAYER_TOP; break;
        case LAYER_OVERLAY:    wlr_layer = ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY; break;
        default:               wlr_layer = ZWLR_LAYER_SHELL_V1_LAYER_TOP; break;
    }

    uint32_t wlr_anchor = 0;
    if (anchor & LAYER_ANCHOR_TOP)    wlr_anchor |= ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP;
    if (anchor & LAYER_ANCHOR_BOTTOM) wlr_anchor |= ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM;
    if (anchor & LAYER_ANCHOR_LEFT)   wlr_anchor |= ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT;
    if (anchor & LAYER_ANCHOR_RIGHT)  wlr_anchor |= ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT;

    ws->layer_surface = zwlr_layer_shell_v1_get_layer_surface(
        display->layer_shell,
        ws->surface,
        display->output,
        wlr_layer,
        "labwc-widget");

    if (!ws->layer_surface) {
        fprintf(stderr, "Failed to create layer surface\n");
        wl_surface_destroy(ws->surface);
        free(ws);
        return NULL;
    }

    /* Configure layer surface */
    zwlr_layer_surface_v1_set_size(ws->layer_surface, width, height);
    zwlr_layer_surface_v1_set_anchor(ws->layer_surface, wlr_anchor);
    zwlr_layer_surface_v1_set_exclusive_zone(ws->layer_surface, exclusive_zone);

    /* Add listener */
    zwlr_layer_surface_v1_add_listener(ws->layer_surface,
                                       &layer_surface_listener, ws);

    /* Commit to trigger configure */
    wl_surface_commit(ws->surface);

    /* Wait for configure */
    wl_display_roundtrip(display->display);

    return ws;
}

void wayland_surface_destroy(wayland_surface_t *surface) {
    if (!surface) return;

    if (surface->cairo_surface) {
        cairo_surface_destroy(surface->cairo_surface);
    }
    if (surface->buffer) {
        wl_buffer_destroy(surface->buffer);
    }
    if (surface->data) {
        free(surface->data);
    }
    if (surface->layer_surface) {
        zwlr_layer_surface_v1_destroy(surface->layer_surface);
    }
    if (surface->surface) {
        wl_surface_destroy(surface->surface);
    }

    free(surface);
}

void wayland_surface_get_size(wayland_surface_t *surface, int *width, int *height) {
    if (!surface) return;
    if (width) *width = surface->width;
    if (height) *height = surface->height;
}

void wayland_surface_set_title(wayland_surface_t *surface, const char *title) {
    /* Layer surfaces don't have titles, but we can store it */
    /* This is mainly for debugging */
}

void wayland_surface_commit(wayland_surface_t *surface) {
    if (!surface || !surface->surface) return;

    /* TODO: Attach buffer and commit */
    wl_surface_commit(surface->surface);
}

cairo_surface_t *wayland_surface_get_cairo(wayland_surface_t *surface) {
    if (!surface) return NULL;

    if (!surface->cairo_surface && surface->data) {
        int stride = cairo_format_stride_for_width(CAIRO_FORMAT_ARGB32, surface->width);
        surface->cairo_surface = cairo_image_surface_create_for_data(
            surface->data, CAIRO_FORMAT_ARGB32,
            surface->width, surface->height, stride);
    }

    return surface->cairo_surface;
}

// dock.c — Dock rendering via Blend2D (C implementation)
#include "dock.h"
#include "blend2d_render.h"
#include "icon.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int dock_icon_size = 28;

#define FOCUS_BAR_H 3
#define SIDE_PAD 12

static int icon_x(int slot_idx, int start_x) {
    return start_x + slot_idx * (dock_icon_size + DOCK_PAD);
}

void dock_draw(struct BlendRenderer* renderer, int w, int h,
               const char** app_ids, const char** titles, int* focused,
               int top_count, int hover_idx) {
    if (!renderer) return;

    // The app_ids/titles/focused arrays are caller-allocated with a fixed
    // capacity (64). Clamp the loop bound so we never read past them even if
    // the caller passes a larger top_count (e.g. >64 open windows).
    if (top_count > 64) top_count = 64;

    // Background gradient (two-tone)
    blend_renderer_fill_rect(renderer, 0, 0, (double)w, (double)h / 2.0, 0xFF141419);
    blend_renderer_fill_rect(renderer, 0, (double)h / 2.0, (double)w, (double)h / 2.0, 0xFF0D0D12);

    // Top border
    blend_renderer_fill_rect(renderer, 0, 0, (double)w, 1, 0xFF404045);

    int cy = (h - dock_icon_size) / 2;
    int slot = dock_icon_size + DOCK_PAD;
    int total_w = top_count > 0 ? top_count * slot - DOCK_PAD : 0;
    int start_x = (w - total_w) / 2;
    if (start_x < 0) start_x = 0;

    // Draw app icons
    for (int i = 0; i < top_count; i++) {
        int x = icon_x(i, start_x);

        // Rounded backdrop tile so icons read clearly against the gradient.
        // Hover gets a brighter tile; non-hover a subtle one.
        uint32_t tile = (i == hover_idx) ? 0x33FFFFFF : 0x14FFFFFF;
        blend_renderer_fill_round_rect(renderer, (double)(x - 4), (double)(cy - 4),
            (double)(dock_icon_size + 8), (double)(dock_icon_size + 8), 8.0, tile);

        // Load or fallback icon
        struct BLImageCore* icon_img = NULL;
        const char* name = app_ids[i];
        if (!name || !name[0]) name = titles[i];
        if (!name) name = "unknown";

        struct BLImageCore loaded = {0};
        if (icon_load(name, dock_icon_size, &loaded)) {
            icon_img = &loaded;
        } else {
            icon_img = icon_fallback(name, dock_icon_size);
        }

        // Draw icon (scale to fit dock_icon_size)
        if (icon_img) {
            blend_renderer_draw_image_scaled(renderer, icon_img, (double)x, (double)cy,
                (double)dock_icon_size, (double)dock_icon_size);
        }

        // Focus bar (below the icon)
        if (focused && focused[i]) {
            blend_renderer_fill_round_rect(renderer, (double)(x + 2), (double)(cy + dock_icon_size + 2),
                (double)(dock_icon_size - 4), (double)FOCUS_BAR_H, (double)FOCUS_BAR_H / 2.0, 0xFF4C7FBF);
        }
    }

    // ---- Separated bar: settings + app-launcher toggles ----
    // A vertical divider separates the running-app icons from the fixed
    // toggles, which are placed like pinned icons on the right.
    int icon_right = start_x + total_w;
    int toggle_start = icon_right + DOCK_PAD;
    int divider_x = icon_right + DOCK_PAD / 2;
    blend_renderer_fill_rect(renderer, (double)divider_x, 6, 1, h - 12, 0xFF404045);

    // Settings toggle
    int settings_tile = toggle_start - 4;
    blend_renderer_fill_round_rect(renderer, (double)settings_tile, (double)(cy - 4),
        (double)(dock_icon_size + 8), (double)(dock_icon_size + 8), 8.0, 0x14FFFFFF);
    struct BLImageCore settings_img = {0};
    if (icon_load("preferences-system", dock_icon_size, &settings_img)) {
        blend_renderer_draw_image_scaled(renderer, &settings_img, (double)toggle_start, (double)cy,
            (double)dock_icon_size, (double)dock_icon_size);
    }

    // App launcher toggle
    int launcher_toggle_x = toggle_start + dock_icon_size + DOCK_PAD;
    int launcher_tile = launcher_toggle_x - 4;
    blend_renderer_fill_round_rect(renderer, (double)launcher_tile, (double)(cy - 4),
        (double)(dock_icon_size + 8), (double)(dock_icon_size + 8), 8.0, 0x14FFFFFF);
    struct BLImageCore launcher_img = {0};
    if (icon_load("system-search", dock_icon_size, &launcher_img)) {
        blend_renderer_draw_image_scaled(renderer, &launcher_img, (double)launcher_toggle_x, (double)cy,
            (double)dock_icon_size, (double)dock_icon_size);
    }
}

int dock_icon_at(int w, int h, int top_count, int mouse_x) {
    (void)h;
    int slot = dock_icon_size + DOCK_PAD;
    int total_w = top_count > 0 ? top_count * slot - DOCK_PAD : 0;
    int start_x = (w - total_w) / 2;
    if (start_x < 0) start_x = 0;

    // Separated-bar toggles (settings + app launcher), to the right of the
    // apps. These mirror the icons drawn in dock_draw(): settings first, then
    // the launcher toggle which opens the full .desktop app grid.
    int icon_right = start_x + total_w;
    int toggle_start = icon_right + DOCK_PAD;
    int settings_x = toggle_start;
    int launcher_toggle_x = toggle_start + dock_icon_size + DOCK_PAD;
    if (mouse_x >= settings_x && mouse_x < settings_x + dock_icon_size + DOCK_PAD) {
        return -2; // settings toggle
    }
    if (mouse_x >= launcher_toggle_x && mouse_x < launcher_toggle_x + dock_icon_size + DOCK_PAD) {
        return -3; // app-launcher toggle: opens the full .desktop app grid
    }

    // Check app icons
    for (int i = 0; i < top_count; i++) {
        int x = icon_x(i, start_x);
        if (mouse_x >= x && mouse_x < x + dock_icon_size + DOCK_PAD) return i;
    }
    return -1;
}

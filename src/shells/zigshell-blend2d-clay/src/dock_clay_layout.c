// dock_clay_layout.c — Clay layout for the dock bar
// Uses Clay 0.14 API with .wrapped prefix pattern.

#include "clay.h"
#include <stdio.h>
#include <string.h>

// Dock constants (matching dock.c)
#define DOCK_ICON_SIZE 28
#define DOCK_PAD 8
#define DOCK_HEIGHT 48
#define FOCUS_BAR_H 3
#define TOGGLE_COUNT 2  // settings + launcher

typedef struct {
    int top_count;
    int hover_idx;
    int settings_hover;
    int launcher_hover;
} DockState;

// Flatten dock Clay commands into the shared flat command buffer
extern void dock_flatten_begin(void);
extern void dock_flatten_cmd(int type, float x, float y, float w, float h,
                             float bg_r, float bg_g, float bg_b, float bg_a,
                             float radius, int font_size,
                             float tc_r, float tc_g, float tc_b, float tc_a,
                             int text_len, const char* text_ptr,
                             float bc_r, float bc_g, float bc_b, float bc_a);

int clay_layout_dock_bar(int width, int height, DockState* state) {
    Clay_BeginLayout();

    // Root: full-width dock bar
    Clay_LayoutConfig root = (Clay_LayoutConfig){
        .sizing = { CLAY_SIZING_FIXED(width), CLAY_SIZING_FIXED(height) },
    };
    CLAY(CLAY_ID("DockRoot"), .wrapped = {
        .layout = root,
        .backgroundColor = { 20, 20, 28, 240 },
    }) {
        // Dock content row: horizontal, centered
        int icon_area_w = state->top_count * (DOCK_ICON_SIZE + DOCK_PAD) - DOCK_PAD;
        int toggle_area_w = TOGGLE_COUNT * (DOCK_ICON_SIZE + DOCK_PAD);
        int divider_w = 1;
        int total_content_w = icon_area_w + DOCK_PAD + divider_w + DOCK_PAD + toggle_area_w;
        int left_pad = (width - total_content_w) / 2;
        if (left_pad < 0) left_pad = 0;

        // Top border line
        Clay_LayoutConfig border_row = (Clay_LayoutConfig){
            .sizing = { CLAY_SIZING_GROW(0, 0), CLAY_SIZING_FIXED(1) },
        };
        Clay__OpenElementWithId(Clay__HashString(CLAY_STRING("TopBorder"), 0));
        Clay__ConfigureOpenElement((Clay_ElementDeclaration){
            .layout = border_row,
            .backgroundColor = { 64, 64, 69, 255 },
        });
        Clay__CloseElement();

        // Main content row
        Clay_LayoutConfig content_row = (Clay_LayoutConfig){
            .sizing = { CLAY_SIZING_GROW(0, 0), CLAY_SIZING_GROW(0, 0) },
            .layoutDirection = CLAY_LEFT_TO_RIGHT,
            .childAlignment = { CLAY_ALIGN_X_CENTER, CLAY_ALIGN_Y_CENTER },
        };
        CLAY(CLAY_ID("DockContent"), .wrapped = { .layout = content_row }) {

            // App icons area
            Clay_LayoutConfig icons_row = (Clay_LayoutConfig){
                .sizing = { CLAY_SIZING_FIXED(icon_area_w > 0 ? icon_area_w : 1), CLAY_SIZING_GROW(0, 0) },
                .layoutDirection = CLAY_LEFT_TO_RIGHT,
                .childGap = DOCK_PAD,
                .childAlignment = { CLAY_ALIGN_X_CENTER, CLAY_ALIGN_Y_CENTER },
            };
            CLAY(CLAY_ID("IconsArea"), .wrapped = { .layout = icons_row }) {
                for (int i = 0; i < state->top_count && i < 32; i++) {
                    // Each icon slot: a container with icon + focus bar
                    Clay_LayoutConfig icon_slot = (Clay_LayoutConfig){
                        .sizing = { CLAY_SIZING_FIXED(DOCK_ICON_SIZE), CLAY_SIZING_FIXED(DOCK_ICON_SIZE + FOCUS_BAR_H + 2) },
                        .layoutDirection = CLAY_TOP_TO_BOTTOM,
                        .childAlignment = { CLAY_ALIGN_X_CENTER, CLAY_ALIGN_Y_TOP },
                    };

                    char id_buf[32];
                    int len = snprintf(id_buf, sizeof(id_buf), "Icon%d", i);
                    Clay_String id_str = { .length = len, .chars = id_buf, .isStaticallyAllocated = 0 };
                    Clay_ElementId eid = Clay__HashString(id_str, 0);

                    // Hover highlight background
                    float bg_a = (i == state->hover_idx) ? 50.0f : 0.0f;

                    Clay__OpenElementWithId(eid);
                    Clay__ConfigureOpenElement((Clay_ElementDeclaration){
                        .layout = icon_slot,
                        .backgroundColor = { 255, 255, 255, bg_a },
                        .cornerRadius = CLAY_CORNER_RADIUS(6),
                    });
                    Clay__CloseElement();
                }
            }

            // Divider
            Clay_LayoutConfig divider = (Clay_LayoutConfig){
                .sizing = { CLAY_SIZING_FIXED(divider_w), CLAY_SIZING_GROW(0, 0) },
            };
            Clay__OpenElementWithId(Clay__HashString(CLAY_STRING("Divider"), 0));
            Clay__ConfigureOpenElement((Clay_ElementDeclaration){
                .layout = divider,
                .backgroundColor = { 64, 64, 69, 255 },
            });
            Clay__CloseElement();

            // Spacer
            Clay_LayoutConfig spacer = (Clay_LayoutConfig){
                .sizing = { CLAY_SIZING_FIXED(DOCK_PAD), CLAY_SIZING_GROW(0, 0) },
            };
            Clay__OpenElementWithId(Clay__HashString(CLAY_STRING("Spacer"), 0));
            Clay__ConfigureOpenElement((Clay_ElementDeclaration){
                .layout = spacer,
            });
            Clay__CloseElement();

            // Toggle icons (settings + launcher)
            Clay_LayoutConfig toggles_row = (Clay_LayoutConfig){
                .sizing = { CLAY_SIZING_FIXED(toggle_area_w), CLAY_SIZING_GROW(0, 0) },
                .layoutDirection = CLAY_LEFT_TO_RIGHT,
                .childGap = DOCK_PAD,
                .childAlignment = { CLAY_ALIGN_X_CENTER, CLAY_ALIGN_Y_CENTER },
            };
            CLAY(CLAY_ID("Toggles"), .wrapped = { .layout = toggles_row }) {
                // Settings toggle
                Clay_LayoutConfig toggle_slot = (Clay_LayoutConfig){
                    .sizing = { CLAY_SIZING_FIXED(DOCK_ICON_SIZE), CLAY_SIZING_FIXED(DOCK_ICON_SIZE) },
                    .childAlignment = { CLAY_ALIGN_X_CENTER, CLAY_ALIGN_Y_CENTER },
                };
                float settings_bg = state->settings_hover ? 50.0f : 0.0f;
                Clay__OpenElementWithId(Clay__HashString(CLAY_STRING("SettingsToggle"), 0));
                Clay__ConfigureOpenElement((Clay_ElementDeclaration){
                    .layout = toggle_slot,
                    .backgroundColor = { 255, 255, 255, settings_bg },
                    .cornerRadius = CLAY_CORNER_RADIUS(6),
                });
                Clay__CloseElement();

                // Launcher toggle
                float launcher_bg = state->launcher_hover ? 50.0f : 0.0f;
                Clay__OpenElementWithId(Clay__HashString(CLAY_STRING("LauncherToggle"), 0));
                Clay__ConfigureOpenElement((Clay_ElementDeclaration){
                    .layout = toggle_slot,
                    .backgroundColor = { 255, 255, 255, launcher_bg },
                    .cornerRadius = CLAY_CORNER_RADIUS(6),
                });
                Clay__CloseElement();
            }
        }
    }

    Clay_RenderCommandArray cmds = Clay_EndLayout(0.0f);
    return cmds.length;
}

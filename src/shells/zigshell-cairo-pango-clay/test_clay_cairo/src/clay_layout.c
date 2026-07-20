// clay_layout.c — Clay 0.14 API (renderer-agnostic layouts)
#define CLAY_IMPLEMENTATION
#include "clay.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static uint8_t* clay_arena = NULL;

void clay_init(int w, int h) {
    size_t sz = Clay_MinMemorySize();
    clay_arena = (uint8_t*)malloc(sz);
    Clay_Arena a = Clay_CreateArenaWithCapacityAndMemory(sz, clay_arena);
    Clay_Initialize(a, (Clay_Dimensions){ (float)w, (float)h }, (Clay_ErrorHandler){ 0 });
}

void clay_cleanup(void) { if (clay_arena) { free(clay_arena); clay_arena = NULL; } }

static Clay_Dimensions measure_text(Clay_StringSlice text, Clay_TextElementConfig* cfg, void* ud) {
    (void)ud;
    float fs = (cfg && cfg->fontSize > 0) ? (float)cfg->fontSize : 14.0f;
    return (Clay_Dimensions){ (float)text.length * 7.5f * (fs / 14.0f), 16.0f * (fs / 14.0f) };
}
void clay_set_text_measurement(void) { Clay_SetMeasureTextFunction(measure_text, NULL); }

typedef struct { float x, y, w, h; } FB;
typedef struct { float r, g, b, a; } FC;
typedef struct { int len; const char* ptr; } FT;
typedef struct { int t; FB bb; FC bg; float rad; FC tc; int fs; FT tx; FC bc; } FCmd;
#define MC 1024
static FCmd fc[MC]; static int fn = 0;

static void flatten(Clay_RenderCommandArray* c) {
    fn = 0;
    for (int i = 0; i < c->length && fn < MC; i++) {
        Clay_RenderCommand* r = &c->internalArray[i];
        FCmd* f = &fc[fn++];
        f->t = r->commandType;
        f->bb = (FB){ r->boundingBox.x, r->boundingBox.y, r->boundingBox.width, r->boundingBox.height };
        f->bg = (FC){0}; f->rad = 0; f->tc = (FC){0}; f->fs = 0; f->tx = (FT){0,0}; f->bc = (FC){0};
        switch (r->commandType) {
            case CLAY_RENDER_COMMAND_TYPE_RECTANGLE:
                f->bg = (FC){ r->renderData.rectangle.backgroundColor.r, r->renderData.rectangle.backgroundColor.g,
                               r->renderData.rectangle.backgroundColor.b, r->renderData.rectangle.backgroundColor.a };
                f->rad = r->renderData.rectangle.cornerRadius.topLeft;
                break;
            case CLAY_RENDER_COMMAND_TYPE_BORDER:
                f->bc = (FC){ r->renderData.border.color.r, r->renderData.border.color.g,
                               r->renderData.border.color.b, r->renderData.border.color.a };
                f->rad = r->renderData.border.cornerRadius.topLeft;
                break;
            case CLAY_RENDER_COMMAND_TYPE_TEXT:
                f->tc = (FC){ r->renderData.text.textColor.r, r->renderData.text.textColor.g,
                               r->renderData.text.textColor.b, r->renderData.text.textColor.a };
                f->fs = r->renderData.text.fontSize;
                f->tx = (FT){ r->renderData.text.stringContents.length, r->renderData.text.stringContents.chars };
                break;
            default: break;
        }
    }
}

static Clay_LayoutConfig center_center(void) {
    return (Clay_LayoutConfig){ .sizing = { CLAY_SIZING_GROW(0, 0), CLAY_SIZING_GROW(0, 0) },
        .childAlignment = { CLAY_ALIGN_X_CENTER, CLAY_ALIGN_Y_CENTER } };
}
static Clay_LayoutConfig left_center_padded(void) {
    return (Clay_LayoutConfig){ .sizing = { CLAY_SIZING_GROW(0, 0), CLAY_SIZING_GROW(0, 0) },
        .childAlignment = { CLAY_ALIGN_X_LEFT, CLAY_ALIGN_Y_CENTER }, .layoutDirection = CLAY_LEFT_TO_RIGHT };
}
static Clay_LayoutConfig right_center_padded(void) {
    return (Clay_LayoutConfig){ .sizing = { CLAY_SIZING_GROW(0, 0), CLAY_SIZING_GROW(0, 0) },
        .childGap = 10, .childAlignment = { CLAY_ALIGN_X_RIGHT, CLAY_ALIGN_Y_CENTER }, .layoutDirection = CLAY_LEFT_TO_RIGHT };
}

int clay_layout_status_bar(int width, int height) {
    Clay_BeginLayout();
    Clay_LayoutConfig root = (Clay_LayoutConfig){
        .sizing = { CLAY_SIZING_FIXED(width), CLAY_SIZING_FIXED(height) },
        .childAlignment = { CLAY_ALIGN_X_LEFT, CLAY_ALIGN_Y_CENTER },
    };
    CLAY(CLAY_ID("Root"), .wrapped = { .layout = root, .backgroundColor = { 24, 24, 30, 255 } }) {
        Clay_LayoutConfig left = left_center_padded();
        left.childGap = 12; left.padding = CLAY_PADDING_ALL(6);
        CLAY(CLAY_ID("Left"), .wrapped = { .layout = left }) {
            CLAY(CLAY_ID("Dot"), .wrapped = {
                .layout = { .sizing = { CLAY_SIZING_FIXED(8), CLAY_SIZING_FIXED(8) } },
                .backgroundColor = { 130, 170, 255, 255 }, .cornerRadius = CLAY_CORNER_RADIUS(4),
            }) {}
            CLAY_TEXT(CLAY_STRING("OCWS Cairo-Clay"), .wrapped = { .fontSize = 14, .textColor = { 200, 200, 210, 255 } });
        }
        CLAY(CLAY_ID("Center"), .wrapped = { .layout = center_center() }) {
            CLAY_TEXT(CLAY_STRING("12:00"), .wrapped = { .fontSize = 14, .textColor = { 220, 220, 230, 255 } });
        }
        Clay_LayoutConfig right = right_center_padded();
        right.padding = CLAY_PADDING_ALL(6);
        CLAY(CLAY_ID("Right"), .wrapped = { .layout = right }) {
            CLAY_TEXT(CLAY_STRING("VOL"), .wrapped = { .fontSize = 11, .textColor = { 160, 160, 170, 255 } });
            CLAY_TEXT(CLAY_STRING("BAT 85%"), .wrapped = { .fontSize = 11, .textColor = { 160, 160, 170, 255 } });
        }
    }
    Clay_RenderCommandArray cmds = Clay_EndLayout(0.0f);
    flatten(&cmds);
    return fn;
}

int clay_layout_center_card(int width, int height) {
    Clay_BeginLayout();
    Clay_LayoutConfig root = (Clay_LayoutConfig){
        .sizing = { CLAY_SIZING_FIXED(width), CLAY_SIZING_FIXED(height) },
        .childAlignment = { CLAY_ALIGN_X_CENTER, CLAY_ALIGN_Y_CENTER },
    };
    CLAY(CLAY_ID("Root"), .wrapped = { .layout = root, .backgroundColor = { 18, 18, 24, 255 } }) {
        Clay_LayoutConfig card = (Clay_LayoutConfig){
            .sizing = { CLAY_SIZING_FIXED(360), CLAY_SIZING_FIXED(200) },
            .layoutDirection = CLAY_TOP_TO_BOTTOM, .childGap = 12,
            .childAlignment = { CLAY_ALIGN_X_LEFT, CLAY_ALIGN_Y_TOP },
            .padding = CLAY_PADDING_ALL(20),
        };
        CLAY(CLAY_ID("Card"), .wrapped = {
            .layout = card,
            .backgroundColor = { 35, 35, 45, 255 }, .cornerRadius = CLAY_CORNER_RADIUS(12),
            .border = { .color = { 60, 60, 80, 255 } },
        }) {
            CLAY_TEXT(CLAY_STRING("Clay + Cairo"), .wrapped = { .fontSize = 20, .textColor = { 240, 240, 250, 255 } });
            CLAY_TEXT(CLAY_STRING("Declarative layout with Cairo software renderer."), .wrapped = { .fontSize = 13, .textColor = { 160, 160, 175, 255 } });
            Clay_LayoutConfig btnrow = (Clay_LayoutConfig){
                .sizing = { CLAY_SIZING_GROW(0, 0), CLAY_SIZING_FIT(0, 0) },
                .layoutDirection = CLAY_LEFT_TO_RIGHT, .childGap = 10,
            };
            CLAY(CLAY_ID("Btns"), .wrapped = { .layout = btnrow }) {
                Clay_LayoutConfig btn = (Clay_LayoutConfig){
                    .sizing = { CLAY_SIZING_FIXED(120), CLAY_SIZING_FIXED(36) },
                    .childAlignment = { CLAY_ALIGN_X_CENTER, CLAY_ALIGN_Y_CENTER },
                };
                CLAY(CLAY_ID("B1"), .wrapped = { .layout = btn, .backgroundColor = { 100, 140, 255, 255 }, .cornerRadius = CLAY_CORNER_RADIUS(8) }) {
                    CLAY_TEXT(CLAY_STRING("Build"), .wrapped = { .fontSize = 13, .textColor = { 255, 255, 255, 255 } });
                }
                CLAY(CLAY_ID("B2"), .wrapped = { .layout = btn, .backgroundColor = { 50, 50, 65, 255 },
                    .cornerRadius = CLAY_CORNER_RADIUS(8), .border = { .color = { 80, 80, 100, 255 } } }) {
                    CLAY_TEXT(CLAY_STRING("Cancel"), .wrapped = { .fontSize = 13, .textColor = { 180, 180, 195, 255 } });
                }
            }
        }
    }
    Clay_RenderCommandArray cmds = Clay_EndLayout(0.0f);
    flatten(&cmds);
    return fn;
}

int clay_layout_dock(int width, int height, int icon_count) {
    Clay_BeginLayout();
    Clay_LayoutConfig root = (Clay_LayoutConfig){
        .sizing = { CLAY_SIZING_FIXED(width), CLAY_SIZING_FIXED(height) },
        .childAlignment = { CLAY_ALIGN_X_CENTER, CLAY_ALIGN_Y_CENTER },
    };
    CLAY(CLAY_ID("Root"), .wrapped = { .layout = root, .backgroundColor = { 20, 20, 28, 200 } }) {
        Clay_LayoutConfig dock = (Clay_LayoutConfig){
            .sizing = { CLAY_SIZING_GROW(0, 0), CLAY_SIZING_FIXED(height - 8) },
            .childGap = 8, .childAlignment = { CLAY_ALIGN_X_CENTER, CLAY_ALIGN_Y_CENTER },
            .layoutDirection = CLAY_LEFT_TO_RIGHT, .padding = CLAY_PADDING_ALL(4),
        };
        CLAY(CLAY_ID("Dock"), .wrapped = { .layout = dock,
            .backgroundColor = { 40, 40, 55, 180 }, .cornerRadius = CLAY_CORNER_RADIUS(14) }) {
            int n = icon_count < 5 ? icon_count : 5;
            for (int i = 0; i < n; i++) {
                char buf[32]; int len = snprintf(buf, sizeof(buf), "I%d", i);
                Clay_String id_str = { .length = len, .chars = buf, .isStaticallyAllocated = 0 };
                Clay_ElementId eid = Clay__HashString(id_str, 0);
                Clay_LayoutConfig ic = (Clay_LayoutConfig){
                    .sizing = { CLAY_SIZING_FIXED(36), CLAY_SIZING_FIXED(36) },
                    .childAlignment = { CLAY_ALIGN_X_CENTER, CLAY_ALIGN_Y_CENTER },
                };
                Clay__OpenElementWithId(eid);
                Clay__ConfigureOpenElement((Clay_ElementDeclaration){
                    .layout = ic,
                    .backgroundColor = { (float)(70+i*40), (float)(90+i*30), 180, 255 },
                    .cornerRadius = CLAY_CORNER_RADIUS(8),
                });
                Clay__CloseElement();
            }
        }
    }
    Clay_RenderCommandArray cmds = Clay_EndLayout(0.0f);
    flatten(&cmds);
    return fn;
}

int clay_cmd_count(void) { return fn; }
float clay_cmd_x(int i) { return fc[i].bb.x; }
float clay_cmd_y(int i) { return fc[i].bb.y; }
float clay_cmd_w(int i) { return fc[i].bb.w; }
float clay_cmd_h(int i) { return fc[i].bb.h; }
int   clay_cmd_type(int i) { return fc[i].t; }
float clay_cmd_bg_r(int i) { return fc[i].bg.r; }
float clay_cmd_bg_g(int i) { return fc[i].bg.g; }
float clay_cmd_bg_b(int i) { return fc[i].bg.b; }
float clay_cmd_bg_a(int i) { return fc[i].bg.a; }
float clay_cmd_radius(int i) { return fc[i].rad; }
float clay_cmd_text_r(int i) { return fc[i].tc.r; }
float clay_cmd_text_g(int i) { return fc[i].tc.g; }
float clay_cmd_text_b(int i) { return fc[i].tc.b; }
float clay_cmd_text_a(int i) { return fc[i].tc.a; }
int   clay_cmd_font_size(int i) { return fc[i].fs; }
int   clay_cmd_text_len(int i) { return fc[i].tx.len; }
const char* clay_cmd_text_ptr(int i) { return fc[i].tx.ptr; }
float clay_cmd_border_r(int i) { return fc[i].bc.r; }
float clay_cmd_border_g(int i) { return fc[i].bc.g; }
float clay_cmd_border_b(int i) { return fc[i].bc.b; }
float clay_cmd_border_a(int i) { return fc[i].bc.a; }
float clay_cmd_border_l(int i) { return 0; }

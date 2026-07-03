/* systems/focus.c - Cross-component focus management */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "widget.h"

/* ============================================================================
 * Focus Management
 * ============================================================================ */

#define MAX_FOCUSED_WIDGETS 32

typedef struct {
    const char *component_name;
    int widget_id;
    bool focused;
    int x, y, width, height;
    widget_context_t *ctx;
    void (*on_focus)(struct focus_manager_t *fm, const char *name);
    void (*on_unfocus)(struct focus_manager_t *fm, const char *name);
} focused_widget_t;

typedef struct focus_manager_t {
    focused_widget_t widgets[MAX_FOCUSED_WIDGETS];
    int widget_count;
    int next_id;
} focus_manager_t;

static focus_manager_t focus_manager;

/* ============================================================================
 * Focus API
 * ============================================================================ */

/* Register a widget for focus management */
int register_widget_for_focus(const char *component_name, widget_context_t *ctx, 
                               void (*on_focus)(focus_manager_t *fm, const char *name),
                               void (*on_unfocus)(focus_manager_t *fm, const char *name)) {
    if (focus_manager.widget_count >= MAX_FOCUSED_WIDGETS) return -1;
    if (!component_name || !ctx) return -1;
    
    int id = focus_manager.next_id++;
    
    focused_widget_t *widget = &focus_manager.widgets[focus_manager.widget_count++];
    widget->component_name = component_name;
    widget->widget_id = id;
    widget->focused = false;
    widget->ctx = ctx;
    widget->on_focus = on_focus;
    widget->on_unfocus = on_unfocus;
    
    return id;
}

/* Set focus to a specific widget */
int focus_widget(const char *component_name) {
    for (int i = 0; i < focus_manager.widget_count; i++) {
        if (strcmp(focus_manager.widgets[i].component_name, component_name) == 0) {
            if (focus_manager.widgets[i].focused) return i;
            
            /* Unfocus previously focused widget */
            for (int j = 0; j < focus_manager.widget_count; j++) {
                if (focus_manager.widgets[j].focused) {
                    focus_manager.widgets[j].focused = false;
                    if (focus_manager.widgets[j].on_unfocus) {
                        focus_manager.widgets[j].on_unfocus(&focus_manager, 
                            focus_manager.widgets[j].component_name);
                    }
                }
            }
            
            /* Focus new widget */
            focus_manager.widgets[i].focused = true;
            if (focus_manager.widgets[i].on_focus) {
                focus_manager.widgets[i].on_focus(&focus_manager, component_name);
            }
            return i;
        }
    }
    return -1;
}

/* Get ID of focused widget */
int get_focused_widget_id(const char *component_name) {
    for (int i = 0; i < focus_manager.widget_count; i++) {
        if (strcmp(focus_manager.widgets[i].component_name, component_name) == 0) {
            return focus_manager.widgets[i].focused ? focus_manager.widgets[i].widget_id : -1;
        }
    }
    return -1;
}

/* Check if widget is focused */
bool is_widget_focused(const char *component_name) {
    int id = get_focused_widget_id(component_name);
    return id != -1;
}

/* Update widget focus based on mouse position */
void update_widget_focus_from_mouse(focus_manager_t *fm, int mouse_x, int mouse_y) {
    for (int i = 0; i < fm->widget_count; i++) {
        focused_widget_t *widget = &fm->widgets[i];
        bool was_focused = widget->focused;
        bool should_be_focused = (mouse_x >= widget->x && mouse_x <= widget->x + widget->width &&
                                  mouse_y >= widget->y && mouse_y <= widget->y + widget->height);
        
        if (should_be_focused != was_focused) {
            widget->focused = should_be_focused;
            if (should_be_focused && widget->on_focus) {
                widget->on_focus(fm, widget->component_name);
            } else if (!should_be_focused && widget->on_unfocus) {
                widget->on_unfocus(fm, widget->component_name);
            }
        }
    }
}

/* Reset focus */
void reset_focus(focus_manager_t *fm) {
    for (int i = 0; i < fm->widget_count; i++) {
        if (fm->widgets[i].focused) {
            fm->widgets[i].focused = false;
            if (fm->widgets[i].on_unfocus) {
                fm->widgets[i].on_unfocus(fm, fm->widgets[i].component_name);
            }
        }
    }
}

/* Get focused widget info */
focused_widget_t* get_focused_widget_info(focus_manager_t *fm) {
    for (int i = 0; i < fm->widget_count; i++) {
        if (fm->widgets[i].focused) {
            return &fm->widgets[i];
        }
    }
    return NULL;
}

/* ============================================================================
 * Focus Callbacks
 * ============================================================================ */

/* Example focus callback for statusbar widgets */
void setup_statusbar_widget_focus(focus_manager_t *fm, const char *component_name,
                                  widget_context_t *ctx, int x, int y, int width, int height) {
    int id = register_widget_for_focus(component_name, ctx,
        (void(*)(focus_manager_t*, const char*))(void*)focus_widget,
        (void(*)(focus_manager_t*, const char*))(void*)reset_focus);
    
    if (id != -1) {
        focused_widget_t *widget = get_focused_widget_info(fm);
        if (widget) {
            widget->x = x;
            widget->y = y;
            widget->width = width;
            widget->height = height;
        }
    }
}

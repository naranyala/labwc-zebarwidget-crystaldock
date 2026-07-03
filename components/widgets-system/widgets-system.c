/* widgets-system core */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "widget.h"

/* ============================================================================
 * Widget System Architecture
 * ============================================================================ */

typedef enum {
    WIDGET_TYPE_STANDARD,
    WIDGET_TYPE_SYSTEM,
    WIDGET_TYPE_CUSTOM
} widget_type_t;

typedef enum {
    WIDGET_STATE_IDLE,
    WIDGET_STATE_INIT,
    WIDGET_STATE_RUNNING,
    WIDGET_STATE_UPDATING,
    WIDGET_STATE_RENDERING,
    WIDGET_STATE_DESTROYING
} widget_state_t;

typedef enum {
    WIDGET_FOCUS_DIRECTION_NONE,
    WIDGET_FOCUS_DIRECTION_FORWARD,
    WIDGET_FOCUS_DIRECTION_BACKWARD,
    WIDGET_FOCUS_DIRECTION_PREVIOUS,
    WIDGET_FOCUS_DIRECTION_NEXT
} widget_focus_direction_t;

/* Widget metadata for registration and management */
typedef struct {
    const char *name;
    const char *description;
    widget_type_t type;
    int width;
    int height;
    int priority;
    bool enabled;
    void *instance;
    widget_state_t state;
    int z_index;
    bool focused;
    int order_index;
} widget_meta_t;

/* Widget navigation system */
typedef struct {
    widget_meta_t *widgets;
    int widget_count;
    int max_widgets;
    int current_focus_index;
    int previous_focus_index;
    bool tab_nav_enabled;
    bool mouse_focus_enabled;
    bool focus_sticky;
} widget_navigation_t;

/* Global widget system state */
typedef struct {
    widget_meta_t *widgets;
    int widget_count;
    int max_widgets;
    widget_navigation_t *navigation;
    bool initialized;
    char *config_path;
} widget_system_t;

static widget_system_t widget_system;

/* ============================================================================
 * Widget Registration API
 * ============================================================================ */

/* Register a widget with the system */
int widget_system_register_widget(widget_meta_t *meta) {
    if (!meta || !meta->name) return -1;
    if (widget_system.widget_count >= widget_system.max_widgets) {
        widget_system.max_widgets *= 2;
        widget_system.widgets = realloc(widget_system.widgets, 
                                        widget_system.max_widgets * sizeof(widget_meta_t));
        if (!widget_system.widgets) return -1;
    }
    
    // Check if widget already registered
    for (int i = 0; i < widget_system.widget_count; i++) {
        if (strcmp(widget_system.widgets[i].name, meta->name) == 0) {
            return -2;  // Widget already registered
        }
    }
    
    widget_system.widgets[widget_system.widget_count++] = *meta;
    
    // Initialize navigation if needed
    if (!widget_system.navigation) {
        widget_system.navigation = calloc(1, sizeof(widget_navigation_t));
        if (!widget_system.navigation) return -1;
        widget_system.navigation->widgets = calloc(widget_system.max_widgets, sizeof(widget_meta_t));
        widget_system.navigation->current_focus_index = -1;
        widget_system.navigation->tab_nav_enabled = true;
        widget_system.navigation->mouse_focus_enabled = true;
        widget_system.navigation->focus_sticky = false;
    }
    
    return widget_system.widget_count - 1;
}

/* Register a system widget (standard library widget) */
int widget_system_register_system_widget(const char *name, const char *description, 
                                         widget_type_t type, int width, int height, 
                                         int priority, bool enabled) {
    widget_meta_t meta = {0};
    meta.name = name;
    meta.description = description;
    meta.type = type;
    meta.width = width;
    meta.height = height;
    meta.priority = priority;
    meta.enabled = enabled;
    meta.state = WIDGET_STATE_IDLE;
    meta.z_index = priority;
    meta.focused = false;
    meta.order_index = -1;
    
    return widget_system_register_widget(&meta);
}

/* Check if widget is registered */
bool widget_system_is_registered(const char *name) {
    if (!name) return false;
    
    for (int i = 0; i < widget_system.widget_count; i++) {
        if (strcmp(widget_system.widgets[i].name, name) == 0) {
            return true;
        }
    }
    return false;
}

/* Get widget metadata by name */
widget_meta_t* widget_system_get_widget(const char *name) {
    if (!name) return NULL;
    
    for (int i = 0; i < widget_system.widget_count; i++) {
        if (strcmp(widget_system.widgets[i].name, name) == 0) {
            return &widget_system.widgets[i];
        }
    }
    return NULL;
}

/* Get widget by index */
widget_meta_t* widget_system_get_widget_by_index(int index) {
    if (index < 0 || index >= widget_system.widget_count) return NULL;
    return &widget_system.widgets[index];
}

/* ============================================================================
 * Widget Navigation API (Tab System)
 * ============================================================================ */

/* Navigate focus forward through widgets */
bool widget_system_navigate_focus_forward() {
    if (!widget_system.navigation || widget_system.navigation->current_focus_index == -1) {
        return false;
    }
    
    int next_index = widget_system.navigation->current_focus_index + 1;
    if (next_index >= widget_system.widget_count) {
        if (widget_system.navigation->focus_sticky) {
            next_index = widget_system.navigation->current_focus_index;
        } else {
            return false;
        }
    }
    
    widget_system.navigation->previous_focus_index = 
        widget_system.navigation->current_focus_index;
    widget_system.navigation->current_focus_index = next_index;
    
    // Update focus state
    widget_meta_t *current = widget_system_get_widget_by_index(next_index);
    if (current) {
        current->focused = true;
        widget_system.navigation->widgets[next_index] = *current;
    }
    
    return true;
}

/* Navigate focus backward through widgets */
bool widget_system_navigate_focus_backward() {
    if (!widget_system.navigation || widget_system.navigation->current_focus_index == -1) {
        return false;
    }
    
    int prev_index = widget_system.navigation->current_focus_index - 1;
    if (prev_index < 0) {
        if (widget_system.navigation->focus_sticky) {
            prev_index = widget_system.navigation->current_focus_index;
        } else {
            return false;
        }
    }
    
    widget_system.navigation->previous_focus_index = 
        widget_system.navigation->current_focus_index;
    widget_system.navigation->current_focus_index = prev_index;
    
    // Update focus state
    if (prev_index >= 0) {
        widget_meta_t *current = widget_system_get_widget_by_index(prev_index);
        if (current) {
            current->focused = true;
            widget_system.navigation->widgets[prev_index] = *current;
        }
    }
    
    return true;
}

/* Set focus to specific widget */
bool widget_system_set_focus(const char *name) {
    if (!name) return false;
    
    int target_index = -1;
    for (int i = 0; i < widget_system.widget_count; i++) {
        if (strcmp(widget_system.widgets[i].name, name) == 0) {
            target_index = i;
            break;
        }
    }
    
    if (target_index == -1) return false;
    
    widget_system.navigation->previous_focus_index = 
        widget_system.navigation->current_focus_index;
    widget_system.navigation->current_focus_index = target_index;
    
    // Update focus state
    widget_meta_t *current = widget_system_get_widget_by_index(target_index);
    if (current) {
        current->focused = true;
        widget_system.navigation->widgets[target_index] = *current;
        
        // Unfocus other widgets
        for (int i = 0; i < widget_system.widget_count; i++) {
            if (i != target_index) {
                widget_meta_t *other = widget_system_get_widget_by_index(i);
                if (other) {
                    other->focused = false;
                    widget_system.navigation->widgets[i] = *other;
                }
            }
        }
    }
    
    return true;
}

/* Get currently focused widget */
widget_meta_t* widget_system_get_focused_widget() {
    if (!widget_system.navigation || widget_system.navigation->current_focus_index == -1) {
        return NULL;
    }
    
    return widget_system_get_widget_by_index(widget_system.navigation->current_focus_index);
}

/* Find next enabled widget in a direction */
int widget_system_find_next_widget(int start_index, widget_focus_direction_t direction) {
    int next_index = -1;
    
    for (int i = 0; i < widget_system.widget_count; i++) {
        int check_index = (direction == WIDGET_FOCUS_DIRECTION_FORWARD)
            ? ((start_index + i + 1) % widget_system.widget_count)
            : ((start_index - i + widget_system.widget_count) % widget_system.widget_count);
        
        if (check_index == start_index && i > 0) continue;
        
        widget_meta_t *widget = widget_system_get_widget_by_index(check_index);
        if (widget && widget->enabled) {
            next_index = check_index;
            break;
        }
    }
    
    return next_index;
}

/* ============================================================================
 * Widget System Initialization and Management
 * ============================================================================ */

/* Initialize widget system */
bool widget_system_init(int max_widgets, const char *config_path) {
    if (widget_system.initialized) return false;
    
    widget_system.max_widgets = max_widgets;
    widget_system.widgets = calloc(max_widgets, sizeof(widget_meta_t));
    widget_system.widget_count = 0;
    widget_system.config_path = (config_path ? strdup(config_path) : NULL);
    
    // Initialize navigation
    widget_system.navigation = calloc(1, sizeof(widget_navigation_t));
    if (!widget_system.navigation) {
        free(widget_system.widgets);
        return false;
    }
    
    widget_system.navigation->widgets = calloc(max_widgets, sizeof(widget_meta_t));
    widget_system.navigation->current_focus_index = -1;
    widget_system.navigation->previous_focus_index = -1;
    widget_system.navigation->tab_nav_enabled = true;
    widget_system.navigation->mouse_focus_enabled = true;
    widget_system.navigation->focus_sticky = false;
    
    widget_system.initialized = true;
    
    return true;
}

/* Cleanup widget system */
void widget_system_cleanup() {
    if (!widget_system.initialized) return;
    
    free(widget_system.widgets);
    free(widget_system.navigation->widgets);
    free(widget_system.navigation);
    free(widget_system.config_path);
    
    memset(&widget_system, 0, sizeof(widget_system_t));
    widget_system.initialized = false;
}

/* Load widget system configuration */
bool widget_system_load_config() {
    if (!widget_system.config_path) return false;
    
    // TODO: Implement configuration loading
    return true;
}

/* Save widget system configuration */
bool widget_system_save_config() {
    if (!widget_system.config_path) return false;
    
    // TODO: Implement configuration saving
    return true;
}

/* Get widget system status */
void widget_system_get_status() {
    printf("Widget System Status:\n");
    printf("  Initialized: %s\n", widget_system.initialized ? "yes" : "no");
    printf("  Registered Widgets: %d/%d\n", widget_system.widget_count, widget_system.max_widgets);
    printf("  Tab Navigation: %s\n", widget_system.navigation && widget_system.navigation->tab_nav_enabled ? "enabled" : "disabled");
    printf("  Mouse Focus: %s\n", widget_system.navigation && widget_system.navigation->mouse_focus_enabled ? "enabled" : "disabled");
    printf("  Current Focus Index: %d\n", widget_system.navigation ? widget_system.navigation->current_focus_index : -1);
    
    if (widget_system.navigation && widget_system.navigation->tab_nav_enabled) {
        printf("  Navigation: Tab (forward), Shift+Tab (backward), Mouse (if enabled)\n");
    }
}

/* ============================================================================
 * Exported Widget System Functions
 * ============================================================================ */

/* Initialize the complete widget system */
bool init_widget_system(int max_widgets, const char *config_path) {
    return widget_system_init(max_widgets, config_path);
}

/* Register standard system widgets */
void register_system_widgets() {
    // Core system widgets
    widget_system_register_system_widget(
        "workspaces", 
        "Workspace switcher widget", 
        WIDGET_TYPE_SYSTEM, 
        280, 
        32, 
        100,  
        true
    );
    
    widget_system_register_system_widget(
        "clock", 
        "Clock widget for time display", 
        WIDGET_TYPE_SYSTEM, 
        120, 
        32, 
        99,   
        true
    );
    
    widget_system_register_system_widget(
        "cpu", 
        "CPU usage monitor", 
        WIDGET_TYPE_SYSTEM, 
        80, 
        32, 
        98,   
        true
    );
    
    widget_system_register_system_widget(
        "memory", 
        "Memory usage monitor", 
        WIDGET_TYPE_SYSTEM, 
        80, 
        32, 
        97,   
        true
    );
    
    widget_system_register_system_widget(
        "network", 
        "Network connectivity status", 
        WIDGET_TYPE_SYSTEM, 
        120, 
        32, 
        96,   
        true
    );
    
    widget_system_register_system_widget(
        "battery", 
        "Battery level and charging status", 
        WIDGET_TYPE_SYSTEM, 
        80, 
        32, 
        95,   
        true
    );
    
    widget_system_register_system_widget(
        "volume", 
        "Audio volume control", 
        WIDGET_TYPE_SYSTEM, 
        80, 
        32, 
        94,   
        true
    );
}

/* Get current focus state */
bool widget_system_has_focus() {
    return widget_system.navigation && 
           widget_system.navigation->current_focus_index != -1;
}

/* Set tab navigation enable/disable */
void widget_system_set_tab_navigation(bool enabled) {
    if (widget_system.navigation) {
        widget_system.navigation->tab_nav_enabled = enabled;
    }
}

/* Set mouse focus enable/disable */
void widget_system_set_mouse_focus(bool enabled) {
    if (widget_system.navigation) {
        widget_system.navigation->mouse_focus_enabled = enabled;
    }
}

/* Set focus sticky behavior */
void widget_system_set_focus_sticky(bool sticky) {
    if (widget_system.navigation) {
        widget_system.navigation->focus_sticky = sticky;
    }
}

/* ============================================================================
 * Widget System Implementation
 * ============================================================================ */

void* widget_system_create_instance(const char *name) {
    widget_meta_t *widget = widget_system_get_widget(name);
    if (!widget) return NULL;
    
    // Create widget instance based on type
    switch (widget->type) {
        case WIDGET_TYPE_STANDARD:
            return widget_system_create_standard_widget(widget);
        case WIDGET_TYPE_SYSTEM:
            return widget_system_create_system_widget(widget);
        case WIDGET_TYPE_CUSTOM:
            return widget_system_create_custom_widget(widget);
        default:
            return NULL;
    }
}

void* widget_system_create_standard_widget(widget_meta_t *meta) {
    // Create standard widget instance
    return NULL;
}

void* widget_system_create_system_widget(widget_meta_t *meta) {
    // Create system widget instance
    return NULL;
}

void* widget_system_create_custom_widget(widget_meta_t *meta) {
    // Create custom widget instance
    return NULL;
}

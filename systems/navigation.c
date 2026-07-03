/* systems/navigation.c - Window and workspace navigation */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "widget.h"

/* ============================================================================
 * Navigation System
 * ============================================================================ */

#define MAX_WORKSPACE_HISTORY 32

typedef struct {
    int id;
    char *title;
    char *app_id;
    bool floating;
    bool maximized;
    bool fullscreen;
    int workspace;
    bool focused;
} window_t;

typedef struct {
    int id;
    char *name;
    bool active;
    int layout_mode;  /* 0: default, 1: tiling, 2: floating */
} workspace_t;

typedef struct {
    window_t *windows[MAX_WORKSPACE_HISTORY];
    int window_count;
    int max_windows;
} window_history_t;

typedef struct {
    workspace_t *workspaces;
    int workspace_count;
    int current_workspace;
    window_history_t history[MAX_WORKSPACE_HISTORY];
} navigation_system_t;

static navigation_system_t nav_system;

/* ============================================================================
 * Navigation API
 * ============================================================================ */

/* Initialize navigation system */
void init_navigation_system(int workspace_count, int max_windows) {
    nav_system.workspaces = calloc(workspace_count, sizeof(workspace_t));
    nav_system.workspace_count = workspace_count;
    nav_system.current_workspace = 1;
    nav_system.history = calloc(max_windows, sizeof(window_history_t));
    
    for (int i = 0; i < workspace_count; i++) {
        nav_system.workspaces[i].id = i + 1;
        nav_system.workspaces[i].name = calloc(16, sizeof(char));
        snprintf(nav_system.workspaces[i].name, 16, "Workspace %d", i + 1);
        nav_system.workspaces[i].active = (i == 0);
        nav_system.workspaces[i].layout_mode = 0;
    }
}

/* Add a window to history */
void add_window_to_history(window_t *window) {
    if (nav_system.history[nav_system.current_workspace].window_count >= MAX_WORKSPACE_HISTORY) {
        for (int i = 0; i < nav_system.history[nav_system.current_workspace].window_count - 1; i++) {
            nav_system.history[nav_system.current_workspace].windows[i] = 
                nav_system.history[nav_system.current_workspace].windows[i + 1];
        }
        nav_system.history[nav_system.current_workspace].window_count--;
    }
    
    nav_system.history[nav_system.current_workspace].windows
        [nav_system.history[nav_system.current_workspace].window_count++] = window;
}

/* Switch to workspace */
void switch_workspace(int workspace_id) {
    if (workspace_id < 1 || workspace_id > nav_system.workspace_count) return;
    
    /* Update active state */
    for (int i = 0; i < nav_system.workspace_count; i++) {
        nav_system.workspaces[i].active = false;
    }
    
    nav_system.workspaces[workspace_id - 1].active = true;
    nav_system.current_workspace = workspace_id;
    
    /* Emit signal/callback for workspace change */
}

/* Move window to workspace */
void move_window_to_workspace(window_t *window, int workspace_id) {
    if (!window || workspace_id < 1 || workspace_id > nav_system.workspace_count) return;
    
    window->workspace = workspace_id;
}

/* Focus window */
void focus_window(window_t *window) {
    if (!window) return;
    
    /* Unfocus all other windows */
    for (int i = 0; i < nav_system.workspace_count; i++) {
        for (int j = 0; j < MAX_WORKSPACE_HISTORY; j++) {
            if (nav_system.history[i].windows[j] == window) {
                if (!window->focused) {
                    window->focused = true;
                }
                continue;
            }
            if (nav_system.history[i].windows[j]) {
                nav_system.history[i].windows[j]->focused = false;
            }
        }
    }
}

/* Maximize window */
void maximize_window(window_t *window) {
    if (!window) return;
    
    window->maximized = !window->maximized;
    window->fullscreen = false;
    
    /* Emit signal for window state change */
}

/* Fullscreen window */
void fullscreen_window(window_t *window) {
    if (!window) return;
    
    window->fullscreen = !window->fullscreen;
    window->maximized = false;
    
    /* Emit signal for window state change */
}

/* Float window */
void float_window(window_t *window) {
    if (!window) return;
    
    window->floating = true;
    window->maximized = false;
    window->fullscreen = false;
    
    /* Emit signal for window state change */
}

/* Get current workspace */
int get_current_workspace() {
    return nav_system.current_workspace;
}

/* Get workspace by ID */
workspace_t* get_workspace_by_id(int workspace_id) {
    if (workspace_id < 1 || workspace_id > nav_system.workspace_count) return NULL;
    return &nav_system.workspaces[workspace_id - 1];
}

/* Get all windows in workspace */
void get_workspace_windows(int workspace_id, window_t **windows, int *count) {
    if (workspace_id < 1 || workspace_id > nav_system.workspace_count) return;
    
    *count = nav_system.history[workspace_id - 1].window_count;
    for (int i = 0; i < *count && i < MAX_WORKSPACE_HISTORY; i++) {
        if (nav_system.history[workspace_id - 1].windows[i]) {
            windows[i] = nav_system.history[workspace_id - 1].windows[i];
        }
    }
}

/* Get focused window */
window_t* get_focused_window() {
    for (int i = 0; i < nav_system.workspace_count; i++) {
        for (int j = 0; j < MAX_WORKSPACE_HISTORY; j++) {
            if (nav_system.history[i].windows[j] && nav_system.history[i].windows[j]->focused) {
                return nav_system.history[i].windows[j];
            }
        }
    }
    return NULL;
}

/* Set workspace layout mode */
void set_workspace_layout(int workspace_id, int layout_mode) {
    if (workspace_id < 1 || workspace_id > nav_system.workspace_count) return;
    nav_system.workspaces[workspace_id - 1].layout_mode = layout_mode;
}

/* Get workspace layout mode */
int get_workspace_layout(int workspace_id) {
    if (workspace_id < 1 || workspace_id > nav_system.workspace_count) return 0;
    return nav_system.workspaces[workspace_id - 1].layout_mode;
}

/* Cleanup navigation system */
void cleanup_navigation_system() {
    for (int i = 0; i < nav_system.workspace_count; i++) {
        free(nav_system.workspaces[i].name);
        
        for (int j = 0; j < MAX_WORKSPACE_HISTORY; j++) {
            if (nav_system.history[i].windows[j]) {
                free(nav_system.history[i].windows[j]->title);
                free(nav_system.history[i].windows[j]->app_id);
                free(nav_system.history[i].windows[j]);
            }
        }
    }
    
    free(nav_system.workspaces);
    free(nav_system.history);
}

/* ============================================================================
 * Navigation Helpers
 * ============================================================================ */

/* Create a new window */
window_t* create_window(const char *title, const char *app_id) {
    window_t *window = calloc(1, sizeof(window_t));
    if (!window) return NULL;
    
    window->id = nav_system.workspace_count * 100 + rand() % 100;
    window->title = strdup(title ? title : "Untitled");
    window->app_id = strdup(app_id ? app_id : "unknown");
    window->floating = false;
    window->maximized = false;
    window->fullscreen = false;
    window->workspace = nav_system.current_workspace;
    window->focused = false;
    
    return window;
}

/* Delete a window */
void delete_window(window_t *window) {
    if (!window) return;
    
    free(window->title);
    free(window->app_id);
    free(window);
}

/* Get workspace count */
int get_workspace_count() {
    return nav_system.workspace_count;
}

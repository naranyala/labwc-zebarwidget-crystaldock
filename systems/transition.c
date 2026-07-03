/* systems/transition.c - System transition and lifecycle management */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "widget.h"

/* ============================================================================
 * System Transitions
 * ============================================================================ */

#define MAX_SYSTEMS 32

typedef enum {
    SYSTEM_BAR,
    SYSTEM_WIDGET,
    SYSTEM_DOCK,
    SYSTEM_FOCUS,
    SYSTEM_CONFIG,
    SYSTEM_THEME,
    SYSTEM_NAVIGATION,
    SYSTEM_PREFERENCE
} system_type_t;

typedef struct {
    system_type_t type;
    const char *name;
    const char *version;
    bool active;
    char *config_path;
    void (*init)(void);
    void (*cleanup)(void);
    int (*state)(void);
} system_t;

typedef struct {
    system_t *systems[MAX_SYSTEMS];
    int system_count;
    int next_id;
    char **active_systems;
    int active_count;
} system_registry_t;

static system_registry_t registry;

/* ============================================================================
 * System Life Cycle
 * ============================================================================ */

/* Register a system */
int register_system(system_t *system) {
    if (registry.system_count >= MAX_SYSTEMS) return -1;
    if (!system || !system->name) return -1;
    
    /* Check if already registered */
    for (int i = 0; i < registry.system_count; i++) {
        if (registry.systems[i] == system) return i;
    }
    
    system->active = false;
    registry.systems[registry.system_count++] = system;
    return registry.system_count - 1;
}

/* Initialize all systems in dependency order */
void init_all_systems() {
    /* Initialize in dependency order */
    for (int i = 0; i < registry.system_count; i++) {
        /* Try to initialize */
        if (registry.systems[i]->init) {
            registry.systems[i]->init();
        }
        registry.systems[i]->active = true;
    }
}

/* Cleanup all systems in reverse dependency order */
void cleanup_all_systems() {
    /* Cleanup in reverse order */
    for (int i = registry.system_count - 1; i >= 0; i--) {
        if (registry.systems[i]->active && registry.systems[i]->cleanup) {
            registry.systems[i]->cleanup();
        }
        registry.systems[i]->active = false;
    }
}

/* Check if system is active */
bool is_system_active(const char *name) {
    for (int i = 0; i < registry.system_count; i++) {
        if (registry.systems[i] && strcmp(registry.systems[i]->name, name) == 0) {
            return registry.systems[i]->active;
        }
    }
    return false;
}

/* Get active systems */
char** get_active_systems(int *count) {
    *count = registry.active_count;
    return registry.active_systems;
}

/* Get system state */
int get_system_state(const char *name) {
    for (int i = 0; i < registry.system_count; i++) {
        if (registry.systems[i] && strcmp(registry.systems[i]->name, name) == 0) {
            if (registry.systems[i]->state) {
                return registry.systems[i]->state();
            }
            return 0;
        }
    }
    return -1;
}

/* ============================================================================
 * System Transitions
 * ============================================================================ */

/* Transition to a new active system configuration */
void transition_to_config(const char *config_path) {
    /* Cleanup current systems */
    cleanup_all_systems();
    
    /* Update config path and reinitialize */
    for (int i = 0; i < registry.system_count; i++) {
        registry.systems[i]->config_path = strdup(config_path);
    }
    
    /* Reinitialize all systems */
    init_all_systems();
}

/* Hot reload a specific system */
void hot_reload_system(const char *name) {
    for (int i = 0; i < registry.system_count; i++) {
        if (registry.systems[i] && strcmp(registry.systems[i]->name, name) == 0) {
            if (registry.systems[i]->active) {
                registry.systems[i]->cleanup();
                registry.systems[i]->active = false;
                
                if (registry.systems[i]->init) {
                    registry.systems[i]->init();
                    registry.systems[i]->active = true;
                }
            }
            break;
        }
    }
}

/* Get all registered systems */
system_t** get_all_systems(int *count) {
    *count = registry.system_count;
    return registry.systems;
}

/* ============================================================================
 * System Callbacks
 * ============================================================================ */

/* Set system init callback */
void set_system_init_callback(const char *name, void (*init)(void)) {
    for (int i = 0; i < registry.system_count; i++) {
        if (registry.systems[i] && strcmp(registry.systems[i]->name, name) == 0) {
            registry.systems[i]->init = init;
            break;
        }
    }
}

/* Set system cleanup callback */
void set_system_cleanup_callback(const char *name, void (*cleanup)(void)) {
    for (int i = 0; i < registry.system_count; i++) {
        if (registry.systems[i] && strcmp(registry.systems[i]->name, name) == 0) {
            registry.systems[i]->cleanup = cleanup;
            break;
        }
    }
}

/* Set system state callback */
void set_system_state_callback(const char *name, int (*state)(void)) {
    for (int i = 0; i < registry.system_count; i++) {
        if (registry.systems[i] && strcmp(registry.systems[i]->name, name) == 0) {
            registry.systems[i]->state = state;
            break;
        }
    }
}

/* Initialize default systems */
void init_default_systems() {
    /* Create active systems list */
    registry.active_systems = calloc(MAX_SYSTEMS, sizeof(char*));
    registry.active_count = 0;
    
    /* Register core systems */
    register_system(setup_system(SYSTEM_CONFIG, "config", "1.0.0"));
    register_system(setup_system(SYSTEM_PREFERENCE, "preferences", "1.0.0"));
    register_system(setup_system(SYSTEM_FOCUS, "focus", "1.0.0"));
    register_system(setup_system(SYSTEM_THEME, "theme", "1.0.0"));
}

/* Setup system factory function */
system_t* setup_system(system_type_t type, const char *name, const char *version) {
    system_t *system = calloc(1, sizeof(system_t));
    if (!system) return NULL;
    
    system->type = type;
    system->name = strdup(name);
    system->version = strdup(version);
    system->active = false;
    system->config_path = NULL;
    system->init = NULL;
    system->cleanup = NULL;
    system->state = NULL;
    
    return system;
}

/* Get system by type */
system_t* get_system_by_type(system_type_t type) {
    for (int i = 0; i < registry.system_count; i++) {
        if (registry.systems[i]->type == type) {
            return registry.systems[i];
        }
    }
    return NULL;
}

/* Get system by name */
system_t* get_system_by_name(const char *name) {
    for (int i = 0; i < registry.system_count; i++) {
        if (registry.systems[i]->name && strcmp(registry.systems[i]->name, name) == 0) {
            return registry.systems[i];
        }
    }
    return NULL;
}

/* Free system */
void free_system(system_t *system) {
    if (!system) return;
    
    free((void*)system->name);
    free((void*)system->version);
    free(system->config_path);
    free(system);
}

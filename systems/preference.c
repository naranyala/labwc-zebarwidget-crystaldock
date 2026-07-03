/* systems/preference.c - User preference management */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "widget.h"

/* ============================================================================
 * Preferences
 * ============================================================================ */

typedef struct {
    const char *key;
    const char *value;
    bool persistent;
    void (*on_change)(struct preferences_t *prefs, const char *key, const char *value);
} preference_t;

typedef struct preferences_t {
    preference_t *preferences;
    int preference_count;
    int max_preferences;
} preferences_t;

static preferences_t global_preferences;

/* ============================================================================
 * Preference API
 * ============================================================================ */

/* Initialize preferences */
void init_preferences(int max_prefs) {
    global_preferences.max_preferences = max_prefs;
    global_preferences.preference_count = 0;
    global_preferences.preferences = calloc(max_prefs, sizeof(preference_t));
}

/* Set a preference value */
void set_preference(const char *key, const char *value, bool persistent) {
    if (!key || !value) return;
    
    /* Check if preference already exists */
    for (int i = 0; i < global_preferences.preference_count; i++) {
        if (strcmp(global_preferences.preferences[i].key, key) == 0) {
            /* Update existing preference */
            free(global_preferences.preferences[i].value);
            global_preferences.preferences[i].value = strdup(value);
            global_preferences.preferences[i].persistent = persistent;
            
            if (global_preferences.preferences[i].on_change) {
                global_preferences.preferences[i].on_change(&global_preferences, key, value);
            }
            return;
        }
    }
    
    /* Add new preference */
    if (global_preferences.preference_count < global_preferences.max_preferences) {
        preference_t *pref = &global_preferences.preferences[global_preferences.preference_count++];
        pref->key = strdup(key);
        pref->value = strdup(value);
        pref->persistent = persistent;
        pref->on_change = NULL;
    }
}

/* Get a preference value */
const char* get_preference(const char *key) {
    if (!key) return NULL;
    
    for (int i = 0; i < global_preferences.preference_count; i++) {
        if (strcmp(global_preferences.preferences[i].key, key) == 0) {
            return global_preferences.preferences[i].value;
        }
    }
    return NULL;
}

/* Get preference as integer */
int get_preference_int(const char *key, int default_value) {
    const char *value = get_preference(key);
    if (!value) return default_value;
    return atoi(value);
}

/* Get preference as boolean */
bool get_preference_bool(const char *key, bool default_value) {
    const char *value = get_preference(key);
    if (!value) return default_value;
    
    if (strcmp(value, "true") == 0 || strcmp(value, "1") == 0) return true;
    if (strcmp(value, "false") == 0 || strcmp(value, "0") == 0) return false;
    
    return default_value;
}

/* Remove a preference */
void remove_preference(const char *key) {
    if (!key) return;
    
    for (int i = 0; i < global_preferences.preference_count; i++) {
        if (strcmp(global_preferences.preferences[i].key, key) == 0) {
            free(global_preferences.preferences[i].key);
            free(global_preferences.preferences[i].value);
            
            /* Shift remaining preferences */
            for (int j = i; j < global_preferences.preference_count - 1; j++) {
                global_preferences.preferences[j] = global_preferences.preferences[j + 1];
            }
            
            global_preferences.preference_count--;
            break;
        }
    }
}

/* Check if preference exists */
bool has_preference(const char *key) {
    return get_preference(key) != NULL;
}

/* List all preferences */
void list_preferences() {
    printf("Current preferences:\n");
    for (int i = 0; i < global_preferences.preference_count; i++) {
        printf("  %s = %s%s\n", 
               global_preferences.preferences[i].key,
               global_preferences.preferences[i].value,
               global_preferences.preferences[i].persistent ? " (persistent)" : "");
    }
}

/* Set preference change callback */
void set_preference_callback(const char *key, void (*on_change)(preferences_t *prefs, const char *key, const char *value)) {
    for (int i = 0; i < global_preferences.preference_count; i++) {
        if (strcmp(global_preferences.preferences[i].key, key) == 0) {
            global_preferences.preferences[i].on_change = on_change;
            break;
        }
    }
}

/* Export preferences to file */
int export_preferences(const char *filename) {
    FILE *f = fopen(filename, "w");
    if (!f) return -1;
    
    fprintf(f, "# User preferences\n");
    fprintf(f, "# Generated by labwc configuration system\n\n");
    
    for (int i = 0; i < global_preferences.preference_count; i++) {
        fprintf(f, "%s=%s\n", 
                global_preferences.preferences[i].key,
                global_preferences.preferences[i].value);
    }
    
    fclose(f);
    return 0;
}

/* Import preferences from file */
int import_preferences(const char *filename) {
    FILE *f = fopen(filename, "r");
    if (!f) return -1;
    
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        /* Skip comments and empty lines */
        if (line[0] == '#' || line[0] == '\0' || line[0] == '\n') continue;
        
        /* Parse KEY=VALUE */
        char *line_copy = strdup(line);
        char *eq = strchr(line_copy, '=');
        if (!eq) continue;
        
        *eq = '\0';
        char *key = line_copy;
        char *value = eq + 1;
        
        /* Remove trailing newline */
        value[strcspn(value, "\n\r")] = '\0';
        
        /* Set preference */
        set_preference(key, value, true);
        
        free(line_copy);
    }
    
    fclose(f);
    return 0;
}

/* Initialize default preferences */
void init_default_preferences() {
    init_preferences(64);
    
    /* System preferences */
    set_preference("bar.position", "top", true);
    set_preference("bar.height", "32", true);
    set_preference("bar.exclusive-zone", "32", true);
    set_preference("bar.transparent", "false", true);
    set_preference("bar.animation", "true", true);
    
    /* Workspace preferences */
    set_preference("workspace.count", "9", true);
    set_preference("workspace.gap", "0", true);
    
    /* Focus preferences */
    set_preference("focus.follow-mouse", "true", true);
    set_preference("focus.cross-component", "true", true);
    
    /* Widget preferences */
    set_preference("widgets.clock.format", "24h", true);
    set_preference("widgets.clock.position", "center", true);
    set_preference("widgets.clock.show-seconds", "false", true);
    
    set_preference("widgets.cpu.show-icon", "true", true);
    set_preference("widgets.cpu.show-temp", "true", true);
    
    set_preference("widgets.memory.show-swap", "true", true);
    set_preference("widgets.memory.show-details", "true", true);
    
    set_preference("widgets.network.show-icon", "true", true);
    set_preference("widgets.network.show-signal", "true", true);
    set_preference("widgets.network.show-type", "true", true);
    
    set_preference("widgets.battery.show-percent", "true", true);
    set_preference("widgets.battery.show-time", "true", true);
    set_preference("widgets.battery.show-charging", "true", true);
    
    set_preference("widgets.volume.show-level", "true", true);
    set_preference("widgets.volume.show-muted", "true", true);
    
    /* Theme preferences */
    set_preference("theme.default", "catppuccin-mocha", true);
    set_preference("theme.accent", "#89b4fa", true);
    set_preference("theme.border", "#585b70", true);
    set_preference("theme.surface", "#45475a", true);
    
    /* Dock preferences */
    set_preference("dock.height", "56", true);
    set_preference("dock.position", "bottom", true);
    set_preference("dock.auto-hide", "false", true);
    
    /* Performance preferences */
    set_preference("performance.refresh-rate", "60", true);
    set_preference("performance.update-interval", "1000", true);
}
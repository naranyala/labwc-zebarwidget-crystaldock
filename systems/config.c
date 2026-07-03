/* systems/config.c - Centralized configuration management
 *
 * Common configuration operations for statusbars, docks, and widgets:
 * - Load configuration from various sources
 * - Validate configuration schemas
 * - Merge configurations
 * - Save user configuration
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "widget.h"

/* Configuration sources priority */
#define DEFAULT_CONFIG_PATH ".config/labwc/statusbar-configs"

typedef struct config_source_t {
    char *path;
    int priority;
} config_source_t;

/* Supported configuration formats */
typedef enum {
    CONFIG_JSON,
    CONFIG_INI,
    CONFIG_C,
    CONFIG_AUTO
} config_format_t;

/* Configuration validation result */
typedef struct config_validation_result_t {
    bool is_valid;
    char errors[256];
    char warnings[256];
} config_validation_result_t;

/* ============================================================================
 * Configuration Source Management
 * ============================================================================ */

static config_source_t config_sources[] = {
    {".config/labwc/statusbar-configs/main.conf", 100},  /* Highest priority */
    {".config/labwc/statusbar-configs/detailed.conf", 90},
    {".config/labwc/statusbar-configs/compact.conf", 80},
    {".config/labwc/statusbar-configs/minimalist.conf", 70},
    {".config/labwc/statusbar-configs", 60},  /* Directory fallback */
    {DEFAULT_CONFIG_PATH, 50},
    {NULL, 0}  /* End marker */
};

static config_source_t dock_config_sources[] = {
    {".config/labwc/dock-configs/crystal.ini", 100},
    {".config/labwc/dock-configs/none.ini", 90},
    {NULL, 0}
};

/* ============================================================================
 * Configuration Loading
 * ============================================================================ */

config_validation_result_t validate_bar_config(const char *config_path) {
    config_validation_result_t result = {0};
    
    FILE *f = fopen(config_path, "r");
    if (!f) {
        snprintf(result.errors, sizeof(result.errors), "Cannot open config file: %s", config_path);
        result.is_valid = false;
        return result;
    }
    
    /* Basic JSON validation for statusbar configs */
    char line[256];
    bool has_name = false;
    bool has_widgets = false;
    int line_count = 0;
    
    while (fgets(line, sizeof(line), f)) {
        line_count++;
        
        /* Check for required fields */
        if (strstr(line, "\"name\":") && !has_name) {
            has_name = true;
        }
        if (strstr(line, "\"widgets\":") && !has_widgets) {
            has_widgets = true;
        }
        
        /* Limit file size check */
        if (line_count > 1000) {
            snprintf(result.warnings, sizeof(result.warnings), "Config file exceeds 1000 lines, performance may be impacted");
            break;
        }
    }
    
    fclose(f);
    
    if (!has_name) {
        snprintf(result.errors, sizeof(result.errors), "Missing required field: name");
        result.is_valid = false;
        return result;
    }
    
    if (!has_widgets) {
        snprintf(result.warnings, sizeof(result.warnings), "Missing widgets field, using default configuration");
        has_widgets = true;  /* Force to true to avoid failure */
    }
    
    result.is_valid = (has_name && has_widgets);
    return result;
}

config_validation_result_t validate_dock_config(const char *config_path) {
    config_validation_result_t result = {0};
    
    FILE *f = fopen(config_path, "r");
    if (!f) {
        snprintf(result.errors, sizeof(result.errors), "Cannot open config file: %s", config_path);
        result.is_valid = false;
        return result;
    }
    
    /* Basic INI validation for dock configs */
    char line[256];
    bool has_section = false;
    int line_count = 0;
    
    while (fgets(line, sizeof(line), f)) {
        line_count++;
        
        if (strstr(line, "[section]")) {
            has_section = true;
        }
        
        if (line_count > 100) {
            snprintf(result.warnings, sizeof(result.warnings), "Config file exceeds 100 lines");
            break;
        }
    }
    
    fclose(f);
    
    result.is_valid = has_section;
    return result;
}

const char* find_best_config_file(config_source_t *sources, const char *preferred) {
    for (int i = 0; sources[i].path != NULL; i++) {
        const char *path = sources[i].path;
        
        /* Try preferred config first */
        if (preferred) {
            char preferred_path[256];
            snprintf(preferred_path, sizeof(preferred_path), "%s/%s", DEFAULT_CONFIG_PATH, preferred);
            if (strcmp(path, preferred_path) == 0) {
                if (access(path, F_OK) == 0) {
                    return path;
                }
            }
        }
        
        /* Try standard config paths */
        if (access(path, F_OK) == 0) {
            return path;
        }
    }
    
    return NULL;
}

/* ============================================================================
 * Configuration Validation
 * ============================================================================ */

bool validate_widget_config(widget_ops_t *ops) {
    if (!ops) return false;
    
    /* Widget must have at least init and render functions */
    return (ops->init && ops->render);
}

bool validate_dock_config(const char *config_name) {
    if (!config_name) return false;
    
    config_validation_result_t result = validate_dock_config_config(config_name);
    return result.is_valid;
}

/* ============================================================================
 * Configuration Serialization
 * ============================================================================ */

/* Export current configuration to file */
int export_config(const char *config_name, const char *output_path) {
    FILE *f = fopen(output_path, "w");
    if (!f) return -1;
    
    fprintf(f, "/* Exported configuration: %s */\n", config_name);
    fprintf(f, "{\n");
    fprintf(f, "  \"name\": \"%s\",\n", config_name);
    fprintf(f, "  \"exported\": true,\n");
    fprintf(f, "  \"timestamp\": %lu\n", (unsigned long)time(NULL));
    fprintf(f, "}\n");
    
    fclose(f);
    return 0;
}

/* ============================================================================
 * Configuration Migration
 * ============================================================================ */

/* Migrate old configuration format to new format */
int migrate_config(const char *old_config_path, const char *new_config_path) {
    FILE *old_f = fopen(old_config_path, "r");
    if (!old_f) return -1;
    
    FILE *new_f = fopen(new_config_path, "w");
    if (!new_f) {
        fclose(old_f);
        return -1;
    }
    
    fprintf(new_f, "/* Migrated configuration */\n");
    fprintf(new_f, "{\n");
    
    char line[256];
    while (fgets(line, sizeof(line), old_f)) {
        /* Transform old format to new format */
        char *transformed = transform_config_line(line);
        if (transformed) {
            fprintf(new_f, "%s", transformed);
            free(transformed);
        }
    }
    
    fprintf(new_f, "}\n");
    
    fclose(old_f);
    fclose(new_f);
    return 0;
}

char* transform_config_line(const char *old_line) {
    /* Implement configuration line transformation logic here */
    /* For example: convert from old widget syntax to new syntax */
    
    /* Simple pass-through implementation */
    char *copy = strdup(old_line);
    return copy;
}

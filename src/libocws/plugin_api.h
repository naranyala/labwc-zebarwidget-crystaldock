#ifndef OCWS_PLUGIN_API_H
#define OCWS_PLUGIN_API_H

#ifdef __cplusplus
extern "C" {
#endif

/* Current API version to ensure ABI compatibility */
#define OCWS_PLUGIN_API_VERSION 1

typedef struct {
    int api_version;               /* Must be set to OCWS_PLUGIN_API_VERSION */
    const char* name;              /* Name of the plugin */
    int tick_interval_sec;         /* Interval in seconds for on_tick callback. 0 to disable. */
    
    /* Lifecycle hooks */
    int (*init)(void);             /* Called when plugin is loaded. Return 0 on success. */
    void (*on_tick)(void);         /* Called every tick_interval_sec */
    void (*shutdown)(void);        /* Called when daemon shuts down */
    
    /* Event handling */
    void (*on_event)(const char* event_name, const char* payload);
} OcwsPlugin;

/* Every plugin must export this symbol */
extern OcwsPlugin OCWS_PLUGIN_ENTRY;

/* ============================================================
 * Host services — provided by the loader (ocws-brokerd / ocws-appletd)
 * and implemented in libocws-pluginrt (a shared library linked by both
 * the host and every plugin, so there is a single event bus instance).
 * Plugins call these to talk to the shell without shelling out.
 * ============================================================ */

/* Publish an event on the bus (and, if bridged, to zigshell-cairo-pango via ocws-emit). */
void ocws_plugin_emit(const char *event, const char *payload);
/* Desktop notification. */
void ocws_plugin_notify(const char *title, const char *body, const char *icon);
/* Read this plugin's config value (falls back to def). */
const char *ocws_plugin_config(const char *key, const char *def);

/* The host registers its implementations before loading plugins. */
typedef void (*ocws_plugin_emit_fn)(const char *event, const char *payload);
typedef void (*ocws_plugin_notify_fn)(const char *title, const char *body, const char *icon);
typedef const char *(*ocws_plugin_config_fn)(const char *key, const char *def);
void ocws_plugin_set_host(ocws_plugin_emit_fn emit,
                          ocws_plugin_notify_fn notify,
                          ocws_plugin_config_fn config);

#ifdef __cplusplus
}
#endif

#endif // OCWS_PLUGIN_API_H

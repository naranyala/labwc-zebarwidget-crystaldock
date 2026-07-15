#ifndef OCWS_BUS_H
#define OCWS_BUS_H

#include "plugin_api.h"

typedef void (*ocws_event_cb)(const char *topic, const char *payload, void *user);

/* In-process event bus used by the host (ocws-brokerd).
 * Subscribers registered with topic "*" receive every event. */

void ocws_bus_init(void);
void ocws_bus_subscribe(const char *topic, ocws_event_cb cb, void *user);
void ocws_bus_emit(const char *topic, const char *json);

/* Optional bridge: forwarded to an external sink (e.g. zigshell-cairo-pango via ocws-emit). */
void ocws_bus_set_zigshell_bridge(void (*fn)(const char *topic, const char *value));
void ocws_bus_emit_zigshell(const char *topic, const char *value);

#endif

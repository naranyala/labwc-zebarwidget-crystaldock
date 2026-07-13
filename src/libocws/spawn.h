#ifndef OCWS_SPAWN_H
#define OCWS_SPAWN_H

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <glib.h>

static inline void run_cmd_async(const char *cmd) {
    if (cmd && cmd[0]) {
        GError *error = NULL;
        gchar *argv[4] = {"/bin/sh", "-c", (gchar*)cmd, NULL};
        g_spawn_async(NULL, argv, NULL, G_SPAWN_SEARCH_PATH | G_SPAWN_DO_NOT_REAP_CHILD,
                      NULL, NULL, NULL, &error);
        if (error) {
            g_warning("run_cmd_async: spawn failed: %s", error->message);
            g_error_free(error);
        }
    }
}

#endif

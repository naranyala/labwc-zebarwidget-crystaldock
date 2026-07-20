/*
 * fonts-mgr-common.c — Helpers, paths, logging, async UI, CSS
 */

#include "fonts-mgr-common.h"
#include <stdarg.h>

/* ============================================================
 * Global Variables
 * ============================================================ */

FontPackage *g_packages = NULL;
SystemFont *g_system_fonts = NULL;
int g_system_font_count = 0;
int g_system_font_capacity = 0;

GtkListStore *g_font_list_store = NULL;
GtkTreeModelFilter *g_font_filter = NULL;
GtkSearchEntry *g_search_entry = NULL;
GtkTreeView *g_treeview = NULL;
GtkTextBuffer *g_log_buffer = NULL;
GtkWidget *g_log_view = NULL;
GtkLabel *g_stats_label = NULL;
GtkListStore *g_managed_store = NULL;

GtkWidget *g_preview_box = NULL;
GtkLabel *g_preview_family = NULL;
GtkLabel *g_preview_style = NULL;
GtkLabel *g_preview_file = NULL;
GtkLabel *g_preview_sample_sm = NULL;
GtkLabel *g_preview_sample_md = NULL;
GtkLabel *g_preview_sample_lg = NULL;
GtkLabel *g_preview_sample_xl = NULL;
GtkLabel *g_preview_bold = NULL;
GtkLabel *g_preview_italic = NULL;
GtkLabel *g_preview_bold_italic = NULL;
GtkLabel *g_preview_mono = NULL;
GtkLabel *g_preview_empty = NULL;
GtkEntry *g_preview_text_entry = NULL;

const char *FONTS_DIR = NULL;
const char *MANAGED_DIR = NULL;
const char *CURSORS_DIR = NULL;

/* ============================================================
 * Paths
 * ============================================================ */

void fonts_mgr_init_paths(void) {
    const char *data_dir = g_get_user_data_dir();

    static char fonts_buf[512];
    static char managed_buf[512];
    static char cursors_buf[512];

    snprintf(fonts_buf, sizeof(fonts_buf), "%s/fonts", data_dir);
    snprintf(managed_buf, sizeof(managed_buf), "%s/fonts/ocws-managed", data_dir);
    snprintf(cursors_buf, sizeof(cursors_buf), "%s/icons", data_dir);

    FONTS_DIR = fonts_buf;
    MANAGED_DIR = managed_buf;
    CURSORS_DIR = cursors_buf;
}

/* ============================================================
 * Logging
 * ============================================================ */

static gboolean append_log_idle(gpointer data) {
    char *msg = (char *)data;
    GtkTextIter end;
    gtk_text_buffer_get_end_iter(g_log_buffer, &end);
    gtk_text_buffer_insert(g_log_buffer, &end, msg, -1);
    gtk_text_buffer_insert(g_log_buffer, &end, "\n", -1);

    gtk_text_buffer_get_end_iter(g_log_buffer, &end);
    gtk_text_view_scroll_to_iter(GTK_TEXT_VIEW(g_log_view), &end, 0.0, FALSE, 0.0, 1.0);
    g_free(msg);
    return G_SOURCE_REMOVE;
}

void fonts_mgr_log_msg(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    char buf[1024];
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);

    char *msg = g_strdup(buf);
    g_idle_add(append_log_idle, msg);
}

void fonts_mgr_run_cmd_logged(const char *cmd) {
    fonts_mgr_log_msg("$ %s", cmd);
    GError *error = NULL;
    gchar *stdout_buf = NULL;
    gchar *argv[4] = {"/bin/sh", "-c", (gchar*)cmd, NULL};
    gint exit_status;
    if (!g_spawn_sync(NULL, argv, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL, &stdout_buf, NULL, &exit_status, &error)) {
        fonts_mgr_log_msg("ERROR: Failed to execute command: %s", error->message);
        g_error_free(error);
        return;
    }
    if (stdout_buf) {
        char line[512];
        char *p = stdout_buf;
        char *next;
        while (p && *p) {
            next = strchr(p, '\n');
            if (next) *next = '\0';
            strncpy(line, p, sizeof(line) - 1);
            line[sizeof(line) - 1] = '\0';
            fonts_mgr_log_msg("  %s", line);
            if (next) {
                *next = '\n';
                p = next + 1;
            } else {
                break;
            }
        }
        g_free(stdout_buf);
    }
    if (WIFEXITED(exit_status) && WEXITSTATUS(exit_status) != 0) {
        fonts_mgr_log_msg("Exit code: %d", WEXITSTATUS(exit_status));
    }
}

/* ============================================================
 * File Helpers
 * ============================================================ */

int fonts_mgr_dir_exists(const char *path) { return ocws_fonts_dir_exists(path); }
int fonts_mgr_file_exists(const char *path) { return ocws_fonts_file_exists(path); }
void fonts_mgr_make_dir_p(const char *path) { ocws_fonts_make_dir_p(path); }

/* ============================================================
 * Async UI Helpers
 * ============================================================ */

static gboolean set_label_text_idle(gpointer data) {
    LabelUpdate *u = (LabelUpdate *)data;
    gtk_label_set_text(GTK_LABEL(u->label), u->text);
    g_free(u);
    return G_SOURCE_REMOVE;
}

void fonts_mgr_set_label_async(GtkWidget *label, const char *text) {
    LabelUpdate *u = g_new0(LabelUpdate, 1);
    u->label = label;
    u->text = g_strdup(text);
    g_idle_add(set_label_text_idle, u);
}

static gboolean set_sensitivity_idle(gpointer data) {
    SensitivityUpdate *u = (SensitivityUpdate *)data;
    gtk_widget_set_sensitive(u->widget, u->sensitive);
    g_free(u);
    return G_SOURCE_REMOVE;
}

void fonts_mgr_set_sensitive_async(GtkWidget *widget, gboolean sensitive) {
    SensitivityUpdate *u = g_new0(SensitivityUpdate, 1);
    u->widget = widget;
    u->sensitive = sensitive;
    g_idle_add(set_sensitivity_idle, u);
}



/*
 * ocws-dotdesktop-mgr.c — Desktop Entry (.desktop) Manager GUI
 *
 * GTK3 application to manage, edit, backup, and restore .desktop files.
 *
 * Features:
 *   - Browse/search system + user .desktop files
 *   - Edit Name, Exec, Icon, Comment, Categories, Terminal
 *   - Icon picker with image preview
 *   - Quick category picker dropdown
 *   - Validation (required fields, Exec path check)
 *   - Bulk enable/disable (rename .desktop ↔ .desktop.disabled)
 *   - Backup/restore
 *   - File info panel (size, permissions, last modified)
 */

#include <gtk/gtk.h>
#include "../libocws/gtk.h"
#include <glib.h>
#include <gio/gio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>

#define APP_ID "org.ocws.dotdesktop-mgr"

/* Common .desktop categories */
static const char *COMMON_CATEGORIES[] = {
    "AudioVideo", "Audio", "Video", "Development", "Education",
    "Game", "Graphics", "Network", "Office", "Science",
    "Settings", "System", "Utility", "Calendar", "Database",
    "Dictionary", "TextEditor", "FileManager", "TerminalEmulator",
    "FileTransfer", "InstantMessaging", "ContactManagement",
    NULL
};

enum {
    COL_ENABLED,
    COL_ICON,
    COL_NAME,
    COL_FILE,
    COL_PATH,
    NUM_COLS
};

static GtkListStore *store = NULL;
static GtkWidget *tree_view = NULL;
static GtkWidget *entry_name = NULL;
static GtkWidget *entry_exec = NULL;
static GtkWidget *entry_icon = NULL;
static GtkWidget *entry_comment = NULL;
static GtkWidget *entry_categories = NULL;
static GtkWidget *check_terminal = NULL;
static GtkWidget *status_label = NULL;
static GtkWidget *search_entry = NULL;
static GtkWidget *icon_preview = NULL;
static GtkWidget *category_combo = NULL;
static GtkWidget *info_label = NULL;
static GtkTreeModelFilter *filter_model = NULL;

static char current_file_path[512] = {0};

/* ============================================================
 * Backend Functions
 * ============================================================ */

static void ensure_backup_dir(void) {
    const char *data_dir = g_get_user_data_dir();
    char path[512];
    snprintf(path, sizeof(path), "%s/ocws/dotdesktop-backups", data_dir);
    g_mkdir_with_parents(path, 0755);
}

static void load_desktop_files_from_dir(const char *dir_path) {
    GDir *dir = g_dir_open(dir_path, 0, NULL);
    if (!dir) return;

    const char *filename;
    while ((filename = g_dir_read_name(dir)) != NULL) {
        gboolean enabled = TRUE;
        const char *check_name = filename;

        /* Also load .desktop.disabled files */
        if (g_str_has_suffix(filename, ".desktop.disabled")) {
            enabled = FALSE;
        } else if (!g_str_has_suffix(filename, ".desktop")) {
            continue;
        }

        char path[1024];
        snprintf(path, sizeof(path), "%s/%s", dir_path, check_name);

        GKeyFile *key_file = g_key_file_new();
        if (g_key_file_load_from_file(key_file, path, G_KEY_FILE_NONE, NULL)) {
            gchar *name = g_key_file_get_locale_string(key_file, "Desktop Entry", "Name", NULL, NULL);
            gchar *icon_name = g_key_file_get_string(key_file, "Desktop Entry", "Icon", NULL);
            if (!name) name = g_strdup(filename);
            if (!icon_name) icon_name = g_strdup("application-x-executable");

            GtkTreeIter iter;
            gtk_list_store_append(store, &iter);
            gtk_list_store_set(store, &iter,
                COL_ENABLED, enabled,
                COL_ICON, icon_name,
                COL_NAME, name,
                COL_FILE, filename,
                COL_PATH, path,
                -1);

            g_free(name);
            g_free(icon_name);
        }
        g_key_file_free(key_file);
    }
    g_dir_close(dir);
}

static void load_all_desktop_files(void) {
    gtk_list_store_clear(store);
    const gchar * const * sys_dirs = g_get_system_data_dirs();
    for (int i = 0; sys_dirs && sys_dirs[i]; i++) {
        char path[512];
        snprintf(path, sizeof(path), "%s/applications", sys_dirs[i]);
        load_desktop_files_from_dir(path);
    }
    const char *data_dir = g_get_user_data_dir();
    char path[512];
    snprintf(path, sizeof(path), "%s/applications", data_dir);
    load_desktop_files_from_dir(path);
}

static void clear_editor(void) {
    gtk_entry_set_text(GTK_ENTRY(entry_name), "");
    gtk_entry_set_text(GTK_ENTRY(entry_exec), "");
    gtk_entry_set_text(GTK_ENTRY(entry_icon), "");
    gtk_entry_set_text(GTK_ENTRY(entry_comment), "");
    gtk_entry_set_text(GTK_ENTRY(entry_categories), "");
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(check_terminal), FALSE);
    gtk_combo_box_set_active(GTK_COMBO_BOX(category_combo), -1);
    if (icon_preview) gtk_image_set_from_icon_name(GTK_IMAGE(icon_preview), "application-x-executable", GTK_ICON_SIZE_DIALOG);
    if (info_label) gtk_label_set_text(GTK_LABEL(info_label), "");
    current_file_path[0] = '\0';
}

/* ============================================================
 * Icon Preview
 * ============================================================ */

static void update_icon_preview(const char *icon_value) {
    if (!icon_preview || !icon_value || !*icon_value) {
        if (icon_preview) gtk_image_set_from_icon_name(GTK_IMAGE(icon_preview), "application-x-executable", GTK_ICON_SIZE_DIALOG);
        return;
    }

    /* If it's a full path to a file, load it directly */
    if (g_path_is_absolute(icon_value) && g_file_test(icon_value, G_FILE_TEST_EXISTS)) {
        GdkPixbuf *pixbuf = gdk_pixbuf_new_from_file_at_scale(icon_value, 64, 64, TRUE, NULL);
        if (pixbuf) {
            gtk_image_set_from_pixbuf(GTK_IMAGE(icon_preview), pixbuf);
            g_object_unref(pixbuf);
            return;
        }
    }

    /* Otherwise treat as icon theme name */
    GtkIconTheme *theme = gtk_icon_theme_get_default();
    GdkPixbuf *pixbuf = gtk_icon_theme_load_icon(theme, icon_value, 48, 0, NULL);
    if (pixbuf) {
        gtk_image_set_from_pixbuf(GTK_IMAGE(icon_preview), pixbuf);
        g_object_unref(pixbuf);
    } else {
        gtk_image_set_from_icon_name(GTK_IMAGE(icon_preview), "application-x-executable", GTK_ICON_SIZE_DIALOG);
    }
}

static void on_icon_changed(GtkEditable *editable, gpointer data) {
    (void)data;
    const char *text = gtk_entry_get_text(GTK_ENTRY(editable));
    update_icon_preview(text);
}

static void on_browse_icon_clicked(GtkWidget *widget, gpointer data) {
    (void)widget;
    (void)data;

    GtkWidget *dialog = gtk_file_chooser_dialog_new("Select Icon",
        NULL, GTK_FILE_CHOOSER_ACTION_OPEN,
        "_Cancel", GTK_RESPONSE_CANCEL,
        "_Open", GTK_RESPONSE_ACCEPT,
        NULL);

    /* Add filters for image files */
    GtkFileFilter *filter = gtk_file_filter_new();
    gtk_file_filter_set_name(filter, "Image files");
    gtk_file_filter_add_mime_type(filter, "image/png");
    gtk_file_filter_add_mime_type(filter, "image/svg+xml");
    gtk_file_filter_add_mime_type(filter, "image/jpeg");
    gtk_file_filter_add_pattern(filter, "*.png");
    gtk_file_filter_add_pattern(filter, "*.svg");
    gtk_file_filter_add_pattern(filter, "*.jpg");
    gtk_file_filter_add_pattern(filter, "*.jpeg");
    gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), filter);

    GtkFileFilter *all_filter = gtk_file_filter_new();
    gtk_file_filter_set_name(all_filter, "All files");
    gtk_file_filter_add_pattern(all_filter, "*");
    gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), all_filter);

    /* Start in common icon directories */
    const char *data_dir = g_get_user_data_dir();
    char icon_dir[512];
    snprintf(icon_dir, sizeof(icon_dir), "%s/icons", data_dir);
    if (g_file_test(icon_dir, G_FILE_TEST_IS_DIR))
        gtk_file_chooser_set_current_folder(GTK_FILE_CHOOSER(dialog), icon_dir);
    else {
        const gchar * const * sys_dirs = g_get_system_data_dirs();
        if (sys_dirs && sys_dirs[0]) {
            char sys_icon_dir[512];
            snprintf(sys_icon_dir, sizeof(sys_icon_dir), "%s/icons", sys_dirs[0]);
            gtk_file_chooser_set_current_folder(GTK_FILE_CHOOSER(dialog), sys_icon_dir);
        }
    }

    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        char *filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        if (filename) {
            gtk_entry_set_text(GTK_ENTRY(entry_icon), filename);
            update_icon_preview(filename);
            g_free(filename);
        }
    }
    gtk_widget_destroy(dialog);
}

/* ============================================================
 * File Info
 * ============================================================ */

static void update_file_info(const char *path) {
    if (!info_label || !path || !*path) {
        if (info_label) gtk_label_set_text(GTK_LABEL(info_label), "");
        return;
    }

    struct stat st;
    if (stat(path, &st) != 0) {
        gtk_label_set_text(GTK_LABEL(info_label), "Cannot read file info");
        return;
    }

    char size_str[64];
    if (st.st_size < 1024)
        snprintf(size_str, sizeof(size_str), "%ld B", (long)st.st_size);
    else if (st.st_size < 1024 * 1024)
        snprintf(size_str, sizeof(size_str), "%.1f KB", st.st_size / 1024.0);
    else
        snprintf(size_str, sizeof(size_str), "%.1f MB", st.st_size / (1024.0 * 1024.0));

    char time_str[64];
    struct tm *tm = localtime(&st.st_mtime);
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M", tm);

    char perms[11];
    snprintf(perms, sizeof(perms), "%c%c%c%c%c%c%c%c%c%c",
        S_ISDIR(st.st_mode) ? 'd' : '-',
        (st.st_mode & S_IRUSR) ? 'r' : '-',
        (st.st_mode & S_IWUSR) ? 'w' : '-',
        (st.st_mode & S_IXUSR) ? 'x' : '-',
        (st.st_mode & S_IRGRP) ? 'r' : '-',
        (st.st_mode & S_IWGRP) ? 'w' : '-',
        (st.st_mode & S_IXGRP) ? 'x' : '-',
        (st.st_mode & S_IROTH) ? 'r' : '-',
        (st.st_mode & S_IWOTH) ? 'w' : '-',
        (st.st_mode & S_IXOTH) ? 'x' : '-');

    char info[512];
    snprintf(info, sizeof(info), "%s  |  %s  |  %s", size_str, perms, time_str);
    gtk_label_set_text(GTK_LABEL(info_label), info);
}

/* ============================================================
 * Validation
 * ============================================================ */

static gboolean validate_entry(void) {
    const char *name = gtk_entry_get_text(GTK_ENTRY(entry_name));
    const char *exec = gtk_entry_get_text(GTK_ENTRY(entry_exec));

    if (!name || strlen(name) == 0) {
        gtk_label_set_text(GTK_LABEL(status_label), "Validation: Name is required!");
        return FALSE;
    }
    if (!exec || strlen(exec) == 0) {
        gtk_label_set_text(GTK_LABEL(status_label), "Validation: Command (Exec) is required!");
        return FALSE;
    }

    /* Check if exec path exists (first word is the command) */
    char cmd_name[256] = {0};
    sscanf(exec, "%255s", cmd_name);
    if (cmd_name[0] != '\0') {
        char which_cmd[280];
        snprintf(which_cmd, sizeof(which_cmd), "command -v %s >/dev/null 2>&1", cmd_name);
        pid_t pid = fork();
        if (pid == 0) {
            execl("/bin/sh", "sh", "-c", which_cmd, NULL);
            exit(1);
        }
        int status = 0;
        waitpid(pid, &status, 0);
        if (WIFEXITED(status) && WEXITSTATUS(status) != 0) {
            char msg[512];
            snprintf(msg, sizeof(msg), "Validation warning: '%s' not found in PATH", cmd_name);
            gtk_label_set_text(GTK_LABEL(status_label), msg);
            return TRUE; /* Warning, not error */
        }
    }
    
    gtk_label_set_text(GTK_LABEL(status_label), "Validation passed");
    return TRUE;
}

/* ============================================================
 * Bulk Enable/Disable
 * ============================================================ */

static void on_toggle_enabled(GtkCellRendererToggle *renderer, gchar *path_str, gpointer data) {
    (void)renderer;
    (void)data;

    GtkTreeIter iter;
    if (!gtk_tree_model_get_iter_from_string(GTK_TREE_MODEL(filter_model), &iter, path_str))
        return;

    gboolean enabled;
    gchar *file_path;
    gtk_tree_model_get(GTK_TREE_MODEL(filter_model), &iter,
        COL_ENABLED, &enabled,
        COL_PATH, &file_path,
        -1);

    if (!file_path) return;

    /* Toggle: rename file */
    char new_path[1024];
    if (enabled) {
        /* Disable: .desktop → .desktop.disabled */
        snprintf(new_path, sizeof(new_path), "%s.disabled", file_path);
    } else {
        /* Enable: .desktop.disabled → .desktop */
        size_t len = strlen(file_path);
        if (len > 10 && strcmp(file_path + len - 10, ".disabled") == 0) {
            snprintf(new_path, sizeof(new_path), "%.*s", (int)(len - 10), file_path);
        } else {
            g_free(file_path);
            return;
        }
    }

    if (rename(file_path, new_path) == 0) {
        /* Update the model */
        gtk_list_store_set(store, &iter, COL_ENABLED, !enabled, COL_PATH, new_path, -1);

        /* If this was the currently loaded file, update current_file_path */
        if (strcmp(file_path, current_file_path) == 0) {
            strncpy(current_file_path, new_path, sizeof(current_file_path) - 1);
        }
        
        char msg[256];
        char *basename = g_path_get_basename(new_path);
        snprintf(msg, sizeof(msg), "%s: %s", !enabled ? "Enabled" : "Disabled", basename);
        g_free(basename);
        gtk_label_set_text(GTK_LABEL(status_label), msg);
    } else {
        gtk_label_set_text(GTK_LABEL(status_label), "Failed to rename file");
    }

    g_free(file_path);
}

/* ============================================================
 * Category Picker
 * ============================================================ */

static void on_category_combo_changed(GtkComboBox *combo, gpointer data) {
    (void)data;
    int idx = gtk_combo_box_get_active(combo);
    if (idx < 0) return;

    const char *cat = COMMON_CATEGORIES[idx];
    if (!cat) return;

    /* Append to categories field if not already present */
    const char *current = gtk_entry_get_text(GTK_ENTRY(entry_categories));
    if (current && strstr(current, cat)) return; /* Already present */

    char new_cats[1024];
    if (current && strlen(current) > 0)
        snprintf(new_cats, sizeof(new_cats), "%s;%s", current, cat);
    else
        snprintf(new_cats, sizeof(new_cats), "%s", cat);

    gtk_entry_set_text(GTK_ENTRY(entry_categories), new_cats);
    gtk_combo_box_set_active(combo, -1); /* Reset selection */
}

/* ============================================================
 * UI Callbacks
 * ============================================================ */

static void on_selection_changed(GtkTreeSelection *selection, gpointer data) {
    (void)data;
    GtkTreeIter iter;
    GtkTreeModel *model;

    if (gtk_tree_selection_get_selected(selection, &model, &iter)) {
        gchar *path;
        gtk_tree_model_get(model, &iter, COL_PATH, &path, -1);
        if (path) {
            /* Load into editor */
            GKeyFile *key_file = g_key_file_new();
            if (g_key_file_load_from_file(key_file, path, G_KEY_FILE_NONE, NULL)) {
                gchar *name = g_key_file_get_locale_string(key_file, "Desktop Entry", "Name", NULL, NULL);
                gchar *exec = g_key_file_get_string(key_file, "Desktop Entry", "Exec", NULL);
                gchar *icon = g_key_file_get_string(key_file, "Desktop Entry", "Icon", NULL);
                gchar *comment = g_key_file_get_locale_string(key_file, "Desktop Entry", "Comment", NULL, NULL);
                gchar *categories = g_key_file_get_string(key_file, "Desktop Entry", "Categories", NULL);
                gboolean terminal = g_key_file_get_boolean(key_file, "Desktop Entry", "Terminal", NULL);

                gtk_entry_set_text(GTK_ENTRY(entry_name), name ? name : "");
                gtk_entry_set_text(GTK_ENTRY(entry_exec), exec ? exec : "");
                gtk_entry_set_text(GTK_ENTRY(entry_icon), icon ? icon : "");
                gtk_entry_set_text(GTK_ENTRY(entry_comment), comment ? comment : "");
                gtk_entry_set_text(GTK_ENTRY(entry_categories), categories ? categories : "");
                gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(check_terminal), terminal);

                update_icon_preview(icon);
                g_free(name);
                g_free(exec);
                g_free(icon);
                g_free(comment);
                g_free(categories);
            }
            g_key_file_free(key_file);

            strncpy(current_file_path, path, sizeof(current_file_path) - 1);
            update_file_info(path);

            char *basename = g_path_get_basename(path);
            char msg[1024];
            snprintf(msg, sizeof(msg), "Loaded: %s", basename);
            g_free(basename);
            gtk_label_set_text(GTK_LABEL(status_label), msg);
        }
        g_free(path);
    }
}

static void on_save_clicked(GtkWidget *widget, gpointer data) {
    (void)widget;
    (void)data;

    if (strlen(current_file_path) == 0) {
        gtk_label_set_text(GTK_LABEL(status_label), "No file selected to save!");
        return;
    }

    if (!validate_entry()) return;

    const char *name = gtk_entry_get_text(GTK_ENTRY(entry_name));
    const char *exec = gtk_entry_get_text(GTK_ENTRY(entry_exec));
    const char *icon = gtk_entry_get_text(GTK_ENTRY(entry_icon));
    const char *comment = gtk_entry_get_text(GTK_ENTRY(entry_comment));
    const char *categories = gtk_entry_get_text(GTK_ENTRY(entry_categories));
    gboolean terminal = gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(check_terminal));

    char save_path[1024];
    strncpy(save_path, current_file_path, sizeof(save_path));

    /* If saving a system file, save to user data dir */
    const char *data_dir = g_get_user_data_dir();
    char user_app_dir[512];
    snprintf(user_app_dir, sizeof(user_app_dir), "%s/applications", data_dir);
    
    if (!g_str_has_prefix(current_file_path, user_app_dir)) {
        char *basename = g_path_get_basename(current_file_path);
        snprintf(save_path, sizeof(save_path), "%s/%s", user_app_dir, basename);
        g_free(basename);
        g_mkdir_with_parents(user_app_dir, 0755);
    }

    GKeyFile *key_file = g_key_file_new();
    g_key_file_load_from_file(key_file, current_file_path, G_KEY_FILE_NONE, NULL);

    if (!g_key_file_has_group(key_file, "Desktop Entry"))
        g_key_file_set_string(key_file, "Desktop Entry", "Type", "Application");

    g_key_file_set_string(key_file, "Desktop Entry", "Name", name);
    g_key_file_set_string(key_file, "Desktop Entry", "Exec", exec);
    g_key_file_set_string(key_file, "Desktop Entry", "Icon", icon);
    if (strlen(comment) > 0) g_key_file_set_string(key_file, "Desktop Entry", "Comment", comment);
    if (strlen(categories) > 0) g_key_file_set_string(key_file, "Desktop Entry", "Categories", categories);
    g_key_file_set_boolean(key_file, "Desktop Entry", "Terminal", terminal);

    gsize length;
    gchar *content = g_key_file_to_data(key_file, &length, NULL);
    if (content) {
        if (g_file_set_contents(save_path, content, length, NULL)) {
            char msg[1024];
            snprintf(msg, sizeof(msg), "Saved: %s", save_path);
            gtk_label_set_text(GTK_LABEL(status_label), msg);
            strncpy(current_file_path, save_path, sizeof(current_file_path) - 1);
            load_all_desktop_files();
            update_file_info(save_path);
        } else {
            gtk_label_set_text(GTK_LABEL(status_label), "Failed to save file.");
        }
        g_free(content);
    }
    g_key_file_free(key_file);
}

static void on_backup_clicked(GtkWidget *widget, gpointer data) {
    (void)widget;
    (void)data;

    if (strlen(current_file_path) == 0) {
        gtk_label_set_text(GTK_LABEL(status_label), "No file selected to backup!");
        return;
    }

    ensure_backup_dir();

    char *basename = g_path_get_basename(current_file_path);
    const char *data_dir = g_get_user_data_dir();

    char backup_path[1024];
    snprintf(backup_path, sizeof(backup_path), "%s/ocws/dotdesktop-backups/%s", data_dir, basename);

    gchar *content;
    gsize length;
    if (g_file_get_contents(current_file_path, &content, &length, NULL)) {
        if (g_file_set_contents(backup_path, content, length, NULL)) {
            char msg[1024];
            snprintf(msg, sizeof(msg), "Backed up: %s", basename);
            gtk_label_set_text(GTK_LABEL(status_label), msg);
        }
        g_free(content);
    }
    g_free(basename);
}

static void on_restore_clicked(GtkWidget *widget, gpointer data) {
    (void)widget;
    (void)data;

    if (strlen(current_file_path) == 0) {
        gtk_label_set_text(GTK_LABEL(status_label), "Select an app first to restore its backup!");
        return;
    }

    char *basename = g_path_get_basename(current_file_path);
    const char *data_dir = g_get_user_data_dir();

    char backup_path[1024];
    snprintf(backup_path, sizeof(backup_path), "%s/ocws/dotdesktop-backups/%s", data_dir, basename);

    if (g_file_test(backup_path, G_FILE_TEST_EXISTS)) {
        char dest_path[1024];
        snprintf(dest_path, sizeof(dest_path), "%s/applications/%s", data_dir, basename);

        gchar *content;
        gsize length;
        if (g_file_get_contents(backup_path, &content, &length, NULL)) {
            if (g_file_set_contents(dest_path, content, length, NULL)) {
                char msg[1024];
                snprintf(msg, sizeof(msg), "Restored: %s", basename);
                gtk_label_set_text(GTK_LABEL(status_label), msg);
                load_all_desktop_files();
                strncpy(current_file_path, dest_path, sizeof(current_file_path) - 1);
                update_file_info(dest_path);
            }
            g_free(content);
        }
    } else {
        gtk_label_set_text(GTK_LABEL(status_label), "No backup found!");
    }
    g_free(basename);
}

static void on_new_clicked(GtkWidget *widget, gpointer data) {
    (void)widget;
    (void)data;
    clear_editor();

    const char *data_dir = g_get_user_data_dir();
    snprintf(current_file_path, sizeof(current_file_path), "%s/applications/new_app.desktop", data_dir);
    gtk_label_set_text(GTK_LABEL(status_label), "New template. Fill details and save.");
}

static void on_validate_clicked(GtkWidget *widget, gpointer data) {
    (void)widget;
    (void)data;
    validate_entry();
}

static gboolean search_filter_func(GtkTreeModel *model, GtkTreeIter *iter, gpointer data) {
    (void)data;
    const char *search_text = gtk_entry_get_text(GTK_ENTRY(search_entry));
    if (!search_text || strlen(search_text) == 0) return TRUE;

    gchar *name = NULL;
    gchar *file = NULL;
    gtk_tree_model_get(model, iter, COL_NAME, &name, COL_FILE, &file, -1);

    gboolean visible = FALSE;
    if (name) {
        gchar *name_lower = g_utf8_strdown(name, -1);
        gchar *search_lower = g_utf8_strdown(search_text, -1);
        if (strstr(name_lower, search_lower) != NULL) visible = TRUE;
        g_free(name_lower);
        g_free(search_lower);
    }
    if (!visible && file) {
        gchar *file_lower = g_utf8_strdown(file, -1);
        gchar *search_lower = g_utf8_strdown(search_text, -1);
        if (strstr(file_lower, search_lower) != NULL) visible = TRUE;
        g_free(file_lower);
        g_free(search_lower);
    }

    g_free(name);
    g_free(file);
    return visible;
}

static void on_search_changed(GtkEditable *editable, gpointer data) {
    (void)editable;
    (void)data;
    if (filter_model) gtk_tree_model_filter_refilter(filter_model);
}

/* ============================================================
 * UI Construction
 * ============================================================ */

static GtkWidget* create_editor_row(const char *label_text, GtkWidget **entry_widget) {
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    gtk_widget_set_margin_bottom(box, 8);

    GtkWidget *label = gtk_label_new(label_text);
    gtk_widget_set_size_request(label, 100, -1);
    gtk_widget_set_halign(label, GTK_ALIGN_END);
    gtk_box_pack_start(GTK_BOX(box), label, FALSE, FALSE, 0);

    *entry_widget = gtk_entry_new();
    gtk_widget_set_hexpand(*entry_widget, TRUE);
    gtk_box_pack_start(GTK_BOX(box), *entry_widget, TRUE, TRUE, 0);

    return box;
}

static GtkWidget* create_icon_row(void) {
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    gtk_widget_set_margin_bottom(box, 8);

    GtkWidget *label = gtk_label_new("Icon:");
    gtk_widget_set_size_request(label, 100, -1);
    gtk_widget_set_halign(label, GTK_ALIGN_END);
    gtk_box_pack_start(GTK_BOX(box), label, FALSE, FALSE, 0);

    entry_icon = gtk_entry_new();
    gtk_widget_set_hexpand(entry_icon, TRUE);
    g_signal_connect(entry_icon, "changed", G_CALLBACK(on_icon_changed), NULL);
    gtk_box_pack_start(GTK_BOX(box), entry_icon, TRUE, TRUE, 0);

    GtkWidget *browse_btn = gtk_button_new_with_label("Browse...");
    g_signal_connect(browse_btn, "clicked", G_CALLBACK(on_browse_icon_clicked), NULL);
    gtk_box_pack_start(GTK_BOX(box), browse_btn, FALSE, FALSE, 0);

    icon_preview = gtk_image_new_from_icon_name("application-x-executable", GTK_ICON_SIZE_DIALOG);
    gtk_widget_set_size_request(icon_preview, 48, 48);
    gtk_box_pack_start(GTK_BOX(box), icon_preview, FALSE, FALSE, 0);

    return box;
}

static GtkWidget* create_category_row(void) {
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    gtk_widget_set_margin_bottom(box, 8);

    GtkWidget *label = gtk_label_new("Categories:");
    gtk_widget_set_size_request(label, 100, -1);
    gtk_widget_set_halign(label, GTK_ALIGN_END);
    gtk_box_pack_start(GTK_BOX(box), label, FALSE, FALSE, 0);

    entry_categories = gtk_entry_new();
    gtk_widget_set_hexpand(entry_categories, TRUE);
    gtk_box_pack_start(GTK_BOX(box), entry_categories, TRUE, TRUE, 0);

    /* Category quick-add dropdown */
    GtkListStore *cat_store = gtk_list_store_new(1, G_TYPE_STRING);
    for (int i = 0; COMMON_CATEGORIES[i]; i++) {
        GtkTreeIter iter;
        gtk_list_store_append(cat_store, &iter);
        gtk_list_store_set(cat_store, &iter, 0, COMMON_CATEGORIES[i], -1);
    }

    category_combo = gtk_combo_box_new_with_model(GTK_TREE_MODEL(cat_store));
    g_object_unref(cat_store);

    GtkCellRenderer *renderer = gtk_cell_renderer_text_new();
    gtk_cell_layout_pack_start(GTK_CELL_LAYOUT(category_combo), renderer, TRUE);
    gtk_cell_layout_set_attributes(GTK_CELL_LAYOUT(category_combo), renderer, "text", 0, NULL);

    gtk_combo_box_set_wrap_width(GTK_COMBO_BOX(category_combo), 4);
    g_signal_connect(category_combo, "changed", G_CALLBACK(on_category_combo_changed), NULL);
    gtk_box_pack_start(GTK_BOX(box), category_combo, FALSE, FALSE, 0);

    return box;
}

static void activate(GtkApplication *app, gpointer user_data) {
    (void)user_data;

    ocws_gtk_enforce_premium_theme();
    ocws_gtk_apply_dynamic_css(app, NULL);

    GtkWidget *window = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window), "OCWS DotDesktop Manager");
    gtk_window_set_default_size(GTK_WINDOW(window), 960, 650);
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);

    /* Header bar */
    GtkWidget *header = gtk_header_bar_new();
    gtk_header_bar_set_show_close_button(GTK_HEADER_BAR(header), TRUE);
    gtk_header_bar_set_title(GTK_HEADER_BAR(header), "Desktop Entries");
    gtk_window_set_titlebar(GTK_WINDOW(window), header);

    GtkWidget *new_btn = gtk_button_new_from_icon_name("document-new-symbolic", GTK_ICON_SIZE_SMALL_TOOLBAR);
    gtk_widget_set_tooltip_text(new_btn, "New Desktop File");
    g_signal_connect(new_btn, "clicked", G_CALLBACK(on_new_clicked), NULL);
    gtk_header_bar_pack_start(GTK_HEADER_BAR(header), new_btn);

    /* Main split container */
    GtkWidget *paned = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL);
    gtk_container_add(GTK_CONTAINER(window), paned);
    gtk_paned_set_position(GTK_PANED(paned), 350);

    /* Left pane: Search + TreeView */
    GtkWidget *left_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_paned_pack1(GTK_PANED(paned), left_box, TRUE, FALSE);

    /* Search */
    search_entry = gtk_search_entry_new();
    gtk_widget_set_margin_top(search_entry, 8);
    gtk_widget_set_margin_bottom(search_entry, 8);
    gtk_widget_set_margin_start(search_entry, 8);
    gtk_widget_set_margin_end(search_entry, 8);
    g_signal_connect(search_entry, "changed", G_CALLBACK(on_search_changed), NULL);
    gtk_box_pack_start(GTK_BOX(left_box), search_entry, FALSE, FALSE, 0);

    /* TreeView with enabled toggle + icon + name */
    store = gtk_list_store_new(NUM_COLS, G_TYPE_BOOLEAN, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
    filter_model = GTK_TREE_MODEL_FILTER(gtk_tree_model_filter_new(GTK_TREE_MODEL(store), NULL));
    gtk_tree_model_filter_set_visible_func(filter_model, search_filter_func, NULL, NULL);

    tree_view = gtk_tree_view_new_with_model(GTK_TREE_MODEL(filter_model));
    gtk_tree_view_set_headers_visible(GTK_TREE_VIEW(tree_view), FALSE);

    /* Enabled toggle column */
    GtkCellRenderer *renderer_toggle = gtk_cell_renderer_toggle_new();
    g_signal_connect(renderer_toggle, "toggled", G_CALLBACK(on_toggle_enabled), NULL);
    GtkTreeViewColumn *col_toggle = gtk_tree_view_column_new_with_attributes("", renderer_toggle, "active", COL_ENABLED, NULL);
    gtk_tree_view_column_set_expand(col_toggle, FALSE);
    gtk_tree_view_column_set_min_width(col_toggle, 30);
    gtk_tree_view_append_column(GTK_TREE_VIEW(tree_view), col_toggle);

    /* Icon column */
    GtkCellRenderer *renderer_icon = gtk_cell_renderer_pixbuf_new();
    g_object_set(renderer_icon, "stock-size", GTK_ICON_SIZE_DND, NULL);
    GtkTreeViewColumn *col_icon = gtk_tree_view_column_new_with_attributes("Icon", renderer_icon, "icon-name", COL_ICON, NULL);
    gtk_tree_view_column_set_expand(col_icon, FALSE);
    gtk_tree_view_append_column(GTK_TREE_VIEW(tree_view), col_icon);

    /* Name column */
    GtkCellRenderer *renderer_text = gtk_cell_renderer_text_new();
    GtkTreeViewColumn *col_text = gtk_tree_view_column_new_with_attributes("Name", renderer_text, "text", COL_NAME, NULL);
    gtk_tree_view_column_set_expand(col_text, TRUE);
    gtk_tree_view_append_column(GTK_TREE_VIEW(tree_view), col_text);

    GtkTreeSelection *selection = gtk_tree_view_get_selection(GTK_TREE_VIEW(tree_view));
    g_signal_connect(selection, "changed", G_CALLBACK(on_selection_changed), NULL);

    GtkWidget *scroll_tree = gtk_scrolled_window_new(NULL, NULL);
    gtk_widget_set_vexpand(scroll_tree, TRUE);
    gtk_container_add(GTK_CONTAINER(scroll_tree), tree_view);
    gtk_box_pack_start(GTK_BOX(left_box), scroll_tree, TRUE, TRUE, 0);

    /* Right pane: Editor */
    GtkWidget *right_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_margin_start(right_box, 16);
    gtk_widget_set_margin_end(right_box, 16);
    gtk_widget_set_margin_top(right_box, 16);
    gtk_widget_set_margin_bottom(right_box, 16);
    gtk_paned_pack2(GTK_PANED(paned), right_box, TRUE, FALSE);

    GtkWidget *title = gtk_label_new("<span size='large' weight='bold'>Desktop Entry Editor</span>");
    gtk_label_set_use_markup(GTK_LABEL(title), TRUE);
    gtk_widget_set_halign(title, GTK_ALIGN_START);
    gtk_widget_set_margin_bottom(title, 16);
    gtk_box_pack_start(GTK_BOX(right_box), title, FALSE, FALSE, 0);

    /* Editor fields */
    gtk_box_pack_start(GTK_BOX(right_box), create_editor_row("Name:", &entry_name), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(right_box), create_editor_row("Command:", &entry_exec), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(right_box), create_icon_row(), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(right_box), create_editor_row("Comment:", &entry_comment), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(right_box), create_category_row(), FALSE, FALSE, 0);

    /* Terminal checkbox */
    GtkWidget *term_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    GtkWidget *spacer = gtk_label_new("");
    gtk_widget_set_size_request(spacer, 100, -1);
    gtk_box_pack_start(GTK_BOX(term_box), spacer, FALSE, FALSE, 0);
    check_terminal = gtk_check_button_new_with_label("Run in Terminal");
    gtk_box_pack_start(GTK_BOX(term_box), check_terminal, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(right_box), term_box, FALSE, FALSE, 0);

    /* Buttons */
    GtkWidget *btn_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_margin_bottom(btn_box, 8);
    gtk_box_pack_start(GTK_BOX(right_box), btn_box, FALSE, FALSE, 0);

    GtkWidget *save_btn = gtk_button_new_with_label("Save");
    GtkStyleContext *ctx = gtk_widget_get_style_context(save_btn);
    gtk_style_context_add_class(ctx, "suggested-action");
    g_signal_connect(save_btn, "clicked", G_CALLBACK(on_save_clicked), NULL);
    gtk_box_pack_start(GTK_BOX(btn_box), save_btn, FALSE, FALSE, 0);

    GtkWidget *validate_btn = gtk_button_new_with_label("Validate");
    g_signal_connect(validate_btn, "clicked", G_CALLBACK(on_validate_clicked), NULL);
    gtk_box_pack_start(GTK_BOX(btn_box), validate_btn, FALSE, FALSE, 0);

    GtkWidget *backup_btn = gtk_button_new_with_label("Backup");
    g_signal_connect(backup_btn, "clicked", G_CALLBACK(on_backup_clicked), NULL);
    gtk_box_pack_start(GTK_BOX(btn_box), backup_btn, FALSE, FALSE, 0);

    GtkWidget *restore_btn = gtk_button_new_with_label("Restore");
    g_signal_connect(restore_btn, "clicked", G_CALLBACK(on_restore_clicked), NULL);
    gtk_box_pack_start(GTK_BOX(btn_box), restore_btn, FALSE, FALSE, 0);

    /* File info panel */
    GtkWidget *info_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_margin_bottom(info_box, 4);
    gtk_box_pack_start(GTK_BOX(right_box), info_box, FALSE, FALSE, 0);

    GtkWidget *info_icon = gtk_image_new_from_icon_name("dialog-information-symbolic", GTK_ICON_SIZE_MENU);
    gtk_box_pack_start(GTK_BOX(info_box), info_icon, FALSE, FALSE, 0);

    info_label = gtk_label_new("");
    gtk_label_set_selectable(GTK_LABEL(info_label), TRUE);
    gtk_widget_set_halign(info_label, GTK_ALIGN_START);
    gtk_widget_set_margin_bottom(info_label, 4);
    gtk_box_pack_start(GTK_BOX(info_box), info_label, TRUE, TRUE, 0);

    /* Spacer */
    GtkWidget *expand = gtk_label_new("");
    gtk_widget_set_vexpand(expand, TRUE);
    gtk_box_pack_start(GTK_BOX(right_box), expand, TRUE, TRUE, 0);

    /* Status */
    status_label = gtk_label_new("Ready — toggle checkbox to enable/disable entries");
    gtk_widget_set_halign(status_label, GTK_ALIGN_START);
    gtk_box_pack_start(GTK_BOX(right_box), status_label, FALSE, FALSE, 0);

    load_all_desktop_files();

    gtk_widget_show_all(window);
}

int main(int argc, char **argv) {
    GtkApplication *app = gtk_application_new(APP_ID, G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
    int status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);
    return status;
}

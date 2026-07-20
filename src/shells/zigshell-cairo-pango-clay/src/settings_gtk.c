/*
 * settings_gtk.c — out-of-process GTK3 settings panel for zigshell.
 *
 * Launched on demand from the shell's gear button. Edits the shared INI config
 * file (same format the shell writes) and signals the running shell to reload
 * via SIGHUP. No Wayland / event-loop coupling with the shell.
 *
 * UI parity with the previous in-panel settings:
 *   Widgets tab: list with reorder (up/down), visibility toggle, L/R side,
 *                delete, and an "Add widget" menu over all widget types.
 *   Dock tab:    autohide switch, font-scale +/-, icon size (sm/md/lg),
 *                pinned-app list with unpin buttons.
 */

#define _GNU_SOURCE
#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

/* ---------- config model ---------- */

#define MAX_WIDGETS 64
#define MAX_PINS 256
#define MAX_NAME 64

static const char *ALL_TYPES[] = {
    "workspaces", "toplevel", "launcher", "cpu", "mem", "temp", "disk",
    "battery", "volume", "network", "media", "clock", "power", "spacer",
    "kbindicator", "customcommand", "showdesktop", "worldclock", "backlight",
    "session", "versions"
};
static const int N_TYPES = sizeof(ALL_TYPES) / sizeof(ALL_TYPES[0]);

typedef struct {
    char name[MAX_NAME];
    int side;      /* 0 = left, 1 = right */
    int hidden;    /* 0 = visible, 1 = hidden */
} WidgetCfg;

static double g_font_scale = 1.0;
static int g_autohide = 0;
static int g_icon_size = 28;
static int g_panel_height = 24;
static WidgetCfg g_widgets[MAX_WIDGETS];
static int g_widget_count = 0;
static char *g_pins[MAX_PINS];
static int g_pin_count = 0;

static char g_config_path[1024];

/* ---------- config path ---------- */

static const char *resolve_config_path(void) {
    const char *env = getenv("ZIGSHELL_CONFIG");
    if (env && *env) {
        snprintf(g_config_path, sizeof(g_config_path), "%s", env);
        return g_config_path;
    }
    const char *home = getenv("HOME"); if (!home) home = ".";
    const char *xdg = getenv("XDG_CONFIG_HOME");
    char base[1024];
    if (xdg && *xdg) snprintf(base, sizeof(base), "%s", xdg);
    else snprintf(base, sizeof(base), "%s/.config", home);
    snprintf(g_config_path, sizeof(g_config_path), "%s/zigshell/panel.conf", base);
    return g_config_path;
}

/* ---------- INI parsing ---------- */

static int parse_bool(const char *v) {
    return (strcmp(v, "true") == 0 || strcmp(v, "1") == 0);
}

static void trim(char *s) {
    while (*s && (*s == ' ' || *s == '\t' || *s == '\r' || *s == '\n')) s++;
    if (!*s) return;
    char *e = s + strlen(s) - 1;
    while (e > s && (*e == ' ' || *e == '\t' || *e == '\r' || *e == '\n')) *e-- = 0;
}

static void config_load(void) {
    const char *path = resolve_config_path();
    FILE *f = fopen(path, "r");
    if (!f) return;
    char line[1024];
    char section[128] = "";
    while (fgets(line, sizeof(line), f)) {
        trim(line);
        if (!*line || line[0] == '#') continue;
        if (line[0] == '[') {
            char *end = strchr(line, ']');
            if (end) *end = 0;
            snprintf(section, sizeof(section), "%s", line + 1);
            continue;
        }
        char *eq = strchr(line, '=');
        if (strcmp(section, "panel") == 0 && eq) {
            *eq = 0; trim(line);
            char *v = eq + 1; trim(v);
            if (strcmp(line, "height") == 0) g_panel_height = atoi(v);
            else if (strcmp(line, "font_scale") == 0) g_font_scale = atof(v);
            else if (strcmp(line, "autohide_dock") == 0) g_autohide = parse_bool(v);
        } else if (strcmp(section, "dock") == 0 && eq) {
            *eq = 0; trim(line);
            char *v = eq + 1; trim(v);
            if (strcmp(line, "icon_size") == 0) g_icon_size = atoi(v);
        } else if (strcmp(section, "dock.pins") == 0) {
            if (g_pin_count < MAX_PINS) {
                g_pins[g_pin_count] = strdup(line);
                g_pin_count++;
            }
        } else if (eq) {
            /* widget section */
            if (g_widget_count >= MAX_WIDGETS) continue;
            *eq = 0; trim(line);
            char *v = eq + 1; trim(v);
            if (strcmp(line, "side") == 0) {
                if (g_widget_count > 0)
                    g_widgets[g_widget_count - 1].side = (strcmp(v, "right") == 0) ? 1 : 0;
            } else if (strcmp(line, "hidden") == 0) {
                if (g_widget_count > 0)
                    g_widgets[g_widget_count - 1].hidden = parse_bool(v);
            }
        } else {
            /* a widget section header line with no '=' — treat as new widget */
            if (g_widget_count < MAX_WIDGETS) {
                snprintf(g_widgets[g_widget_count].name, MAX_NAME, "%s", line);
                g_widgets[g_widget_count].side = 0;
                g_widgets[g_widget_count].hidden = 0;
                g_widget_count++;
            }
        }
    }
    fclose(f);
}

static void config_save(void) {
    const char *path = resolve_config_path();
    char dir[1024];
    snprintf(dir, sizeof(dir), "%s", path);
    char *slash = strrchr(dir, '/');
    if (slash) { *slash = 0; mkdir(dir, 0755); }

    FILE *f = fopen(path, "w");
    if (!f) return;
    fprintf(f, "[panel]\n");
    fprintf(f, "height = %d\n", g_panel_height);
    fprintf(f, "font_scale = %.3f\n", g_font_scale);
    fprintf(f, "autohide_dock = %s\n", g_autohide ? "true" : "false");
    fprintf(f, "\n[dock]\n");
    fprintf(f, "icon_size = %d\n", g_icon_size);
    fprintf(f, "\n[dock.pins]\n");
    for (int i = 0; i < g_pin_count; i++) fprintf(f, "%s\n", g_pins[i]);
    fprintf(f, "\n");
    for (int i = 0; i < g_widget_count; i++) {
        fprintf(f, "[%s]\n", g_widgets[i].name);
        if (g_widgets[i].side == 1) fprintf(f, "side = right\n");
        if (g_widgets[i].hidden) fprintf(f, "hidden = true\n");
        fprintf(f, "\n");
    }
    fclose(f);
}

/* ---------- shell reload (SIGHUP) ---------- */

static void signal_shell_reload(void) {
    DIR *d = opendir("/proc");
    if (!d) return;
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (e->d_type != DT_DIR) continue;
        char comm_path[256];
        snprintf(comm_path, sizeof(comm_path), "/proc/%s/comm", e->d_name);
        FILE *cf = fopen(comm_path, "r");
        if (!cf) continue;
        char comm[64];
        if (fgets(comm, sizeof(comm), cf)) {
            comm[strcspn(comm, "\n")] = 0;
            if (strcmp(comm, "zigshell-cairo-pango") == 0 || strcmp(comm, "zigshell") == 0) {
                kill(atoi(e->d_name), SIGHUP);
                fclose(cf);
                closedir(d);
                return;
            }
        }
        fclose(cf);
    }
    closedir(d);
}

static void apply_and_reload(void) {
    config_save();
    signal_shell_reload();
}

static void on_reload_clicked(GtkWidget *btn, gpointer ud) {
    (void)btn; (void)ud;
    apply_and_reload();
}

/* ---------- widgets tab state ---------- */

static GtkWidget *g_list_box = NULL;
static GtkWidget *g_pins_box = NULL;
static GtkWidget *g_font_label = NULL;

static void rebuild_widget_list(void);
static void rebuild_pins(void);

static void on_vis_toggled(GtkToggleButton *btn, gpointer ud) {
    int idx = GPOINTER_TO_INT(ud);
    if (idx < 0 || idx >= g_widget_count) return;
    g_widgets[idx].hidden = gtk_toggle_button_get_active(btn) ? 0 : 1;
    apply_and_reload();
}
static void on_side_changed(GtkComboBox *cb, gpointer ud) {
    int idx = GPOINTER_TO_INT(ud);
    if (idx < 0 || idx >= g_widget_count) return;
    g_widgets[idx].side = gtk_combo_box_get_active(cb) == 1 ? 1 : 0;
    apply_and_reload();
}
static void on_delete(GtkButton *b, gpointer ud) {
    int idx = GPOINTER_TO_INT(ud);
    if (idx < 0 || idx >= g_widget_count) return;
    for (int i = idx; i + 1 < g_widget_count; i++)
        g_widgets[i] = g_widgets[i + 1];
    g_widget_count--;
    apply_and_reload();
    rebuild_widget_list();
}
static void on_move(GtkButton *b, gpointer ud) {
    int idx = GPOINTER_TO_INT(ud) >> 1;
    int dir = (GPOINTER_TO_INT(ud) & 1) ? 1 : -1;
    int j = idx + dir;
    if (idx < 0 || idx >= g_widget_count) return;
    if (j < 0 || j >= g_widget_count) return;
    WidgetCfg t = g_widgets[idx];
    g_widgets[idx] = g_widgets[j];
    g_widgets[j] = t;
    apply_and_reload();
    rebuild_widget_list();
}

static void rebuild_widget_list(void) {
    GList *children = gtk_container_get_children(GTK_CONTAINER(g_list_box));
    for (GList *c = children; c; c = c->next)
        gtk_container_remove(GTK_CONTAINER(g_list_box), GTK_WIDGET(c->data));
    g_list_free(children);

    for (int i = 0; i < g_widget_count; i++) {
        GtkWidget *row = gtk_list_box_row_new();
        GtkWidget *hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
        gtk_widget_set_margin_start(hbox, 8);
        gtk_widget_set_margin_end(hbox, 8);

        GtkWidget *label = gtk_label_new(g_widgets[i].name);
        gtk_widget_set_halign(label, GTK_ALIGN_START);
        gtk_box_pack_start(GTK_BOX(hbox), label, TRUE, TRUE, 0);

        GtkWidget *vis = gtk_check_button_new();
        gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(vis), !g_widgets[i].hidden);
        gtk_widget_set_tooltip_text(vis, "Visible");
        g_signal_connect(vis, "toggled", G_CALLBACK(on_vis_toggled), GINT_TO_POINTER(i));
        gtk_box_pack_end(GTK_BOX(hbox), vis, FALSE, FALSE, 0);

        GtkWidget *side = gtk_combo_box_text_new();
        gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(side), "Left");
        gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(side), "Right");
        gtk_combo_box_set_active(GTK_COMBO_BOX(side), g_widgets[i].side == 1 ? 1 : 0);
        g_signal_connect(side, "changed", G_CALLBACK(on_side_changed), GINT_TO_POINTER(i));
        gtk_box_pack_end(GTK_BOX(hbox), side, FALSE, FALSE, 0);

        GtkWidget *up = gtk_button_new_with_label("↑");
        g_signal_connect(up, "clicked", G_CALLBACK(on_move), GINT_TO_POINTER((i << 1) | 0));
        gtk_box_pack_end(GTK_BOX(hbox), up, FALSE, FALSE, 0);
        GtkWidget *down = gtk_button_new_with_label("↓");
        g_signal_connect(down, "clicked", G_CALLBACK(on_move), GINT_TO_POINTER((i << 1) | 1));
        gtk_box_pack_end(GTK_BOX(hbox), down, FALSE, FALSE, 0);

        GtkWidget *del = gtk_button_new_with_label("✕");
        gtk_widget_set_tooltip_text(del, "Remove");
        g_signal_connect(del, "clicked", G_CALLBACK(on_delete), GINT_TO_POINTER(i));
        gtk_box_pack_end(GTK_BOX(hbox), del, FALSE, FALSE, 0);

        gtk_container_add(GTK_CONTAINER(row), hbox);
        gtk_list_box_insert(GTK_LIST_BOX(g_list_box), row, -1);
    }
    gtk_widget_show_all(g_list_box);
}

static void on_add_btn_clicked(GtkButton *btn, gpointer user_data) {
    GtkWidget *menu = GTK_WIDGET(user_data);
    gtk_menu_popup_at_widget(GTK_MENU(menu), GTK_WIDGET(btn), GDK_GRAVITY_SOUTH_WEST, GDK_GRAVITY_NORTH_WEST, NULL);
}

static void on_add_type(GtkMenuItem *item, gpointer ud) {
    int t = GPOINTER_TO_INT(ud);
    if (g_widget_count >= MAX_WIDGETS) return;
    snprintf(g_widgets[g_widget_count].name, MAX_NAME, "%s", ALL_TYPES[t]);
    g_widgets[g_widget_count].side = 1;
    g_widgets[g_widget_count].hidden = 0;
    g_widget_count++;
    apply_and_reload();
    rebuild_widget_list();
}

/* ---------- dock tab state ---------- */

static void on_autohide(GtkSwitch *sw, gpointer ud) {
    (void)ud;
    g_autohide = gtk_switch_get_active(sw) ? 1 : 0;
    apply_and_reload();
}
static void on_font_down(GtkButton *b, gpointer ud) {
    (void)b; (void)ud;
    g_font_scale -= 0.1; if (g_font_scale < 0.6) g_font_scale = 0.6;
    char buf[32]; snprintf(buf, sizeof(buf), "%.2fx", g_font_scale);
    gtk_label_set_text(GTK_LABEL(g_font_label), buf);
    apply_and_reload();
}
static void on_font_up(GtkButton *b, gpointer ud) {
    (void)b; (void)ud;
    g_font_scale += 0.1; if (g_font_scale > 2.5) g_font_scale = 2.5;
    char buf[32]; snprintf(buf, sizeof(buf), "%.2fx", g_font_scale);
    gtk_label_set_text(GTK_LABEL(g_font_label), buf);
    apply_and_reload();
}
static void on_icon_size(GtkComboBox *cb, gpointer ud) {
    (void)ud;
    int sz = gtk_combo_box_get_active(cb);
    int sizes[] = {22, 28, 36};
    if (sz >= 0 && sz < 3) { g_icon_size = sizes[sz]; apply_and_reload(); }
}
static void on_unpin(GtkButton *b, gpointer ud) {
    int idx = GPOINTER_TO_INT(ud);
    if (idx < 0 || idx >= g_pin_count) return;
    free(g_pins[idx]);
    for (int i = idx; i + 1 < g_pin_count; i++) g_pins[i] = g_pins[i + 1];
    g_pin_count--;
    apply_and_reload();
    rebuild_pins();
}

static void rebuild_pins(void) {
    GList *children = gtk_container_get_children(GTK_CONTAINER(g_pins_box));
    for (GList *c = children; c; c = c->next)
        gtk_container_remove(GTK_CONTAINER(g_pins_box), GTK_WIDGET(c->data));
    g_list_free(children);
    for (int i = 0; i < g_pin_count; i++) {
        GtkWidget *hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
        GtkWidget *label = gtk_label_new(g_pins[i]);
        gtk_widget_set_halign(label, GTK_ALIGN_START);
        gtk_box_pack_start(GTK_BOX(hbox), label, TRUE, TRUE, 0);
        GtkWidget *unpin = gtk_button_new_with_label("Unpin");
        g_signal_connect(unpin, "clicked", G_CALLBACK(on_unpin), GINT_TO_POINTER(i));
        gtk_box_pack_end(GTK_BOX(hbox), unpin, FALSE, FALSE, 0);
        gtk_container_add(GTK_CONTAINER(g_pins_box), hbox);
    }
    gtk_widget_show_all(g_pins_box);
}

/* ---------- main ---------- */

int gtk_settings_main(int argc, char **argv) {
    gtk_init(&argc, &argv);
    config_load();

    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "Zigshell Settings");
    gtk_window_set_default_size(GTK_WINDOW(window), 460, 560);
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);

    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_container_add(GTK_CONTAINER(window), vbox);
    gtk_widget_set_margin_start(vbox, 10);
    gtk_widget_set_margin_end(vbox, 10);
    gtk_widget_set_margin_top(vbox, 10);
    gtk_widget_set_margin_bottom(vbox, 10);

    GtkWidget *notebook = gtk_notebook_new();
    gtk_box_pack_start(GTK_BOX(vbox), notebook, TRUE, TRUE, 0);

    /* Widgets tab */
    GtkWidget *widgets_page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    GtkWidget *scrolled = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolled),
        GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
    gtk_box_pack_start(GTK_BOX(widgets_page), scrolled, TRUE, TRUE, 0);

    g_list_box = gtk_list_box_new();
    gtk_list_box_set_selection_mode(GTK_LIST_BOX(g_list_box), GTK_SELECTION_NONE);
    gtk_container_add(GTK_CONTAINER(scrolled), g_list_box);

    GtkWidget *add_btn = gtk_button_new_with_label("+ Add widget");
    gtk_box_pack_start(GTK_BOX(widgets_page), add_btn, FALSE, FALSE, 0);

    GtkWidget *menu = gtk_menu_new();
    for (int t = 0; t < N_TYPES; t++) {
        GtkWidget *mi = gtk_menu_item_new_with_label(ALL_TYPES[t]);
        g_signal_connect(mi, "activate", G_CALLBACK(on_add_type), GINT_TO_POINTER(t));
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), mi);
    }
    gtk_widget_show_all(menu);
    g_signal_connect(add_btn, "clicked", G_CALLBACK(on_add_btn_clicked), menu);

    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), widgets_page,
        gtk_label_new("Widgets"));

    /* Dock tab */
    GtkWidget *dock_page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_widget_set_margin_start(dock_page, 8);
    gtk_widget_set_margin_end(dock_page, 8);

    GtkWidget *ah_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    GtkWidget *ah_label = gtk_label_new("Auto-hide dock");
    gtk_widget_set_halign(ah_label, GTK_ALIGN_START);
    gtk_box_pack_start(GTK_BOX(ah_box), ah_label, TRUE, TRUE, 0);
    GtkWidget *ah_switch = gtk_switch_new();
    gtk_switch_set_active(GTK_SWITCH(ah_switch), g_autohide ? TRUE : FALSE);
    g_signal_connect(ah_switch, "notify::active", G_CALLBACK(on_autohide), NULL);
    gtk_box_pack_end(GTK_BOX(ah_box), ah_switch, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(dock_page), ah_box, FALSE, FALSE, 0);

    GtkWidget *fs_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    GtkWidget *fs_label = gtk_label_new("Font scale");
    gtk_widget_set_halign(fs_label, GTK_ALIGN_START);
    gtk_box_pack_start(GTK_BOX(fs_box), fs_label, TRUE, TRUE, 0);
    GtkWidget *fs_down = gtk_button_new_with_label("−");
    g_signal_connect(fs_down, "clicked", G_CALLBACK(on_font_down), NULL);
    char fbuf[32]; snprintf(fbuf, sizeof(fbuf), "%.2fx", g_font_scale);
    g_font_label = gtk_label_new(fbuf);
    GtkWidget *fs_up = gtk_button_new_with_label("+");
    g_signal_connect(fs_up, "clicked", G_CALLBACK(on_font_up), NULL);
    gtk_box_pack_end(GTK_BOX(fs_box), fs_up, FALSE, FALSE, 0);
    gtk_box_pack_end(GTK_BOX(fs_box), g_font_label, FALSE, FALSE, 0);
    gtk_box_pack_end(GTK_BOX(fs_box), fs_down, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(dock_page), fs_box, FALSE, FALSE, 0);

    GtkWidget *is_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    GtkWidget *is_label = gtk_label_new("Dock icon size");
    gtk_widget_set_halign(is_label, GTK_ALIGN_START);
    gtk_box_pack_start(GTK_BOX(is_box), is_label, TRUE, TRUE, 0);
    GtkWidget *is_combo = gtk_combo_box_text_new();
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(is_combo), "Small");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(is_combo), "Medium");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(is_combo), "Large");
    gtk_combo_box_set_active(GTK_COMBO_BOX(is_combo),
        g_icon_size == 22 ? 0 : (g_icon_size == 36 ? 2 : 1));
    g_signal_connect(is_combo, "changed", G_CALLBACK(on_icon_size), NULL);
    gtk_box_pack_end(GTK_BOX(is_box), is_combo, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(dock_page), is_box, FALSE, FALSE, 0);

    GtkWidget *pins_label = gtk_label_new("Pinned applications");
    gtk_widget_set_halign(pins_label, GTK_ALIGN_START);
    gtk_box_pack_start(GTK_BOX(dock_page), pins_label, FALSE, FALSE, 0);
    GtkWidget *pins_scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(pins_scroll),
        GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
    gtk_box_pack_start(GTK_BOX(dock_page), pins_scroll, TRUE, TRUE, 0);
    g_pins_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
    gtk_container_add(GTK_CONTAINER(pins_scroll), g_pins_box);

    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), dock_page,
        gtk_label_new("Dock"));

    /* Apply / Reload button — write config and signal the shell to reload. */
    GtkWidget *reload_btn = gtk_button_new_with_label("Reload / Apply");
    gtk_widget_set_margin_top(reload_btn, 6);
    g_signal_connect(reload_btn, "clicked", G_CALLBACK(on_reload_clicked), NULL);
    gtk_box_pack_start(GTK_BOX(vbox), reload_btn, FALSE, FALSE, 0);

    rebuild_widget_list();
    rebuild_pins();

    gtk_widget_show_all(window);
    gtk_main();
    return 0;
}

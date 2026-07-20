/*
 * settings-tabs.h — Tab Builder Functions
 * Each tab builds a complete page for the settings panel.
 */

#ifndef SETTINGS_TABS_H
#define SETTINGS_TABS_H

#include <gtk/gtk.h>

GtkWidget* build_shell_tab(void);
GtkWidget* build_appearance_tab(void);
GtkWidget* build_bar_config_tab(void);
GtkWidget* build_widgets_tab(void);
GtkWidget* build_workspaces_tab(void);
GtkWidget* build_notifications_tab(void);
GtkWidget* build_diagnostics_tab(void);
GtkWidget* build_quick_settings_tab(void);
GtkWidget* build_keybinds_tab(void);
GtkWidget* build_credits_tab(void);
GtkWidget* build_about_tab(void);
GtkWidget* build_apps_tab(void);

#endif /* SETTINGS_TABS_H */

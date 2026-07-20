#include <gtk/gtk.h>
#include <stdio.h>

static GtkWidget* make_tooltip_row(const char *title, const char *subtitle, const char *tooltip) {
    GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_margin_bottom(row, 8);
    
    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
    
    GtkWidget *lbl = gtk_label_new(NULL);
    char *m = g_strdup_printf("<b>%s</b>", title);
    gtk_label_set_markup(GTK_LABEL(lbl), m);
    gtk_label_set_xalign(GTK_LABEL(lbl), 0.0);
    g_free(m);
    
    GtkWidget *sub = gtk_label_new(subtitle);
    gtk_label_set_xalign(GTK_LABEL(sub), 0.0);
    gtk_style_context_add_class(gtk_widget_get_style_context(sub), "dim-label");
    
    GtkWidget *tip = gtk_label_new(NULL);
    gtk_label_set_markup(GTK_LABEL(tip), tooltip);
    gtk_label_set_xalign(GTK_LABEL(tip), 0.0);
    gtk_style_context_add_class(gtk_widget_get_style_context(tip), "dim-label");
    
    gtk_box_pack_start(GTK_BOX(vbox), lbl, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(vbox), sub, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(vbox), tip, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(row), vbox, TRUE, TRUE, 0);
    
    return row;
}

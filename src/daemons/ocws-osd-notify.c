#include <gtk/gtk.h>
#include <gtk-layer-shell/gtk-layer-shell.h>
#include <gio/gio.h>

static void show_notification(const gchar *summary, const gchar *body) {
    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    
    gtk_layer_init_for_window(GTK_WINDOW(window));
    gtk_layer_set_layer(GTK_WINDOW(window), GTK_LAYER_SHELL_LAYER_OVERLAY);
    gtk_layer_set_anchor(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_TOP, TRUE);
    gtk_layer_set_anchor(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
    gtk_layer_set_margin(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_TOP, 20);
    gtk_layer_set_margin(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_RIGHT, 20);

    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5);
    gtk_widget_set_margin_top(box, 15);
    gtk_widget_set_margin_bottom(box, 15);
    gtk_widget_set_margin_start(box, 20);
    gtk_widget_set_margin_end(box, 20);
    
    // Glassmorphism styling will be applied via CSS in the future
    
    GtkWidget *lbl_summary = gtk_label_new(summary);
    PangoAttrList *attrs = pango_attr_list_new();
    pango_attr_list_insert(attrs, pango_attr_weight_new(PANGO_WEIGHT_BOLD));
    gtk_label_set_attributes(GTK_LABEL(lbl_summary), attrs);
    pango_attr_list_unref(attrs);
    
    GtkWidget *lbl_body = gtk_label_new(body);
    
    gtk_box_pack_start(GTK_BOX(box), lbl_summary, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), lbl_body, FALSE, FALSE, 0);
    
    gtk_container_add(GTK_CONTAINER(window), box);
    gtk_widget_show_all(window);
    
    // Auto-close after 3 seconds
    g_timeout_add_seconds(3, (GSourceFunc)(gtk_widget_destroy + 0), window);
}

static void handle_method_call(GDBusConnection *connection, const gchar *sender,
                               const gchar *object_path, const gchar *interface_name,
                               const gchar *method_name, GVariant *parameters,
                               GDBusMethodInvocation *invocation, gpointer user_data) {
    if (g_strcmp0(method_name, "Notify") == 0) {
        gchar *app_name, *summary, *body, *icon;
        guint32 replaces_id, expire_timeout;
        GVariant *actions, *hints;
        
        g_variant_get(parameters, "(susss@as@a{sv}i)", 
                      &app_name, &replaces_id, &icon, &summary, &body, 
                      &actions, &hints, &expire_timeout);
                      
        show_notification(summary, body);
        
        g_free(app_name); g_free(summary); g_free(body); g_free(icon);
        g_variant_unref(actions); g_variant_unref(hints);
        
        g_dbus_method_invocation_return_value(invocation, g_variant_new("(u)", 1));
    } else if (g_strcmp0(method_name, "GetCapabilities") == 0) {
        GVariantBuilder *b = g_variant_builder_new(G_VARIANT_TYPE_ARRAY);
        g_variant_builder_add(b, "s", "body");
        g_dbus_method_invocation_return_value(invocation, g_variant_new("(as)", b));
        g_variant_builder_unref(b);
    } else if (g_strcmp0(method_name, "GetServerInformation") == 0) {
        g_dbus_method_invocation_return_value(invocation,
            g_variant_new("(ssss)", "ocws-osd-notify", "OCWS", "1.0", "1.0"));
    } else if (g_strcmp0(method_name, "CloseNotification") == 0) {
        g_dbus_method_invocation_return_value(invocation, NULL);
    }
}

static const GDBusInterfaceVTable interface_vtable = {
    handle_method_call, NULL, NULL, { 0 }
};

static void on_bus_acquired(GDBusConnection *connection, const gchar *name, gpointer user_data) {
    GDBusNodeInfo *introspection_data = g_dbus_node_info_new_for_xml(
        "<node>"
        "  <interface name='org.freedesktop.Notifications'>"
        "    <method name='Notify'>"
        "      <arg type='s' name='app_name' direction='in'/>"
        "      <arg type='u' name='replaces_id' direction='in'/>"
        "      <arg type='s' name='app_icon' direction='in'/>"
        "      <arg type='s' name='summary' direction='in'/>"
        "      <arg type='s' name='body' direction='in'/>"
        "      <arg type='as' name='actions' direction='in'/>"
        "      <arg type='a{sv}' name='hints' direction='in'/>"
        "      <arg type='i' name='expire_timeout' direction='in'/>"
        "      <arg type='u' name='id' direction='out'/>"
        "    </method>"
        "  </interface>"
        "</node>", NULL);
        
    g_dbus_connection_register_object(connection, "/org/freedesktop/Notifications",
        introspection_data->interfaces[0], &interface_vtable, NULL, NULL, NULL);
    g_dbus_node_info_unref(introspection_data);
}

int main(int argc, char **argv) {
    gtk_init(&argc, &argv);
    
    g_bus_own_name(G_BUS_TYPE_SESSION, "org.freedesktop.Notifications",
                   G_BUS_NAME_OWNER_FLAGS_REPLACE,
                   on_bus_acquired, NULL, NULL, NULL, NULL);
                   
    gtk_main();
    return 0;
}

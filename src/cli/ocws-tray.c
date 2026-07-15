/*
 * ocws-tray — system-tray controller for OCWS background processes.
 *
 * Registers a set of managed background processes via ocws_proc (libocws/proc.h)
 * and shows them in a tray icon (zserge/tray, sources/zsergey-tray/tray-master).
 * Each menu entry toggles its process; a Quit entry stops everything and exits.
 *
 * Build (see build.zig): links gtk+-3.0, glib-2.0, ayatana-appindicator3-0.1
 * and compiles tray.h with -DTRAY_APPINDICATOR.
 */

#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../libocws/proc.h"

#define TRAY_APPINDICATOR
#include "tray.h"

static struct tray tray;
static struct tray_menu menu[OCWS_PROC_MAX + 3];      /* procs + sep + quit + terminator */
static char labels[OCWS_PROC_MAX][96];                /* live label buffers */

static void toggle_cb(struct tray_menu *m) {
    ocws_proc_t *p = (ocws_proc_t *)m->context;
    if (ocws_proc_refresh(p) && p->running) ocws_proc_stop(p);
    else ocws_proc_start(p);
    snprintf(labels[m - menu], sizeof(labels[0]), "%-18s [%s]",
             p->name, ocws_proc_refresh(p) ? "running" : "stopped");
    tray_update(&tray);
}

static void quit_cb(struct tray_menu *m) {
    (void)m;
    for (int i = 0; i < ocws_procs_count; i++) ocws_proc_stop(&ocws_procs[i]);
    tray_exit();
}

static void rebuild_menu(void) {
    int idx = 0;
    for (int i = 0; i < ocws_procs_count; i++) {
        ocws_proc_t *p = &ocws_procs[i];
        ocws_proc_refresh(p);
        snprintf(labels[idx], sizeof(labels[idx]), "%-18s [%s]",
                 p->name, p->running ? "running" : "stopped");
        menu[idx].text = labels[idx];
        menu[idx].disabled = 0;
        menu[idx].checked = 0;
        menu[idx].cb = toggle_cb;
        menu[idx].context = p;
        menu[idx].submenu = NULL;
        idx++;
    }
    menu[idx].text = "-";          /* separator */
    menu[idx].cb = NULL;
    menu[idx].context = NULL;
    menu[idx].submenu = NULL;
    idx++;
    menu[idx].text = "Quit";
    menu[idx].disabled = 0;
    menu[idx].checked = 0;
    menu[idx].cb = quit_cb;
    menu[idx].context = NULL;
    menu[idx].submenu = NULL;
    idx++;
    menu[idx].text = NULL;         /* terminator */
    tray.menu = menu;
}

int main(void) {
    /* Register the background processes this session manages. */
    ocws_proc_add("Equalizer",  "ocws-equalizer &");
    ocws_proc_add("Dock",       "zigshell-cairo-pango &");
    ocws_proc_add("Idleness",   "swayidle &");

    tray.icon = "audio-volume-high";
    rebuild_menu();

    if (tray_init(&tray) < 0) {
        fprintf(stderr, "ocws-tray: failed to init tray (no display?)\n");
        return 1;
    }

    /* Periodically refresh liveness so labels stay accurate. */
    while (tray_loop(1) == 0) {
        static int ticks = 0;
        if ((++ticks % 30) == 0) { /* ~ every 30 iterations */
            rebuild_menu();
            tray_update(&tray);
        }
    }
    return 0;
}

#ifndef OCWS_THEME_CSS_H
#define OCWS_THEME_CSS_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/*
 * theme_css.h — Shared CSS theme color loader.
 *
 * Parses ~/.config/ocws/css/theme.css for GTK-style @define-color entries
 * used by GL widgets (waveform, equalizer, speaker) to adapt to the
 * active OCWS theme.
 *
 * Usage:
 *   OcwsThemeColors tc = {0};
 *   ocws_load_theme_colors(&tc);
 *   // tc.accent_r, tc.accent_g, tc.accent_b  — accent color (0.0-1.0)
 *   // tc.bg_r, tc.bg_g, tc.bg_b, tc.bg_a    — background color + alpha
 */

typedef struct {
    /* Accent color from @define-color accent #RRGGBB */
    float accent_r, accent_g, accent_b;
    /* Background color from @define-color theme_bg_color #RRGGBB */
    float bg_r, bg_g, bg_b;
    /* Widget alpha from @define-color widget_alpha N.N */
    float bg_a;
} OcwsThemeColors;

/* Load theme colors from ~/.config/ocws/css/theme.css.
 * Fills defaults (blue accent, dark background) if file is missing or
 * any color is not defined. */
static inline void ocws_load_theme_colors(OcwsThemeColors *out) {
    /* Defaults: blue accent on dark background */
    out->accent_r = 0.20f;
    out->accent_g = 0.60f;
    out->accent_b = 0.86f;
    out->bg_r = 0.10f;
    out->bg_g = 0.10f;
    out->bg_b = 0.14f;
    out->bg_a = 0.85f;

    const char *home = getenv("HOME");
    if (!home || !*home) return;

    char path[512];
    snprintf(path, sizeof(path), "%s/.config/ocws/css/theme.css", home);

    FILE *f = fopen(path, "r");
    if (!f) return;

    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);

    if (sz <= 0 || sz > 1024 * 1024) { fclose(f); return; }

    char *content = (char *)malloc((size_t)sz + 1);
    if (!content) { fclose(f); return; }
    fread(content, 1, (size_t)sz, f);
    content[sz] = '\0';
    fclose(f);

    /* Extract accent color: @define-color accent #RRGGBB */
    char *ptr = strstr(content, "@define-color accent #");
    if (ptr) {
        ptr += 22;
        int r_int = 0, g_int = 0, b_int = 0;
        if (sscanf(ptr, "%02x%02x%02x", &r_int, &g_int, &b_int) == 3) {
            out->accent_r = r_int / 255.0f;
            out->accent_g = g_int / 255.0f;
            out->accent_b = b_int / 255.0f;
        }
    }

    /* Extract background color: @define-color theme_bg_color #RRGGBB */
    char *bg_ptr = strstr(content, "@define-color theme_bg_color #");
    if (bg_ptr) {
        bg_ptr += 30;
        int br = 0, bg = 0, bb = 0;
        if (sscanf(bg_ptr, "%02x%02x%02x", &br, &bg, &bb) == 3) {
            out->bg_r = br / 255.0f;
            out->bg_g = bg / 255.0f;
            out->bg_b = bb / 255.0f;
        }
    }

    /* Extract widget alpha: @define-color widget_alpha N.N */
    char *alpha_ptr = strstr(content, "@define-color widget_alpha ");
    if (alpha_ptr) {
        alpha_ptr += 27;
        float alpha_val = 0.85f;
        if (sscanf(alpha_ptr, "%f", &alpha_val) == 1) {
            out->bg_a = alpha_val;
        }
    }

    free(content);
}

#endif

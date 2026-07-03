/* render/font.c - Font loading and management */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fontconfig/fontconfig.h>
#include <pango/pangocairo.h>
#include "widget.h"

/* Nerd Font codepoints for common icons */
typedef struct {
    const char *name;
    const char *icon;
} nerd_icon_t;

static const nerd_icon_t nerd_icons[] = {
    /* CPU */
    {"cpu", "\uf4bc"},           /* nf-fae-chip */
    {"cpu-alt", "\uf2db"},       /* nf-fa-microchip */

    /* Memory */
    {"memory", "\uf538"},        /* nf-fae-chip */
    {"memory-alt", "\uf233"},    /* nf-fa-server */

    /* Network */
    {"wifi-4", "\uf5eb"},        /* nf-md-wifi_strength_4 */
    {"wifi-3", "\uf5ec"},        /* nf-md-wifi_strength_3 */
    {"wifi-2", "\uf5ed"},        /* nf-md-wifi_strength_2 */
    {"wifi-1", "\uf5ee"},        /* nf-md-wifi_strength_1 */
    {"wifi-0", "\uf5ef"},        /* nf-md-wifi_strength_outline */
    {"wifi-off", "\uf5f0"},      /* nf-md-wifi_strength_off_outline */
    {"ethernet", "\uf796"},      /* nf-md-ethernet_cable */

    /* Battery */
    {"battery-4", "\uf240"},     /* nf-fa-battery_4 */
    {"battery-3", "\uf241"},     /* nf-fa-battery_3 */
    {"battery-2", "\uf242"},     /* nf-fa-battery_2 */
    {"battery-1", "\uf243"},     /* nf-fa-battery_1 */
    {"battery-0", "\uf244"},     /* nf-fa-battery_0 */
    {"battery-charging", "\uf0e7"}, /* nf-fa-bolt */

    /* Volume */
    {"volume-high", "\uf028"},   /* nf-fa-volume_up */
    {"volume-medium", "\uf027"}, /* nf-fa-volume_down */
    {"volume-low", "\uf6a8"},    /* nf-fa-volume_off */
    {"volume-mute", "\uf6a9"},   /* nf-fa-volume_off */
    {"volume-off", "\uf026"},    /* nf-fa-volume_off */

    /* Weather */
    {"sunny", "\uf185"},         /* nf-fa-sun_o */
    {"cloudy", "\uf0c2"},        /* nf-fa-cloud */
    {"rain", "\uf0d9"},          /* nf-fa-tint */
    {"snow", "\uf2dc"},          /* nf-fa-snowflake_o */
    {"storm", "\uf0e7"},         /* nf-fa-bolt */

    /* Media */
    {"music", "\uf001"},         /* nf-fa-music */
    {"play", "\uf04b"},          /* nf-fa-play */
    {"pause", "\uf04c"},         /* nf-fa-pause */
    {"stop", "\uf04d"},          /* nf-fa-stop */

    /* System */
    {"power", "\uf011"},         /* nf-fa-power_off */
    {"settings", "\uf013"},      /* nf-fa-cog */
    {"terminal", "\uf120"},      /* nf-fa-terminal */

    {NULL, NULL}
};

/* Find nerd icon by name */
const char *nerd_find_icon(const char *name) {
    if (!name) return NULL;

    for (int i = 0; nerd_icons[i].name != NULL; i++) {
        if (strcmp(nerd_icons[i].name, name) == 0) {
            return nerd_icons[i].icon;
        }
    }

    return NULL;
}

/* Find font path using fontconfig */
char *font_find(const char *family, int *index) {
    if (!family) return NULL;

    FcInit();

    FcPattern *pattern = FcPatternCreate();
    FcPatternAddString(pattern, FC_FAMILY, (const FcChar8 *)family);

    FcConfigSubstitute(NULL, pattern, FcMatchPattern);
    FcDefaultSubstitute(pattern);

    FcResult result;
    FcPattern *match = FcFontMatch(NULL, pattern, &result);

    char *path = NULL;
    if (match) {
        FcChar8 *file = NULL;
        if (FcPatternGetString(match, FC_FILE, 0, &file) == FcResultMatch) {
            path = strdup((const char *)file);
        }
        if (index) {
            int idx = 0;
            FcPatternGetInteger(match, FC_INDEX, 0, &idx);
            *index = idx;
        }
        FcPatternDestroy(match);
    }

    FcPatternDestroy(pattern);

    return path;
}

/* Check if Nerd Font is available */
bool nerd_font_available(void) {
    char *path = font_find("JetBrainsMono Nerd Font", NULL);
    if (path) {
        free(path);
        return true;
    }

    path = font_find("FiraCode Nerd Font", NULL);
    if (path) {
        free(path);
        return true;
    }

    path = font_find("Cascadia Code Nerd Font", NULL);
    if (path) {
        free(path);
        return true;
    }

    return false;
}

/* Get system monospace font */
const char *font_get_system_mono(void) {
    static char font_name[128] = "";

    if (font_name[0] == '\0') {
        /* Try common monospace fonts */
        const char *candidates[] = {
            "JetBrains Mono",
            "Fira Code",
            "Cascadia Code",
            "SF Mono",
            "Monospace",
            NULL
        };

        for (int i = 0; candidates[i] != NULL; i++) {
            char *path = font_find(candidates[i], NULL);
            if (path) {
                snprintf(font_name, sizeof(font_name), "%s", candidates[i]);
                free(path);
                return font_name;
            }
        }

        /* Fallback */
        snprintf(font_name, sizeof(font_name), "Monospace");
    }

    return font_name;
}

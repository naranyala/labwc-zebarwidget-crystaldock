#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <limits.h>
#include <cairo/cairo.h>

#define MAX_COLORS 32
#define MAX_BUCKETS 64
#define SAMPLE_STRIDE 4

typedef struct {
    unsigned char r, g, b;
    int count;
} ColorEntry;

typedef struct {
    int r_min, r_max, g_min, g_max, b_min, b_max;
    int total;
    long r_sum, g_sum, b_sum;
    ColorEntry *pixels;
    int npixels;
} Bucket;

static int cmp_r(const void *a, const void *b) {
    return ((const ColorEntry *)a)->r - ((const ColorEntry *)b)->r;
}
static int cmp_g(const void *a, const void *b) {
    return ((const ColorEntry *)a)->g - ((const ColorEntry *)b)->g;
}
static int cmp_b(const void *a, const void *b) {
    return ((const ColorEntry *)a)->b - ((const ColorEntry *)b)->b;
}

static void bucket_stats(Bucket *b) {
    b->r_min = b->g_min = b->b_min = 255;
    b->r_max = b->g_max = b->b_max = 0;
    b->total = 0;
    b->r_sum = b->g_sum = b->b_sum = 0;
    for (int i = 0; i < b->npixels; i++) {
        ColorEntry *p = &b->pixels[i];
        int cnt = p->count;
        if (p->r < b->r_min) b->r_min = p->r;
        if (p->r > b->r_max) b->r_max = p->r;
        if (p->g < b->g_min) b->g_min = p->g;
        if (p->g > b->g_max) b->g_max = p->g;
        if (p->b < b->b_min) b->b_min = p->b;
        if (p->b > b->b_max) b->b_max = p->b;
        b->total += cnt;
        b->r_sum += (long)p->r * cnt;
        b->g_sum += (long)p->g * cnt;
        b->b_sum += (long)p->b * cnt;
    }
}

static int bucket_range(Bucket *b) {
    int r = b->r_max - b->r_min;
    int g = b->g_max - b->g_min;
    int bl = b->b_max - b->b_min;
    if (r >= g && r >= bl) return r;
    if (g >= r && g >= bl) return g;
    return bl;
}

static int median_cut(Bucket buckets[], int nbuckets, int target) {
    while (nbuckets < target && nbuckets < MAX_BUCKETS) {
        int best_idx = -1, best_range = -1;
        for (int i = 0; i < nbuckets; i++) {
            if (buckets[i].npixels < 2) continue;
            int range = bucket_range(&buckets[i]);
            if (range > best_range) {
                best_range = range;
                best_idx = i;
            }
        }
        if (best_idx < 0) break;

        Bucket src = buckets[best_idx];
        int range_r = src.r_max - src.r_min;
        int range_g = src.g_max - src.g_min;
        int range_b = src.b_max - src.b_min;

        if (range_r >= range_g && range_r >= range_b)
            qsort(src.pixels, src.npixels, sizeof(ColorEntry), cmp_r);
        else if (range_g >= range_r && range_g >= range_b)
            qsort(src.pixels, src.npixels, sizeof(ColorEntry), cmp_g);
        else
            qsort(src.pixels, src.npixels, sizeof(ColorEntry), cmp_b);

        int mid = src.npixels / 2;

        Bucket left = {0};
        left.pixels = src.pixels;
        left.npixels = mid;
        bucket_stats(&left);

        Bucket right = {0};
        right.pixels = src.pixels + mid;
        right.npixels = src.npixels - mid;
        bucket_stats(&right);

        buckets[best_idx] = left;
        if (nbuckets < MAX_BUCKETS)
            buckets[nbuckets++] = right;
    }
    return nbuckets;
}

typedef struct {
    int r, g, b;
    int weight;
} DominantColor;

static int cmp_weight_desc(const void *a, const void *b) {
    return ((const DominantColor *)b)->weight - ((const DominantColor *)a)->weight;
}

static int extract_colors(cairo_surface_t *surface, int ncolors, DominantColor *out) {
    int w = cairo_image_surface_get_width(surface);
    int h = cairo_image_surface_get_height(surface);
    if (w <= 0 || h <= 0 || w > INT_MAX / h) {
        fprintf(stderr, "Invalid image dimensions\n");
        return 0;
    }
    size_t total = (size_t)w * h;
    unsigned char *data = cairo_image_surface_get_data(surface);
    int stride = cairo_image_surface_get_stride(surface);

    ColorEntry *entries = malloc(sizeof(ColorEntry) * (total / SAMPLE_STRIDE + 1));
    int nentries = 0;

    for (int y = 0; y < h; y += SAMPLE_STRIDE) {
        for (int x = 0; x < w; x += SAMPLE_STRIDE) {
            unsigned char *px = data + y * stride + x * 4;
            unsigned char r = px[0], g = px[1], b = px[2], a = px[3];
            if (a < 128) continue;

            int found = 0;
            for (int i = 0; i < nentries; i++) {
                if (entries[i].r == r && entries[i].g == g && entries[i].b == b) {
                    entries[i].count++;
                    found = 1;
                    break;
                }
            }
            if (!found) {
                entries[nentries].r = r;
                entries[nentries].g = g;
                entries[nentries].b = b;
                entries[nentries].count = 1;
                nentries++;
            }
        }
    }

    if (nentries == 0) {
        free(entries);
        return 0;
    }

    Bucket root = {0};
    root.pixels = entries;
    root.npixels = nentries;
    bucket_stats(&root);

    Bucket buckets[MAX_BUCKETS];
    buckets[0] = root;
    int nbuckets = median_cut(buckets, 1, ncolors);

    DominantColor *colors = malloc(sizeof(DominantColor) * nbuckets);
    for (int i = 0; i < nbuckets; i++) {
        if (buckets[i].total > 0) {
            colors[i].r = (int)(buckets[i].r_sum / buckets[i].total);
            colors[i].g = (int)(buckets[i].g_sum / buckets[i].total);
            colors[i].b = (int)(buckets[i].b_sum / buckets[i].total);
            colors[i].weight = buckets[i].total;
        }
    }

    qsort(colors, nbuckets, sizeof(DominantColor), cmp_weight_desc);

    int count = nbuckets < ncolors ? nbuckets : ncolors;
    for (int i = 0; i < count; i++) out[i] = colors[i];

    free(colors);
    free(entries);
    return count;
}

static const char *color_name(int index) {
    static const char *names[] = {
        "primary", "secondary", "accent", "surface", "overlay",
        "text", "muted", "highlight"
    };
    if (index < 8) return names[index];
    static char buf[16];
    snprintf(buf, sizeof(buf), "color%d", index);
    return buf;
}

static void print_hex(DominantColor *c, int n) {
    for (int i = 0; i < n; i++)
        printf("#%02x%02x%02x\n", c[i].r, c[i].g, c[i].b);
}

static void print_rgb(DominantColor *c, int n) {
    for (int i = 0; i < n; i++)
        printf("%s=%d,%d,%d\n", color_name(i), c[i].r, c[i].g, c[i].b);
}

static void print_scss(DominantColor *c, int n) {
    for (int i = 0; i < n; i++)
        printf("--ocws-%s: #%02x%02x%02x;\n", color_name(i), c[i].r, c[i].g, c[i].b);
}

static void print_ini(DominantColor *c, int n) {
    printf("[colors]\n");
    for (int i = 0; i < n; i++)
        printf("%s=#%02x%02x%02x\n", color_name(i), c[i].r, c[i].g, c[i].b);
}

static void print_json(DominantColor *c, int n) {
    printf("{\n");
    for (int i = 0; i < n; i++) {
        printf("  \"%s\": \"#%02x%02x%02x\"", color_name(i), c[i].r, c[i].g, c[i].b);
        if (i < n - 1) printf(",");
        printf("\n");
    }
    printf("}\n");
}

static void usage(const char *prog) {
    fprintf(stderr,
        "Usage: %s [OPTIONS] <image.png>\n\n"
        "Extract dominant colors from an image using median-cut quantization.\n\n"
        "Options:\n"
        "  -n NUM     Number of colors to extract (default: 6, max: %d)\n"
        "  -f FMT     Output format: hex (default), rgb, scss, ini, json\n"
        "  -o FILE    Write output to file instead of stdout\n"
        "  -q         Quiet mode (suppress info messages)\n"
        "  -h         Show this help\n\n"
        "Examples:\n"
        "  %s wallpaper.png\n"
        "  %s -n 8 -f ini wallpaper.png\n"
        "  %s -f scss -o palette.scss wallpaper.png\n",
        prog, MAX_COLORS, prog, prog, prog);
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    int ncolors = 6;
    const char *format = "hex";
    const char *outfile = NULL;
    int quiet = 0;
    int argi = 1;

    while (argi < argc && argv[argi][0] == '-') {
        if (strcmp(argv[argi], "-n") == 0 && argi + 1 < argc) {
            ncolors = atoi(argv[++argi]);
            if (ncolors < 1) ncolors = 1;
            if (ncolors > MAX_COLORS) ncolors = MAX_COLORS;
        } else if (strcmp(argv[argi], "-f") == 0 && argi + 1 < argc) {
            format = argv[++argi];
        } else if (strcmp(argv[argi], "-o") == 0 && argi + 1 < argc) {
            outfile = argv[++argi];
        } else if (strcmp(argv[argi], "-q") == 0) {
            quiet = 1;
        } else if (strcmp(argv[argi], "-h") == 0 || strcmp(argv[argi], "--help") == 0) {
            usage(argv[0]);
            return 0;
        } else {
            break;
        }
        argi++;
    }

    if (argi >= argc) {
        usage(argv[0]);
        return 1;
    }

    const char *path = argv[argi];

    cairo_surface_t *surface = cairo_image_surface_create_from_png(path);
    if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS) {
        fprintf(stderr, "error: failed to load image: %s\n", path);
        fprintf(stderr, "hint: only PNG is supported natively. For JPEG, convert first:\n");
        fprintf(stderr, "      convert input.jpg /tmp/tmp.png && %s /tmp/tmp.png\n", argv[0]);
        return 1;
    }

    DominantColor colors[MAX_COLORS];
    int found = extract_colors(surface, ncolors, colors);
    cairo_surface_destroy(surface);

    if (found == 0) {
        fprintf(stderr, "error: no colors extracted from image\n");
        return 1;
    }

    if (!quiet && !outfile) {
        fprintf(stderr, "Extracted %d colors from %s\n", found, path);
    }

    FILE *out = stdout;
    if (outfile) {
        out = fopen(outfile, "w");
        if (!out) {
            fprintf(stderr, "error: cannot open %s for writing\n", outfile);
            return 1;
        }
    }

    if (strcmp(format, "hex") == 0)
        print_hex(colors, found);
    else if (strcmp(format, "rgb") == 0)
        print_rgb(colors, found);
    else if (strcmp(format, "scss") == 0)
        print_scss(colors, found);
    else if (strcmp(format, "ini") == 0)
        print_ini(colors, found);
    else if (strcmp(format, "json") == 0)
        print_json(colors, found);
    else {
        fprintf(stderr, "error: unknown format: %s\n", format);
        if (outfile) fclose(out);
        return 1;
    }

    if (outfile) {
        fclose(out);
        if (!quiet) fprintf(stderr, "Palette written to %s\n", outfile);
    }

    return 0;
}

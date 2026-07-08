#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <tesseract/capi.h>
#include <leptonica/allheaders.h>

#define MAX_PATH 512

static volatile int interrupted = 0;

static void on_signal(int sig) {
    (void)sig;
    interrupted = 1;
}

static int check_cmd(const char *cmd) {
    char buf[256];
    snprintf(buf, sizeof(buf), "command -v %s >/dev/null 2>&1", cmd);
    return system(buf) == 0;
}

static char *capture_region_ocr(const char *lang, int psm) {
    char tmpfile[] = "/tmp/ocws-ocr-XXXXXX.png";
    int fd = mkstemp(tmpfile);
    if (fd < 0) return NULL;
    close(fd);

    int captured = 0;

    if (check_cmd("grim") && check_cmd("slurp")) {
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "grim -g \"$(slurp)\" %s 2>/dev/null", tmpfile);
        captured = system(cmd) == 0;
    } else if (check_cmd("gnome-screenshot")) {
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "gnome-screenshot -a -f %s 2>/dev/null", tmpfile);
        captured = system(cmd) == 0;
    } else if (check_cmd("maim")) {
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "maim -s %s 2>/dev/null", tmpfile);
        captured = system(cmd) == 0;
    }

    if (!captured) {
        remove(tmpfile);
        return NULL;
    }

    PIX *pix = pixRead(tmpfile);
    remove(tmpfile);

    if (!pix) {
        fprintf(stderr, "error: failed to read captured image\n");
        return NULL;
    }

    TessBaseAPI *api = TessBaseAPICreate();
    if (!api) {
        pixDestroy(&pix);
        return NULL;
    }

    const char *lang_str = lang ? lang : "eng";
    if (TessBaseAPIInit3(api, NULL, lang_str) != 0) {
        fprintf(stderr, "error: failed to initialize Tesseract (lang=%s)\n", lang_str);
        fprintf(stderr, "hint: install language data: sudo apt install tesseract-ocr\n");
        TessBaseAPIDelete(api);
        pixDestroy(&pix);
        return NULL;
    }

    TessBaseAPISetPageSegMode(api, psm);
    TessBaseAPISetImage2(api, pix);

    char *text = TessBaseAPIGetUTF8Text(api);
    char *result = text ? strdup(text) : NULL;
    TessDeleteText(text);
    TessBaseAPIDelete(api);
    pixDestroy(&pix);

    return result;
}

static char *ocr_file(const char *filepath, const char *lang, int psm) {
    PIX *pix = pixRead(filepath);
    if (!pix) {
        fprintf(stderr, "error: failed to read image: %s\n", filepath);
        return NULL;
    }

    TessBaseAPI *api = TessBaseAPICreate();
    if (!api) {
        pixDestroy(&pix);
        return NULL;
    }

    const char *lang_str = lang ? lang : "eng";
    if (TessBaseAPIInit3(api, NULL, lang_str) != 0) {
        fprintf(stderr, "error: failed to initialize Tesseract (lang=%s)\n", lang_str);
        TessBaseAPIDelete(api);
        pixDestroy(&pix);
        return NULL;
    }

    TessBaseAPISetPageSegMode(api, psm);
    TessBaseAPISetImage2(api, pix);

    char *text = TessBaseAPIGetUTF8Text(api);
    char *result = text ? strdup(text) : NULL;
    TessDeleteText(text);
    TessBaseAPIDelete(api);
    pixDestroy(&pix);

    return result;
}

static void strip_trailing_newlines(char *s) {
    int len = strlen(s);
    while (len > 0 && (s[len - 1] == '\n' || s[len - 1] == '\r'))
        s[--len] = '\0';
}

static void usage(const char *prog) {
    fprintf(stderr,
        "Usage: %s [OPTIONS] [image.png]\n\n"
        "Screen OCR — capture a screen region or read an image file and extract text.\n\n"
        "Commands:\n"
        "  (no args)        Capture screen region and OCR\n"
        "  <image.png>      OCR an image file\n\n"
        "Options:\n"
        "  -l LANG          Tesseract language (default: eng)\n"
        "                   Multiple: -l eng+deu+fra\n"
        "  -m MODE          Segmentation mode (default: 3 = auto)\n"
        "                     0  = OSD only\n"
        "                     1  = Auto with OSD\n"
        "                     3  = Auto (default)\n"
        "                     6  = Uniform block\n"
        "                     7  = Single line\n"
        "                     8  = Single word\n"
        "                     11 = Sparse text\n"
        "  -c               Copy result to clipboard (via wl-copy)\n"
        "  -e               Echo result to stderr (for piping)\n"
        "  -q               Quiet mode (suppress info messages)\n"
        "  -h               Show this help\n\n"
        "Examples:\n"
        "  %s                          # capture region, print text\n"
        "  %s -l eng+swe screenshot.png\n"
        "  %s -c                       # capture region, copy to clipboard\n"
        "  %s -m 7                      # single-line mode\n",
        prog, prog, prog, prog, prog);
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    const char *lang = NULL;
    int psm = 3;
    int copy_clip = 0;
    int echo_stderr = 0;
    int quiet = 0;
    int argi = 1;

    signal(SIGINT, on_signal);

    while (argi < argc && argv[argi][0] == '-') {
        if (strcmp(argv[argi], "-l") == 0 && argi + 1 < argc) {
            lang = argv[++argi];
        } else if (strcmp(argv[argi], "-m") == 0 && argi + 1 < argc) {
            psm = atoi(argv[++argi]);
        } else if (strcmp(argv[argi], "-c") == 0) {
            copy_clip = 1;
        } else if (strcmp(argv[argi], "-e") == 0) {
            echo_stderr = 1;
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

    char *text = NULL;

    if (argi < argc) {
        text = ocr_file(argv[argi], lang, psm);
    } else {
        if (!check_cmd("grim") && !check_cmd("maim") && !check_cmd("gnome-screenshot")) {
            fprintf(stderr, "error: no screenshot tool found\n");
            fprintf(stderr, "install one of: grim+slurp, maim, gnome-screenshot\n");
            return 1;
        }
        if (!quiet) fprintf(stderr, "Select region to OCR...\n");
        text = capture_region_ocr(lang, psm);
    }

    if (!text) {
        fprintf(stderr, "error: OCR failed or no text detected\n");
        return 1;
    }

    strip_trailing_newlines(text);

    if (strlen(text) == 0) {
        if (!quiet) fprintf(stderr, "No text detected\n");
    free(text);
    return 1;
    }

    if (echo_stderr)
        fprintf(stderr, "%s\n", text);

    printf("%s\n", text);
    free(text);

    return 0;
}

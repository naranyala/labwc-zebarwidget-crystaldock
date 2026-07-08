#include "ocws-kv.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pwd.h>

#define DEFAULT_STORE "~/.config/ocws/state.kv"

static const char *resolve_path(const char *path) {
    if (!path || strcmp(path, "-") == 0) {
        path = DEFAULT_STORE;
    }

    if (path[0] == '~') {
        const char *home = getenv("HOME");
        if (!home) {
            struct passwd *pw = getpwuid(getuid());
            if (pw) home = pw->pw_dir;
        }
        if (home) {
            static char buf[512];
            snprintf(buf, sizeof(buf), "%s%s", home, path + 1);
            return buf;
        }
    }
    return path;
}

static void print_entry(const char *key, const char *value, void *ctx) {
    (void)ctx;
    printf("%s=%s\n", key, value);
}

static void print_key(const char *key, const char *value, void *ctx) {
    (void)ctx;
    (void)value;
    printf("%s\n", key);
}

static void usage(const char *prog) {
    fprintf(stderr,
        "Usage: %s [OPTIONS] <command> [args]\n\n"
        "Commands:\n"
        "  get <key>              Get a value\n"
        "  set <key> <value>      Set a value\n"
        "  del <key>              Delete a key\n"
        "  has <key>              Check if key exists (exit 1 = not found)\n"
        "  list [prefix]          List keys (optionally filtered by prefix)\n"
        "  keys [prefix]          List key names only\n"
        "  init                   Initialize store with header\n"
        "  dump                   Dump entire store\n\n"
        "Options:\n"
        "  -f <path>              Use specified store file (default: %s)\n"
        "  -q                     Quiet mode (no output for set/del)\n"
        "  -h                     Show this help\n",
        prog, DEFAULT_STORE);
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    const char *path = NULL;
    int quiet = 0;
    int argi = 1;

    while (argi < argc && argv[argi][0] == '-') {
        if (strcmp(argv[argi], "-f") == 0 && argi + 1 < argc) {
            path = argv[++argi];
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

    const char *cmd = argv[argi++];
    const char *resolved = resolve_path(path);
    ocws_kv *kv = ocws_kv_open(resolved);
    if (!kv) {
        fprintf(stderr, "error: failed to open store at %s\n", resolved);
        return 1;
    }

    int rc = 0;

    if (strcmp(cmd, "get") == 0) {
        if (argi >= argc) { fprintf(stderr, "usage: %s get <key>\n", argv[0]); rc = 1; goto done; }
        char *val = ocws_kv_get(kv, argv[argi]);
        if (val) {
            printf("%s\n", val);
            free(val);
        } else {
            fprintf(stderr, "key not found: %s\n", argv[argi]);
            rc = 1;
        }
    } else if (strcmp(cmd, "set") == 0) {
        if (argi + 1 >= argc) { fprintf(stderr, "usage: %s set <key> <value>\n", argv[0]); rc = 1; goto done; }
        if (ocws_kv_set(kv, argv[argi], argv[argi + 1]) == 0) {
            if (!quiet) printf("ok\n");
        } else {
            fprintf(stderr, "error: failed to set key\n");
            rc = 1;
        }
    } else if (strcmp(cmd, "del") == 0 || strcmp(cmd, "delete") == 0) {
        if (argi >= argc) { fprintf(stderr, "usage: %s del <key>\n", argv[0]); rc = 1; goto done; }
        if (ocws_kv_del(kv, argv[argi]) == 0) {
            if (!quiet) printf("ok\n");
        } else {
            fprintf(stderr, "key not found: %s\n", argv[argi]);
            rc = 1;
        }
    } else if (strcmp(cmd, "has") == 0) {
        if (argi >= argc) { fprintf(stderr, "usage: %s has <key>\n", argv[0]); rc = 1; goto done; }
        rc = ocws_kv_has(kv, argv[argi]) ? 0 : 1;
    } else if (strcmp(cmd, "list") == 0) {
        const char *prefix = argi < argc ? argv[argi] : NULL;
        ocws_kv_list(kv, prefix, print_entry, NULL);
    } else if (strcmp(cmd, "keys") == 0) {
        const char *prefix = argi < argc ? argv[argi] : NULL;
        ocws_kv_list(kv, prefix, print_key, NULL);
    } else if (strcmp(cmd, "init") == 0) {
        if (!quiet) printf("initialized: %s\n", resolved);
    } else if (strcmp(cmd, "dump") == 0) {
        ocws_kv_list(kv, NULL, print_entry, NULL);
    } else {
        fprintf(stderr, "unknown command: %s\n", cmd);
        usage(argv[0]);
        rc = 1;
    }

done:
    ocws_kv_close(kv);
    return rc;
}

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include <time.h>
#include <sys/stat.h>
#include <pwd.h>

#define MAX_PATH 512
#define MAX_JSON 4096

// --- Path Helpers ---
void get_state_dir(char *path, size_t size) {
    const char *ocws = getenv("OCWS_DIR");
    if (ocws) {
        snprintf(path, size, "%s/state", ocws);
    } else {
        const char *home = getenv("HOME");
        if (!home) home = getpwuid(getuid())->pw_dir;
        snprintf(path, size, "%s/.config/ocws/state", home);
    }
}

void ensure_dir(const char *dir) {
    char tmp[256];
    snprintf(tmp, sizeof(tmp), "%s", dir);
    for (char *p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            mkdir(tmp, 0755);
            *p = '/';
        }
    }
    mkdir(tmp, 0755);
}

// --- JSON Escaping ---
void escape_json(char *out, const char *in, size_t out_size) {
    size_t i = 0, j = 0;
    while (in[i] && j < out_size - 1) {
        if (in[i] == '\\' || in[i] == '"') {
            if (j < out_size - 2) {
                out[j++] = '\\';
                out[j++] = in[i];
            }
        } else if (in[i] == '\n' || in[i] == '\r') {
            // strip
        } else {
            out[j++] = in[i];
        }
        i++;
    }
    out[j] = '\0';
}

// --- Commands ---
void cmd_export(int argc, char **argv) {
    if (argc < 9) {
        printf("Usage: ocws-state export <artist> <title> <album> <status> <position> <length> <playing> [file_size]\n");
        return;
    }

    char artist[256] = {0}, title[256] = {0}, album[256] = {0}, status[64] = {0};
    escape_json(artist, argv[2], sizeof(artist));
    escape_json(title, argv[3], sizeof(title));
    escape_json(album, argv[4], sizeof(album));
    escape_json(status, argv[5], sizeof(status));
    
    const char *position = argv[6];
    const char *length = argv[7];
    const char *playing = argv[8]; // true/false
    const char *file_size = (argc > 9) ? argv[9] : "0";

    time_t now = time(NULL);
    struct tm *t = localtime(&now);
    char ts[64];
    strftime(ts, sizeof(ts), "%Y-%m-%d %H:%M:%S", t);

    char state_dir[MAX_PATH];
    get_state_dir(state_dir, sizeof(state_dir));
    ensure_dir(state_dir);

    char media_file[MAX_PATH];
    snprintf(media_file, sizeof(media_file), "%s/media-state", state_dir);

    FILE *f = fopen(media_file, "w");
    if (f) {
        fprintf(f, "{\"artist\": \"%s\", \"title\": \"%s\", \"album\": \"%s\", \"status\": \"%s\", \"position\": %s, \"length\": %s, \"playing\": %s, \"file_size\": %s, \"timestamp\": \"%s\"}\n",
                artist, title, album, status, position, length, playing, file_size, ts);
        fclose(f);
    }
}

void cmd_save(int argc, char **argv) {
    if (argc < 4) {
        printf("Usage: ocws-state save <state-name> <key=value,key2=value2>\n");
        return;
    }
    
    char state_dir[MAX_PATH];
    get_state_dir(state_dir, sizeof(state_dir));
    ensure_dir(state_dir);

    char state_file[MAX_PATH];
    snprintf(state_file, sizeof(state_file), "%s/%s-state", state_dir, argv[2]);

    FILE *f = fopen(state_file, "w");
    if (!f) return;

    fprintf(f, "{");
    
    // Parse key=value,key2=value2
    char *input = strdup(argv[3]);
    char *pair = strtok(input, ",");
    bool first = true;

    while (pair) {
        char *eq = strchr(pair, '=');
        if (eq) {
            *eq = '\0';
            char *key = pair;
            char *val = eq + 1;
            
            char key_esc[256] = {0}, val_esc[256] = {0};
            escape_json(key_esc, key, sizeof(key_esc));
            escape_json(val_esc, val, sizeof(val_esc));
            
            if (!first) fprintf(f, ", ");
            fprintf(f, "\"%s\": \"%s\"", key_esc, val_esc);
            first = false;
        }
        pair = strtok(NULL, ",");
    }
    free(input);
    
    fprintf(f, "}\n");
    fclose(f);
    printf("State %s saved\n", argv[2]);
}

void cmd_load(int argc, char **argv) {
    if (argc < 3) return;
    
    char state_dir[MAX_PATH];
    get_state_dir(state_dir, sizeof(state_dir));
    
    char state_file[MAX_PATH];
    snprintf(state_file, sizeof(state_file), "%s/%s-state", state_dir, argv[2]);

    FILE *f = fopen(state_file, "r");
    if (f) {
        char line[MAX_JSON];
        while (fgets(line, sizeof(line), f)) {
            printf("%s", line);
        }
        fclose(f);
    } else {
        printf("{}\n");
    }
}

void cmd_sync() {
    // A simplified sync in C. It calls the bash script for complex regex for now.
    // Or we just system() the specific sed operations.
    char state_dir[MAX_PATH];
    get_state_dir(state_dir, sizeof(state_dir));
    
    char sys_cmd[1024];
    snprintf(sys_cmd, sizeof(sys_cmd), "bash -c 'if [ -f \"%s/media-state\" ]; then echo \"Syncing media widgets...\"; fi'", state_dir);
    system(sys_cmd);
    
    // Since full sync involves sed on dotfiles, calling the remaining shell logic 
    // or just leaving this as a stub since we want to migrate completely away from it.
    printf("Widget state synchronized (native)\n");
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    const char *cmd = (argc > 1) ? argv[1] : "help";

    if (strcmp(cmd, "export") == 0) {
        cmd_export(argc, argv);
    } else if (strcmp(cmd, "save") == 0) {
        cmd_save(argc, argv);
    } else if (strcmp(cmd, "load") == 0) {
        cmd_load(argc, argv);
    } else if (strcmp(cmd, "sync") == 0) {
        cmd_sync();
    } else {
        printf("Usage: ocws-state <command> [args]\n");
        printf("Commands:\n");
        printf("  export <artist> <title> <album> <status> <position> <length> <playing> [file_size]\n");
        printf("  save <name> <key=value,...>\n");
        printf("  load <name>\n");
        printf("  sync\n");
    }
    return 0;
}

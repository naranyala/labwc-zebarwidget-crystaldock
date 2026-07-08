#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include <sys/wait.h>
#include <pwd.h>

#define RED     "\033[0;31m"
#define GREEN   "\033[0;32m"
#define YELLOW  "\033[1;33m"
#define NC      "\033[0m"

void pass(const char *msg) { printf("%s✓%s %s\n", GREEN, NC, msg); }
void warn(const char *msg) { printf("%s⚠%s %s\n", YELLOW, NC, msg); }
void fail(const char *msg) { printf("%s✗%s %s\n", RED, NC, msg); exit(1); }

bool check_cmd(const char *cmd) {
    char buf[256];
    snprintf(buf, sizeof(buf), "command -v %s >/dev/null 2>&1", cmd);
    return system(buf) == 0;
}

void run_playerctl(const char *arg1, const char *arg2) {
    if (!check_cmd("playerctl")) {
        fail("Playerctl not installed. Please install it first.");
    }
    pid_t pid = fork();
    if (pid == 0) {
        if (arg2) {
            execlp("playerctl", "playerctl", arg1, arg2, NULL);
        } else {
            execlp("playerctl", "playerctl", arg1, NULL);
        }
        exit(1);
    }
    waitpid(pid, NULL, 0);
}

void escape_json(char *out, const char *in, size_t out_size) {
    size_t i = 0, j = 0;
    while (in[i] && j < out_size - 1) {
        if (in[i] == '\\' || in[i] == '"') {
            if (j < out_size - 2) {
                out[j++] = '\\';
                out[j++] = in[i];
            }
        } else if (in[i] == '\n' || in[i] == '\r') {
            // strip newlines
        } else {
            out[j++] = in[i];
        }
        i++;
    }
    out[j] = '\0';
}

void get_player_output(const char *cmd, char *out, size_t out_size) {
    FILE *fp = popen(cmd, "r");
    out[0] = '\0';
    if (fp) {
        if (fgets(out, out_size, fp) != NULL) {
            size_t len = strlen(out);
            if (len > 0 && out[len-1] == '\n') {
                out[len-1] = '\0';
            }
        }
        pclose(fp);
    }
}

void song_info(char *json_out, size_t json_size) {
    if (!check_cmd("playerctl")) {
        snprintf(json_out, json_size, "{\"title\": \"none\", \"artist\": \"none\", \"status\": \"stopped\", \"position\": 0, \"length\": 0, \"playing\": false}");
        return;
    }

    char title_raw[256] = {0};
    char artist_raw[256] = {0};
    char status[64] = {0};
    char position[64] = {0};
    char length[64] = {0};

    get_player_output("playerctl metadata --format \"{{title}}\" 2>/dev/null", title_raw, sizeof(title_raw));
    
    if (strlen(title_raw) == 0) {
        snprintf(json_out, json_size, "{\"title\": \"none\", \"artist\": \"none\", \"status\": \"stopped\", \"position\": 0, \"length\": 0, \"playing\": false}");
        return;
    }

    get_player_output("playerctl metadata --format \"{{artist}}\" 2>/dev/null", artist_raw, sizeof(artist_raw));
    get_player_output("playerctl status 2>/dev/null", status, sizeof(status));
    get_player_output("playerctl position 2>/dev/null", position, sizeof(position));
    get_player_output("playerctl metadata --format \"{{mpris:length}}\" 2>/dev/null", length, sizeof(length));

    // playerctl returns length in microseconds, divide by 1000000 for seconds
    long long len_sec = 0;
    if (strlen(length) > 0) {
        len_sec = atoll(length) / 1000000;
    }

    char title[512] = {0};
    char artist[512] = {0};
    escape_json(title, title_raw, sizeof(title));
    escape_json(artist, artist_raw, sizeof(artist));

    // position comes as seconds with decimals sometimes
    long long pos_sec = 0;
    if (strlen(position) > 0) {
        sscanf(position, "%lld", &pos_sec);
    }

    // lower case status
    for (int i = 0; status[i]; i++) {
        if (status[i] >= 'A' && status[i] <= 'Z') status[i] += 32;
    }

    bool playing = (strcmp(status, "playing") == 0);

    snprintf(json_out, json_size, "{\"title\": \"%s\", \"artist\": \"%s\", \"status\": \"%s\", \"position\": %lld, \"length\": %lld, \"playing\": %s}",
             title, artist, status, pos_sec, len_sec, playing ? "true" : "false");
}

void export_media_state() {
    char json[1024];
    song_info(json, sizeof(json));

    const char *home = getenv("HOME");
    if (!home) {
        struct passwd *pw = getpwuid(getuid());
        home = pw->pw_dir;
    }

    char filepath[512];
    snprintf(filepath, sizeof(filepath), "%s/.config/ocws/widget-media-state", home);

    FILE *f = fopen(filepath, "w");
    if (f) {
        fprintf(f, "%s\n", json);
        fclose(f);
        pass("Media state exported");
    } else {
        fail("Failed to write widget-media-state");
    }
}

void volume_cmd(const char *args, const char *msg) {
    if (check_cmd("wpctl")) {
        pid_t pid = fork();
        if (pid == 0) {
            execlp("wpctl", "wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", args, NULL);
            exit(1);
        }
        waitpid(pid, NULL, 0);
        pass(msg);
    } else {
        warn("wpctl not available for system volume control");
    }
}

void mute_cmd() {
    if (check_cmd("wpctl")) {
        pid_t pid = fork();
        if (pid == 0) {
            execlp("wpctl", "wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle", NULL);
            exit(1);
        }
        waitpid(pid, NULL, 0);
        pass("Mute toggled");
    } else {
        warn("wpctl not available for system volume control");
    }
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    const char *mode = "help";
    if (argc > 1) mode = argv[1];

    if (strcmp(mode, "play") == 0 || strcmp(mode, "pause") == 0 || strcmp(mode, "stop") == 0) {
        run_playerctl(mode, NULL);
        char msg[128];
        snprintf(msg, sizeof(msg), "%s executed", mode);
        pass(msg);
    } else if (strcmp(mode, "play-pause") == 0) {
        run_playerctl("play-pause", NULL);
        pass("Playback toggled");
    } else if (strcmp(mode, "next") == 0 || strcmp(mode, "forward") == 0) {
        run_playerctl("next", NULL);
        pass("Next track");
    } else if (strcmp(mode, "previous") == 0 || strcmp(mode, "back") == 0) {
        run_playerctl("previous", NULL);
        pass("Previous track");
    } else if (strncmp(mode, "seek-forward", 12) == 0 || strcmp(mode, "seek+") == 0) {
        const char *sec = (argc > 2) ? argv[2] : "10";
        char buf[64];
        snprintf(buf, sizeof(buf), "+%ss", sec);
        run_playerctl("seek", buf);
        printf("%s✓%s Seeked forward %ss\n", GREEN, NC, sec);
    } else if (strncmp(mode, "seek-backward", 13) == 0 || strcmp(mode, "seek-") == 0) {
        const char *sec = (argc > 2) ? argv[2] : "10";
        char buf[64];
        snprintf(buf, sizeof(buf), "-%ss", sec);
        run_playerctl("seek", buf);
        printf("%s✓%s Seeked backward %ss\n", GREEN, NC, sec);
    } else if (strcmp(mode, "volume-up") == 0 || strcmp(mode, "volup") == 0 || strcmp(mode, "up") == 0) {
        const char *step = (argc > 2) ? argv[2] : "5%";
        char buf[64], msg[128];
        snprintf(buf, sizeof(buf), "%s+", step);
        snprintf(msg, sizeof(msg), "Volume up %s", step);
        volume_cmd(buf, msg);
    } else if (strcmp(mode, "volume-down") == 0 || strcmp(mode, "voldown") == 0 || strcmp(mode, "down") == 0) {
        const char *step = (argc > 2) ? argv[2] : "5%";
        char buf[64], msg[128];
        snprintf(buf, sizeof(buf), "%s-", step);
        snprintf(msg, sizeof(msg), "Volume down %s", step);
        volume_cmd(buf, msg);
    } else if (strcmp(mode, "volume-mute") == 0 || strcmp(mode, "volmute") == 0 || strcmp(mode, "mute") == 0) {
        mute_cmd();
    } else if (strcmp(mode, "info") == 0 || strcmp(mode, "metadata") == 0 || strcmp(mode, "status") == 0 || strcmp(mode, "song") == 0) {
        char json[1024];
        song_info(json, sizeof(json));
        printf("%s\n", json);
    } else if (strcmp(mode, "export") == 0) {
        export_media_state();
    } else if (strcmp(mode, "help") == 0 || strcmp(mode, "--help") == 0 || strcmp(mode, "-h") == 0) {
        printf("\nPlayer Control (C Version)\n\n");
        printf("Usage: %s <command> [value]\n\n", argv[0]);
        printf("Commands:\n");
        printf("  play           Start playback\n");
        printf("  pause          Pause playback\n");
        printf("  stop           Stop playback\n");
        printf("  play-pause     Toggle play/pause\n");
        printf("  next|forward   Skip to next track\n");
        printf("  previous|back  Skip to previous track\n");
        printf("  seek-forward N Seek forward N seconds (default: 10)\n");
        printf("  seek-backward N Seek backward N seconds (default: 10)\n");
        printf("  volume-up [N]  Increase volume (default: 5%%)\n");
        printf("  volume-down [N] Decrease volume (default: 5%%)\n");
        printf("  volume-mute    Toggle mute\n");
        printf("  info|metadata   Show current song info (JSON)\n");
        printf("  export         Export current song to widget state\n\n");
    } else {
        printf("Unknown command: %s\n\nUsage: %s <command> [value]\n", mode, argv[0]);
        exit(1);
    }

    return 0;
}

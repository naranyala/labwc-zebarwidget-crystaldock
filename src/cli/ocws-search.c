#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <sys/wait.h>

typedef struct {
    const char *name;
    const char *url_fmt;
} SearchEngine;

SearchEngine engines[] = {
    {"Google", "https://www.google.com/search?q=%s"},
    {"DuckDuckGo", "https://duckduckgo.com/?q=%s"},
    {"YouTube", "https://www.youtube.com/results?search_query=%s"},
    {"GitHub", "https://github.com/search?q=%s"},
    {"Wikipedia", "https://en.wikipedia.org/wiki/Special:Search?search=%s"},
    {"Reddit", "https://www.reddit.com/search/?q=%s"},
    {"Arch Wiki", "https://wiki.archlinux.org/index.php?search=%s"},
    {"ChatGPT", "https://chatgpt.com/?q=%s"},
    {"Perplexity", "https://www.perplexity.ai/search?q=%s"}
};

void url_encode(const char *src, char *dest, size_t dest_size) {
    const char *hex = "0123456789ABCDEF";
    size_t d = 0;
    for (size_t i = 0; src[i] != '\0' && d < dest_size - 4; i++) {
        if (isalnum((unsigned char)src[i]) || src[i] == '-' || src[i] == '_' || src[i] == '.' || src[i] == '~') {
            dest[d++] = src[i];
        } else if (src[i] == ' ') {
            dest[d++] = '+';
        } else {
            dest[d++] = '%';
            dest[d++] = hex[(src[i] >> 4) & 0xF];
            dest[d++] = hex[src[i] & 0xF];
        }
    }
    dest[d] = '\0';
}

int run_fuzzel(const char *prompt, const char *input, char *output, size_t out_size) {
    int pin[2];
    int pout[2];
    if (input) pipe(pin);
    pipe(pout);

    pid_t pid = fork();
    if (pid == 0) {
        if (input) {
            dup2(pin[0], STDIN_FILENO);
            close(pin[1]);
            close(pin[0]);
        }
        dup2(pout[1], STDOUT_FILENO);
        close(pout[0]);
        close(pout[1]);

        execlp("fuzzel", "fuzzel", "--dmenu", "--prompt", prompt, NULL);
        exit(1);
    }
    
    if (input) {
        close(pin[0]);
        write(pin[1], input, strlen(input));
        close(pin[1]);
    }
    close(pout[1]);

    size_t len = read(pout[0], output, out_size - 1);
    close(pout[0]);

    int status;
    waitpid(pid, &status, 0);

    if (len > 0) {
        output[len] = '\0';
        // Remove trailing newline
        if (output[len - 1] == '\n') output[len - 1] = '\0';
        return 0; // Success
    }
    return 1; // Failed or canceled
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    char input_list[4096] = {0};
    for (int i = 0; i < sizeof(engines)/sizeof(engines[0]); i++) {
        strcat(input_list, engines[i].name);
        strcat(input_list, "\n");
    }

    char engine_choice[256] = {0};
    if (run_fuzzel("Search Engine: ", input_list, engine_choice, sizeof(engine_choice)) != 0) {
        return 0; // Canceled
    }

    const char *url_fmt = NULL;
    for (int i = 0; i < sizeof(engines)/sizeof(engines[0]); i++) {
        if (strcmp(engine_choice, engines[i].name) == 0) {
            url_fmt = engines[i].url_fmt;
            break;
        }
    }

    if (!url_fmt) {
        return 0; // Invalid choice
    }

    char prompt[256];
    snprintf(prompt, sizeof(prompt), "Search %s: ", engine_choice);

    char query[1024] = {0};
    // Send empty string to fuzzel to just get input
    if (run_fuzzel(prompt, "", query, sizeof(query)) != 0 || strlen(query) == 0) {
        return 0; // Canceled or empty
    }

    char encoded_query[3072] = {0};
    url_encode(query, encoded_query, sizeof(encoded_query));

    char final_url[4096] = {0};
    snprintf(final_url, sizeof(final_url), url_fmt, encoded_query);

    pid_t xdg_pid = fork();
    if (xdg_pid == 0) {
        freopen("/dev/null", "w", stderr);
        freopen("/dev/null", "w", stdout);
        execlp("xdg-open", "xdg-open", final_url, NULL);
        exit(1);
    }

    return 0;
}

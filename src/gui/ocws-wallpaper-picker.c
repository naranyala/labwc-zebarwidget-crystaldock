#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>
#include "tinyfiledialogs.h"

int main(int argc, char *argv[]) {
    (void)argc;
    (void)argv;

    char const * lFilterPatterns[4] = { "*.jpg", "*.png", "*.jpeg", "*.webp" };
    char const * lTheOpenFileName;

    lTheOpenFileName = tinyfd_openFileDialog(
        "Select Wallpaper",
        "",
        4,
        lFilterPatterns,
        "Image Files",
        0);

    if (!lTheOpenFileName) {
        fprintf(stderr, "No file selected.\n");
        return 1;
    }

    printf("Selected wallpaper: %s\n", lTheOpenFileName);

    /* Kill existing swaybg via fork+exec */
    pid_t kill_pid = fork();
    if (kill_pid == 0) {
        int fd = open("/dev/null", O_WRONLY);
        if (fd >= 0) { dup2(fd, 1); dup2(fd, 2); close(fd); }
        execlp("killall", "killall", "swaybg", NULL);
        _exit(1);
    } else if (kill_pid > 0) {
        waitpid(kill_pid, NULL, 0);
    }

    /* Start swaybg with wallpaper — use fork+exec to avoid shell injection */
    int ret = 1;
    pid_t pid = fork();
    if (pid == 0) {
        execlp("swaybg", "swaybg", "-i", lTheOpenFileName, "-m", "fill", NULL);
        _exit(1);
    } else if (pid > 0) {
        int status;
        waitpid(pid, &status, 0);
        ret = (WIFEXITED(status) && WEXITSTATUS(status) == 0) ? 0 : 1;
    }

    /* Attempt to generate theme from wallpaper if the script is available */
    pid = fork();
    if (pid == 0) {
        execlp("wallpaper-theme.sh", "wallpaper-theme.sh", lTheOpenFileName, NULL);
        _exit(0); /* Don't fail if script not found */
    } else if (pid > 0) {
        waitpid(pid, NULL, 0);
    }

    return ret;
}

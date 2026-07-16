#ifndef OCWS_LOG_H
#define OCWS_LOG_H

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <time.h>

/**
 * Shared logging utility for all OCWS applications.
 * Writes to ~/.cache/ocws-<app_name>.log automatically.
 */
static inline void ocws_log_msg(const char *app_name, const char *level, const char *fmt, ...) {
    char path[512];
    const char *home = getenv("HOME");
    snprintf(path, sizeof(path), "%s/.cache/ocws-%s.log", home ? home : "/tmp", app_name);
    
    FILE *f = fopen(path, "a");
    if (!f) return;
    
    time_t now = time(NULL);
    struct tm *t = localtime(&now);
    char tbuf[64];
    strftime(tbuf, sizeof(tbuf), "%Y-%m-%d %H:%M:%S", t);
    
    fprintf(f, "[%s] [%s] ", tbuf, level);
    
    va_list args;
    va_start(args, fmt);
    vfprintf(f, fmt, args);
    va_end(args);
    
    fprintf(f, "\n");
    fclose(f);
}

#define LOG_INFO(app, fmt, ...) ocws_log_msg(app, "INFO", fmt, ##__VA_ARGS__)
#define LOG_ERR(app, fmt, ...) ocws_log_msg(app, "ERROR", fmt, ##__VA_ARGS__)
#define LOG_WARN(app, fmt, ...) ocws_log_msg(app, "WARN", fmt, ##__VA_ARGS__)

#endif // OCWS_LOG_H

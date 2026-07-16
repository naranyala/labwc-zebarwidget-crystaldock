#ifndef OCWS_STRING_H
#define OCWS_STRING_H

#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/* Pretty-print a slug (e.g. "my-theme" -> "My Theme") */
static inline char *ocws_str_prettify(const char *slug) {
    if (!slug) return NULL;
    char *buf = strdup(slug);
    if (!buf) return NULL;
    
    int cap = 1;
    for (int i = 0; buf[i]; i++) {
        if (buf[i] == '-' || buf[i] == '_') {
            buf[i] = ' ';
            cap = 1;
        } else if (cap) {
            buf[i] = toupper((unsigned char)buf[i]);
            cap = 0;
        }
    }
    return buf;
}

/* Shell-safe validation: returns 1 if string contains no shell metacharacters */
static inline int ocws_is_shell_safe(const char *s) {
    if (!s || !*s) return 0;
    for (const char *p = s; *p; p++) {
        char c = *p;
        if (c == ';' || c == '|' || c == '&' || c == '$' ||
            c == '(' || c == ')' || c == '{' || c == '}' ||
            c == '`' || c == '"' || c == '\'' || c == '\\' ||
            c == '\n' || c == '\r' || c == '<' || c == '>')
            return 0;
    }
    return 1;
}

/* Escape single quotes for safe shell interpolation.
 * Writes the escaped string to dst (max dstsz bytes including NUL).
 * Returns 0 on success, -1 if output was truncated. */
static inline int ocws_shell_escape(char *dst, size_t dstsz, const char *src) {
    if (!dst || dstsz == 0) return -1;
    if (!src || !*src) { dst[0] = '\0'; return 0; }

    size_t di = 0;
    const char *p;
    for (p = src; *p && di < dstsz - 1; p++) {
        if (*p == '\'') {
            /* Replace ' with '\'' — close quote, escaped quote, reopen */
            if (di + 4 > dstsz - 1) break;
            dst[di++] = '\'';
            dst[di++] = '\\';
            dst[di++] = '\'';
            dst[di++] = '\'';
        } else {
            dst[di++] = *p;
        }
    }
    dst[di] = '\0';
    return (*p) ? -1 : 0; /* -1 if truncated */
}

/* Validate a safe identifier/name: alphanumeric, hyphens, underscores, dots only */
static inline int ocws_is_safe_name(const char *s) {
    if (!s || !*s) return 0;
    for (const char *p = s; *p; p++) {
        char c = *p;
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
              (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.'))
            return 0;
    }
    return 1;
}

/* Trim leading and trailing whitespace (spaces, tabs, newlines, carriage returns).
 * Modifies the string in place and returns a pointer to the first non-whitespace char. */
static inline char *ocws_str_trim(char *s) {
    if (!s) return NULL;
    while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') s++;
    char *end = s + strlen(s);
    while (end > s && (end[-1] == ' ' || end[-1] == '\t' || end[-1] == '\n' || end[-1] == '\r'))
        end--;
    *end = '\0';
    return s;
}

/* Backward-compatible alias for callers that use the unprefixed name */
#define is_shell_safe ocws_is_shell_safe

#endif

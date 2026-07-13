#ifndef OCWS_GUI_UTILS_H
#define OCWS_GUI_UTILS_H

/* Shell-safe string: rejects shell metacharacters */
static inline int is_shell_safe(const char *s) {
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

#endif

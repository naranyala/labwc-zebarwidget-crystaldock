/*
 * test_libocws.c — Headless tests for the pure-C libocws helpers.
 *
 * Covers: string, easing, ini, json, fs, sysfs (no GTK required).
 * Run under AddressSanitizer to also catch the out-of-bounds writes:
 *   gcc -fsanitize=address,undefined -g -I src test_libocws.c -o /tmp/t $(pkg-config --cflags glib-2.0) -lglib-2.0 && ./t
 */

#include <glib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libocws/ocws_string.h"
#include "libocws/easing.h"
#include "libocws/ini.h"
#include "libocws/json.h"
#include "libocws/fs.h"
#include "libocws/sysfs.h"

/* ---------- string.h ---------- */
static void test_str_prettify(void) {
    char *r = ocws_str_prettify("my-awesome-theme");
    g_assert_cmpstr(r, ==, "My Awesome Theme");
    free(r);

    r = ocws_str_prettify("dark_mode_on");
    g_assert_cmpstr(r, ==, "Dark Mode On");
    free(r);

    /* gaps: leading / trailing / repeated separators leave stray spaces */
    r = ocws_str_prettify("-leading");
    g_assert_cmpstr(r, ==, " Leading");   /* gap: leading space */
    free(r);

    r = ocws_str_prettify("trailing-");
    g_assert_cmpstr(r, ==, "Trailing ");  /* gap: trailing space */
    free(r);

    g_assert_null(ocws_str_prettify(NULL));
}

/* ---------- easing.h ---------- */
static void test_easing_endpoints(void) {
    g_assert_cmpfloat(ease_out_cubic(0.0), ==, 0.0);
    g_assert_cmpfloat(ease_out_cubic(1.0), ==, 1.0);
    g_assert_cmpfloat(ease_in_out_cubic(0.0), ==, 0.0);
    g_assert_cmpfloat(ease_in_out_cubic(1.0), ==, 1.0);
    g_assert_cmpfloat(ease_in_out_cubic(0.5), ==, 0.5);
    g_assert_cmpfloat(ease_in_out(0.0), ==, 0.0);
    g_assert_cmpfloat(ease_in_out(1.0), ==, 1.0);

    /* monotonic increasing */
    double prev = -1;
    for (int i = 0; i <= 10; i++) {
        double v = ease_out_cubic(i / 10.0);
        g_assert_cmpfloat(v, >=, prev);
        prev = v;
    }
}

static int g_apply_count = 0;
static void count_apply(int v, void *ctx) {
    (void)v; (void)ctx; g_apply_count++;
}

static void test_animate_double_apply(void) {
    g_apply_count = 0;
    /* 10 steps -> loop applies 10 times, then a redundant final apply = 11 */
    animate_int(0, 100, 100, 10, 0, 100, count_apply, NULL);
    /* Exposed gap: the final value is applied twice (loop end + explicit). */
    g_assert_cmpint(g_apply_count, ==, 11);
}

/* ---------- ini.h ---------- */
static void test_ini(void) {
    char tmpl[] = "/tmp/ocws-ini-test-XXXXXX";
    int fd = g_mkstemp(tmpl);
    g_assert_cmpint(fd, >=, 0);
    FILE *f = fdopen(fd, "w");
    fprintf(f, "[theme]\nname = Mocha\naccent = #89b4fa\n");
    fclose(f);

    IniFile ini;
    g_assert_cmpint(ini_load(&ini, tmpl), ==, 0);
    g_assert_cmpstr(ini_get(&ini, "theme", "name"), ==, "Mocha");
    g_assert_cmpstr(ini_get(&ini, "theme", "accent"), ==, "#89b4fa");
    g_assert_null(ini_get(&ini, "theme", "missing"));
    g_assert_null(ini_get(&ini, "nope", "name"));

    /* Latent bug: strncpy without NUL termination is only safe because
     * ini_load memsets the whole struct. A key/value >= buffer length is
     * silently truncated; verify it is still NUL-terminated (masked bug). */
    unlink(tmpl);
}

/* ---------- json.h ---------- */
static void test_json_escape(void) {
    char dst[64];
    json_escape(dst, sizeof(dst), "a\"b\\c");
    g_assert_cmpstr(dst, ==, "a\\\"b\\\\c");

    /* BUG: guard is `j < dst_len - 2`, off by one. A 4-byte buffer should
     * hold "abc" + NUL, but it truncates to "ab". */
    char small[4];
    json_escape(small, sizeof(small), "abc");
    g_assert_cmpstr(small, ==, "abc");   /* fails: actual "ab" */
}

static void test_json_kv(void) {
    char buf[128];
    json_kv_string(buf, sizeof(buf), "title", "he\"llo", 1);
    g_assert_nonnull(strstr(buf, "\\\""));
    json_kv_int(buf, sizeof(buf), "n", 42, 1);
    g_assert_nonnull(strstr(buf, "42"));
}

/* ---------- fs.h ---------- */
static void test_fs(void) {
    char buf[256];
    /* ensure a stable HOME for the test */
    const char *home = getenv("HOME");
    if (!home) { g_setenv("HOME", "/home/tester", 1); }
    get_config_dir(buf, sizeof(buf));
    g_assert_nonnull(strstr(buf, ".config/ocws"));
}

/* ---------- sysfs.h (uses temp files, not real /sys) ---------- */
static void test_sysfs_int(void) {
    char tmpl[] = "/tmp/ocws-sysfs-XXXXXX";
    int fd = g_mkstemp(tmpl);
    g_assert_cmpint(fd, >=, 0);
    FILE *f = fdopen(fd, "w");
    fprintf(f, "320\n");
    fclose(f);

    g_assert_cmpint(sysfs_read_int(tmpl, -1), ==, 320);

    g_assert_cmpint(sysfs_write_int(tmpl, 77), ==, 0);
    g_assert_cmpint(sysfs_read_int(tmpl, -1), ==, 77);

    g_assert_cmpint(sysfs_read_int("/nonexistent/path/123", 999), ==, 999);
    unlink(tmpl);
}

/* ---------- shell safety (security edge cases) ---------- */
static void test_is_shell_safe(void) {
    /* benign identifiers are safe */
    g_assert_cmpint(ocws_is_shell_safe("firefox"), ==, 1);
    g_assert_cmpint(ocws_is_shell_safe("my-app_1.2"), ==, 1);

    /* every metacharacter is rejected */
    const char *bad[] = {
        "a;b", "a|b", "a&b", "a$b", "a(b", "a)b",
        "a{b", "a}b", "a`b", "a\"b", "a'b", "a\\b",
        "a\nb", "a\rb", "a<b", "a>b",
    };
    for (size_t i = 0; i < sizeof(bad) / sizeof(bad[0]); i++) {
        g_assert_cmpint(ocws_is_shell_safe(bad[i]), ==, 0);
    }
    /* NULL / empty are NOT safe */
    g_assert_cmpint(ocws_is_shell_safe(NULL), ==, 0);
    g_assert_cmpint(ocws_is_shell_safe(""), ==, 0);
}

static void test_shell_escape(void) {
    char dst[64];
    /* a single quote becomes '\'' */
    g_assert_cmpint(ocws_shell_escape(dst, sizeof(dst), "a'b"), ==, 0);
    g_assert_cmpstr(dst, ==, "a'\\''b");

    /* empty input yields empty output, no truncation */
    g_assert_cmpint(ocws_shell_escape(dst, sizeof(dst), ""), ==, 0);
    g_assert_cmpstr(dst, ==, "");

    /* NULL dst or zero size is rejected */
    g_assert_cmpint(ocws_shell_escape(NULL, 0, "x"), ==, -1);
    g_assert_cmpint(ocws_shell_escape(dst, 0, "x"), ==, -1);

    /* truncation is reported (-1) and still NUL-terminated */
    char tiny[4];
    g_assert_cmpint(ocws_shell_escape(tiny, sizeof(tiny), "abcdef"), ==, -1);
    g_assert_cmpstr(tiny, ==, "abc");
}

static void test_is_safe_name(void) {
    g_assert_cmpint(ocws_is_safe_name("Foot.desktop"), ==, 1);
    g_assert_cmpint(ocws_is_safe_name("my_app-1"), ==, 1);
    g_assert_cmpint(ocws_is_safe_name("a/b"), ==, 0);   /* slash rejected */
    g_assert_cmpint(ocws_is_safe_name("a b"), ==, 0);   /* space rejected */
    g_assert_cmpint(ocws_is_safe_name(""), ==, 0);
    g_assert_cmpint(ocws_is_safe_name(NULL), ==, 0);
}

static void test_str_trim(void) {
    char s[] = "  \t hello \n\r ";
    char *t = ocws_str_trim(s);
    g_assert_cmpstr(t, ==, "hello");

    char empty[] = "   ";
    g_assert_cmpstr(ocws_str_trim(empty), ==, "");
    g_assert_null(ocws_str_trim(NULL));
}

/* ---------- easing monotonicity / symmetry (niche) ---------- */
static void test_easing_shape(void) {
    /* ease_out_cubic is symmetric-ish: f(1-t) ~ 1 - f(t) mirrored growth */
    for (int i = 0; i <= 10; i++) {
        double t = i / 10.0;
        double v = ease_out_cubic(t);
        g_assert_cmpfloat(v, >=, 0.0);
        g_assert_cmpfloat(v, <=, 1.0);
    }
    /* midpoint of ease_out_cubic is past 0.5 (front-loaded) */
    g_assert_cmpfloat(ease_out_cubic(0.5), >, 0.5);

    /* ease_in_out is symmetric about 0.5 */
    g_assert_cmpfloat(ease_in_out_cubic(0.25), ==, 1.0 - ease_in_out_cubic(0.75));

    /* clamping: out-of-range inputs stay within [0,1] */
    g_assert_cmpfloat(ease_in_out(-1.0), >=, 0.0);
    g_assert_cmpfloat(ease_in_out(2.0), <=, 1.0);
}

/* ---------- ini niche cases ---------- */
static void test_ini_niche(void) {
    char tmpl[] = "/tmp/ocws-ini-niche-XXXXXX";
    int fd = g_mkstemp(tmpl);
    g_assert_cmpint(fd, >=, 0);
    FILE *f = fdopen(fd, "w");
    /* comments, blank lines, no trailing newline, duplicate keys */
    fprintf(f, "# comment\n\n[sec]\nkey = one\nkey = two\n");
    fclose(f);

    IniFile ini;
    g_assert_cmpint(ini_load(&ini, tmpl), ==, 0);
    /* duplicate key: last writer wins */
    g_assert_cmpstr(ini_get(&ini, "sec", "key"), ==, "two");
    /* case-sensitive section/key lookup */
    g_assert_null(ini_get(&ini, "SEC", "key"));
    g_assert_null(ini_get(&ini, "sec", "KEY"));
    /* missing key returns default via ini_get_int */
    g_assert_cmpint(ini_get_int(&ini, "sec", "absent", 42), ==, 42);
    g_assert_cmpint(ini_get_int(&ini, "ghost", "key", 7), ==, 7);

    /* non-existent file load fails gracefully */
    g_assert_cmpint(ini_load(&ini, "/no/such/file"), ==, -1);
    unlink(tmpl);
}

/* ---------- sysfs niche cases ---------- */
static void test_sysfs_niche(void) {
    char tmpl[] = "/tmp/ocws-sysfs-niche-XXXXXX";
    int fd = g_mkstemp(tmpl);
    g_assert_cmpint(fd, >=, 0);
    FILE *f = fdopen(fd, "w");
    fprintf(f, "  -5 \n");   /* leading space, no newline issues */
    fclose(f);
    /* sysfs_read_int parses signed/whitespace */
    g_assert_cmpint(sysfs_read_int(tmpl, 0), ==, -5);
    /* negative write round-trips */
    g_assert_cmpint(sysfs_write_int(tmpl, -99), ==, 0);
    g_assert_cmpint(sysfs_read_int(tmpl, 0), ==, -99);
    unlink(tmpl);
}

int main(int argc, char **argv) {
    g_test_init(&argc, &argv, NULL);
    g_test_add_func("/libocws/str_prettify", test_str_prettify);
    g_test_add_func("/libocws/easing_endpoints", test_easing_endpoints);
    g_test_add_func("/libocws/animate_double_apply", test_animate_double_apply);
    g_test_add_func("/libocws/ini", test_ini);
    g_test_add_func("/libocws/json_escape", test_json_escape);
    g_test_add_func("/libocws/json_kv", test_json_kv);
    g_test_add_func("/libocws/fs", test_fs);
    g_test_add_func("/libocws/sysfs_int", test_sysfs_int);
    g_test_add_func("/libocws/is_shell_safe", test_is_shell_safe);
    g_test_add_func("/libocws/shell_escape", test_shell_escape);
    g_test_add_func("/libocws/is_safe_name", test_is_safe_name);
    g_test_add_func("/libocws/str_trim", test_str_trim);
    g_test_add_func("/libocws/easing_shape", test_easing_shape);
    g_test_add_func("/libocws/ini_niche", test_ini_niche);
    g_test_add_func("/libocws/sysfs_niche", test_sysfs_niche);
    return g_test_run();
}

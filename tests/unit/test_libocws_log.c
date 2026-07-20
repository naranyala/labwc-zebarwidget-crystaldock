/*
 * test_libocws_log.c — Tests for log.h (logging utility)
 *
 * Covers: ocws_log_msg, LOG_INFO/LOG_ERR/LOG_WARN macros,
 *         file creation, timestamp format, multi-line messages
 *
 * Compile: gcc -o test_libocws_log test_libocws_log.c -I../../src
 * Run:     ./test_libocws_log
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <unistd.h>
#include "../../src/libocws/log.h"

static int tests_run = 0;
static int tests_passed = 0;

#define TEST(name) do { tests_run++; printf("  test %-45s ", name); } while(0)
#define PASS() do { tests_passed++; printf("[PASS]\n"); } while(0)
#define FAIL(msg) do { printf("[FAIL] %s\n", msg); } while(0)
#define ASSERT(cond, msg) do { if (!(cond)) { FAIL(msg); return; } } while(0)

static const char *log_path = NULL;

static void cleanup_log(const char *app) {
    char path[512];
    const char *home = getenv("HOME");
    snprintf(path, sizeof(path), "%s/.cache/ocws-%s.log", home ? home : "/tmp", app);
    unlink(path);
}

static int file_contains(const char *path, const char *needle) {
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    char line[1024];
    int found = 0;
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, needle)) { found = 1; break; }
    }
    fclose(f);
    return found;
}

static void get_log_path(const char *app, char *buf, size_t len) {
    const char *home = getenv("HOME");
    snprintf(buf, len, "%s/.cache/ocws-%s.log", home ? home : "/tmp", app);
}

/* ======================================================================
 * Basic logging
 * ====================================================================== */

static void test_log_creates_file(void) {
    TEST("log: creates log file");
    cleanup_log("test_log_basic");
    ocws_log_msg("test_log_basic", "INFO", "test message");
    char path[512];
    get_log_path("test_log_basic", path, sizeof(path));
    ASSERT(access(path, F_OK) == 0, "log file should exist");
    cleanup_log("test_log_basic");
    PASS();
}

static void test_log_contains_message(void) {
    TEST("log: message appears in log file");
    cleanup_log("test_log_msg");
    ocws_log_msg("test_log_msg", "INFO", "hello world");
    char path[512];
    get_log_path("test_log_msg", path, sizeof(path));
    ASSERT(file_contains(path, "hello world"), "should contain 'hello world'");
    cleanup_log("test_log_msg");
    PASS();
}

static void test_log_contains_level(void) {
    TEST("log: level tag appears in log file");
    cleanup_log("test_log_level");
    ocws_log_msg("test_log_level", "ERROR", "something broke");
    char path[512];
    get_log_path("test_log_level", path, sizeof(path));
    ASSERT(file_contains(path, "[ERROR]"), "should contain '[ERROR]'");
    cleanup_log("test_log_level");
    PASS();
}

static void test_log_contains_timestamp(void) {
    TEST("log: timestamp in YYYY-MM-DD HH:MM:SS format");
    cleanup_log("test_log_time");
    ocws_log_msg("test_log_time", "INFO", "timestamp test");
    char path[512];
    get_log_path("test_log_time", path, sizeof(path));
    /* Check for a 4-digit year pattern */
    FILE *f = fopen(path, "r");
    ASSERT(f != NULL, "should open log");
    char line[1024];
    fgets(line, sizeof(line), f);
    fclose(f);
    /* Format: [2026-07-20 ...] [INFO] ... */
    ASSERT(line[0] == '[', "should start with [");
    ASSERT(line[5] == '-' && line[8] == '-', "should have YYYY-MM-DD format");
    cleanup_log("test_log_time");
    PASS();
}

static void test_log_macros(void) {
    TEST("log: LOG_INFO, LOG_ERR, LOG_WARN macros work");
    cleanup_log("test_log_macros");
    LOG_INFO("test_log_macros", "info msg %d", 42);
    LOG_ERR("test_log_macros", "err msg");
    LOG_WARN("test_log_macros", "warn msg");
    char path[512];
    get_log_path("test_log_macros", path, sizeof(path));
    ASSERT(file_contains(path, "[INFO] info msg 42"), "LOG_INFO should work");
    ASSERT(file_contains(path, "[ERROR] err msg"), "LOG_ERR should work");
    ASSERT(file_contains(path, "[WARN] warn msg"), "LOG_WARN should work");
    cleanup_log("test_log_macros");
    PASS();
}

static void test_log_append(void) {
    TEST("log: multiple calls append to same file");
    cleanup_log("test_log_append");
    ocws_log_msg("test_log_append", "INFO", "first");
    ocws_log_msg("test_log_append", "INFO", "second");
    ocws_log_msg("test_log_append", "INFO", "third");
    char path[512];
    get_log_path("test_log_append", path, sizeof(path));
    ASSERT(file_contains(path, "first"), "should contain 'first'");
    ASSERT(file_contains(path, "second"), "should contain 'second'");
    ASSERT(file_contains(path, "third"), "should contain 'third'");
    cleanup_log("test_log_append");
    PASS();
}

static void test_log_multiline(void) {
    TEST("log: message with newlines");
    cleanup_log("test_log_multi");
    ocws_log_msg("test_log_multi", "INFO", "line1\nline2");
    char path[512];
    get_log_path("test_log_multi", path, sizeof(path));
    ASSERT(file_contains(path, "line1"), "should contain 'line1'");
    ASSERT(file_contains(path, "line2"), "should contain 'line2'");
    cleanup_log("test_log_multi");
    PASS();
}

static void test_log_format_args(void) {
    TEST("log: printf-style formatting");
    cleanup_log("test_log_fmt");
    ocws_log_msg("test_log_fmt", "INFO", "name=%s count=%d", "test", 99);
    char path[512];
    get_log_path("test_log_fmt", path, sizeof(path));
    ASSERT(file_contains(path, "name=test count=99"), "should format args");
    cleanup_log("test_log_fmt");
    PASS();
}

int main(void) {
    printf("═══════════════════════════════════════════════════════════\n");
    printf(" test_libocws_log — log.h unit tests\n");
    printf("═══════════════════════════════════════════════════════════\n\n");

    printf("[ocws_log_msg]\n");
    test_log_creates_file();
    test_log_contains_message();
    test_log_contains_level();
    test_log_contains_timestamp();

    printf("\n[Macros]\n");
    test_log_macros();

    printf("\n[Behavior]\n");
    test_log_append();
    test_log_multiline();
    test_log_format_args();

    printf("\n═══════════════════════════════════════════════════════════\n");
    printf(" Results: %d/%d passed\n", tests_passed, tests_run);
    printf("═══════════════════════════════════════════════════════════\n");

    return tests_passed == tests_run ? 0 : 1;
}

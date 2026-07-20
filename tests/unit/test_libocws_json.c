/*
 * test_libocws_json.c — Tests for json.h (JSON escape, KV formatting)
 *
 * Covers: json_escape (quotes, backslash, newlines, tabs, control chars,
 *         truncation, empty, null), json_kv_string, json_kv_int, json_kv_bool
 *
 * Compile: gcc -o test_libocws_json test_libocws_json.c -I../../src
 * Run:     ./test_libocws_json
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "../../src/libocws/json.h"

static int tests_run = 0;
static int tests_passed = 0;

#define TEST(name) do { tests_run++; printf("  test %-45s ", name); } while(0)
#define PASS() do { tests_passed++; printf("[PASS]\n"); } while(0)
#define FAIL(msg) do { printf("[FAIL] %s\n", msg); } while(0)
#define ASSERT(cond, msg) do { if (!(cond)) { FAIL(msg); return; } } while(0)

/* ======================================================================
 * json_escape tests
 * ====================================================================== */

static void test_escape_plain(void) {
    TEST("json_escape: plain text passes through");
    char buf[256];
    json_escape(buf, sizeof(buf), "hello world");
    ASSERT(strcmp(buf, "hello world") == 0, "should pass through");
    PASS();
}

static void test_escape_double_quote(void) {
    TEST("json_escape: double quote escaped");
    char buf[256];
    json_escape(buf, sizeof(buf), "say \"hi\"");
    ASSERT(strcmp(buf, "say \\\"hi\\\"") == 0, "should escape double quotes");
    PASS();
}

static void test_escape_backslash(void) {
    TEST("json_escape: backslash escaped");
    char buf[256];
    json_escape(buf, sizeof(buf), "path\\to");
    ASSERT(strcmp(buf, "path\\\\to") == 0, "should escape backslash");
    PASS();
}

static void test_escape_newline(void) {
    TEST("json_escape: newline escaped");
    char buf[256];
    json_escape(buf, sizeof(buf), "line1\nline2");
    ASSERT(strcmp(buf, "line1\\nline2") == 0, "should escape newline");
    PASS();
}

static void test_escape_tab(void) {
    TEST("json_escape: tab escaped");
    char buf[256];
    json_escape(buf, sizeof(buf), "col1\tcol2");
    ASSERT(strcmp(buf, "col1\\tcol2") == 0, "should escape tab");
    PASS();
}

static void test_escape_mixed(void) {
    TEST("json_escape: mixed special characters");
    char buf[256];
    json_escape(buf, sizeof(buf), "a\"b\\c\nd\te");
    ASSERT(strcmp(buf, "a\\\"b\\\\c\\nd\\te") == 0, "should escape all");
    PASS();
}

static void test_escape_empty(void) {
    TEST("json_escape: empty string");
    char buf[256];
    json_escape(buf, sizeof(buf), "");
    ASSERT(strlen(buf) == 0, "should be empty");
    PASS();
}

static void test_escape_truncation(void) {
    TEST("json_escape: truncation at buffer boundary");
    char buf[8];
    json_escape(buf, sizeof(buf), "this is a very long string with \"quotes\"");
    ASSERT(strlen(buf) < sizeof(buf), "should be truncated");
    ASSERT(buf[strlen(buf)] == '\0', "should be null-terminated");
    PASS();
}

static void test_escape_carriage_return(void) {
    TEST("json_escape: carriage return NOT escaped (known limitation)");
    char buf[256];
    json_escape(buf, sizeof(buf), "a\rb");
    /* json_escape does NOT handle \r — it passes through raw.
     * This documents the known limitation. */
    ASSERT(strcmp(buf, "a\rb") == 0, "\\r passes through (known gap)");
    PASS();
}

static void test_escape_null_char(void) {
    TEST("json_escape: null char terminates early (known limitation)");
    char buf[256];
    json_escape(buf, sizeof(buf), "before\0after");
    ASSERT(strcmp(buf, "before") == 0, "stops at null char");
    PASS();
}

/* ======================================================================
 * json_kv_string tests
 * ====================================================================== */

static void test_kv_string_first(void) {
    TEST("json_kv_string: first entry (no leading comma)");
    char buf[256];
    json_kv_string(buf, sizeof(buf), "name", "Alice", 1);
    ASSERT(strcmp(buf, "\"name\": \"Alice\"") == 0, "should not have leading comma");
    PASS();
}

static void test_kv_string_not_first(void) {
    TEST("json_kv_string: subsequent entry (with leading comma)");
    char buf[256];
    json_kv_string(buf, sizeof(buf), "name", "Alice", 0);
    ASSERT(strcmp(buf, ", \"name\": \"Alice\"") == 0, "should have leading comma");
    PASS();
}

static void test_kv_string_with_escapes(void) {
    TEST("json_kv_string: value with characters needing escaping");
    char buf[256];
    json_kv_string(buf, sizeof(buf), "msg", "hello \"world\"", 1);
    ASSERT(strstr(buf, "\\\"world\\\"") != NULL, "quotes should be escaped");
    PASS();
}

static void test_kv_string_empty_value(void) {
    TEST("json_kv_string: empty value");
    char buf[256];
    json_kv_string(buf, sizeof(buf), "key", "", 1);
    ASSERT(strcmp(buf, "\"key\": \"\"") == 0, "should be empty string in JSON");
    PASS();
}

/* ======================================================================
 * json_kv_int tests
 * ====================================================================== */

static void test_kv_int_positive(void) {
    TEST("json_kv_int: positive integer");
    char buf[256];
    json_kv_int(buf, sizeof(buf), "count", 42, 1);
    ASSERT(strcmp(buf, "\"count\": 42") == 0, "should format as JSON int");
    PASS();
}

static void test_kv_int_zero(void) {
    TEST("json_kv_int: zero");
    char buf[256];
    json_kv_int(buf, sizeof(buf), "count", 0, 1);
    ASSERT(strcmp(buf, "\"count\": 0") == 0, "should be 0");
    PASS();
}

static void test_kv_int_negative(void) {
    TEST("json_kv_int: negative integer");
    char buf[256];
    json_kv_int(buf, sizeof(buf), "offset", -100, 1);
    ASSERT(strcmp(buf, "\"offset\": -100") == 0, "should handle negatives");
    PASS();
}

static void test_kv_int_not_first(void) {
    TEST("json_kv_int: with leading comma");
    char buf[256];
    json_kv_int(buf, sizeof(buf), "count", 42, 0);
    ASSERT(strcmp(buf, ", \"count\": 42") == 0, "should have leading comma");
    PASS();
}

/* ======================================================================
 * json_kv_bool tests
 * ====================================================================== */

static void test_kv_bool_true(void) {
    TEST("json_kv_bool: true");
    char buf[256];
    json_kv_bool(buf, sizeof(buf), "active", 1, 1);
    ASSERT(strcmp(buf, "\"active\": true") == 0, "should be 'true'");
    PASS();
}

static void test_kv_bool_false(void) {
    TEST("json_kv_bool: false");
    char buf[256];
    json_kv_bool(buf, sizeof(buf), "active", 0, 1);
    ASSERT(strcmp(buf, "\"active\": false") == 0, "should be 'false'");
    PASS();
}

static void test_kv_bool_not_first(void) {
    TEST("json_kv_bool: with leading comma");
    char buf[256];
    json_kv_bool(buf, sizeof(buf), "ok", 1, 0);
    ASSERT(strcmp(buf, ", \"ok\": true") == 0, "should have leading comma");
    PASS();
}

/* ======================================================================
 * Composition test: building a full JSON object
 * ====================================================================== */

static void test_compose_json_object(void) {
    TEST("compose: build complete JSON object from KV parts");
    char buf[1024] = "";
    char part[256];

    json_kv_string(part, sizeof(part), "name", "test-app", 1);
    strcat(buf, part);
    json_kv_int(part, sizeof(part), "pid", 12345, 0);
    strcat(buf, part);
    json_kv_bool(part, sizeof(part), "running", 1, 0);
    strcat(buf, part);
    json_kv_string(part, sizeof(part), "path", "/usr/bin/app", 0);
    strcat(buf, part);

    ASSERT(strstr(buf, "\"name\": \"test-app\"") != NULL, "has name");
    ASSERT(strstr(buf, "\"pid\": 12345") != NULL, "has pid");
    ASSERT(strstr(buf, "\"running\": true") != NULL, "has running");
    ASSERT(strstr(buf, "\"path\": \"/usr/bin/app\"") != NULL, "has path");
    /* Verify comma separation */
    ASSERT(buf[0] == '"', "first entry has no leading comma");
    ASSERT(strstr(buf, ", \"pid\"") != NULL, "second entry has comma");
    PASS();
}

int main(void) {
    printf("═══════════════════════════════════════════════════════════\n");
    printf(" test_libocws_json — json.h unit tests\n");
    printf("═══════════════════════════════════════════════════════════\n\n");

    printf("[json_escape]\n");
    test_escape_plain();
    test_escape_double_quote();
    test_escape_backslash();
    test_escape_newline();
    test_escape_tab();
    test_escape_mixed();
    test_escape_empty();
    test_escape_truncation();
    test_escape_carriage_return();
    test_escape_null_char();

    printf("\n[json_kv_string]\n");
    test_kv_string_first();
    test_kv_string_not_first();
    test_kv_string_with_escapes();
    test_kv_string_empty_value();

    printf("\n[json_kv_int]\n");
    test_kv_int_positive();
    test_kv_int_zero();
    test_kv_int_negative();
    test_kv_int_not_first();

    printf("\n[json_kv_bool]\n");
    test_kv_bool_true();
    test_kv_bool_false();
    test_kv_bool_not_first();

    printf("\n[Composition]\n");
    test_compose_json_object();

    printf("\n═══════════════════════════════════════════════════════════\n");
    printf(" Results: %d/%d passed\n", tests_passed, tests_run);
    printf("═══════════════════════════════════════════════════════════\n");

    return tests_passed == tests_run ? 0 : 1;
}

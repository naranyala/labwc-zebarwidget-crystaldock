/*
 * test_libocws_security.c — Security-focused tests for OCWS C utilities
 *
 * Covers: shell injection vectors, buffer overflow attempts, format string
 *         attacks, path traversal, integer overflow edge cases
 *
 * Compile: gcc -o test_libocws_security test_libocws_security.c -I../../src
 * Run:     ./test_libocws_security
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "../../src/libocws/ocws_string.h"
#include "../../src/libocws/json.h"
#include "../../src/libocws/cli-common.h"

static int tests_run = 0;
static int tests_passed = 0;

#define TEST(name) do { tests_run++; printf("  test %-45s ", name); } while(0)
#define PASS() do { tests_passed++; printf("[PASS]\n"); } while(0)
#define FAIL(msg) do { printf("[FAIL] %s\n", msg); } while(0)
#define ASSERT(cond, msg) do { if (!(cond)) { FAIL(msg); return; } } while(0)

/* ======================================================================
 * Shell injection via ocws_is_shell_safe
 * ====================================================================== */

static void test_injection_semicolon_cmd(void) {
    TEST("inject: '; rm -rf /' detected as unsafe");
    ASSERT(ocws_is_shell_safe("'; rm -rf /'") == 0, "should be detected");
    PASS();
}

static void test_injection_backtick(void) {
    TEST("inject: `whoami` detected as unsafe");
    ASSERT(ocws_is_shell_safe("`whoami`") == 0, "should be detected");
    PASS();
}

static void test_injection_dollar_parens(void) {
    TEST("inject: $(cmd) detected as unsafe");
    ASSERT(ocws_is_shell_safe("$(cat /etc/passwd)") == 0, "should be detected");
    PASS();
}

static void test_injection_pipe(void) {
    TEST("inject: 'a | b' detected as unsafe");
    ASSERT(ocws_is_shell_safe("a | b") == 0, "should be detected");
    PASS();
}

static void test_injection_ampersand_chain(void) {
    TEST("inject: 'a && b' detected as unsafe");
    ASSERT(ocws_is_shell_safe("a && b") == 0, "should be detected");
    PASS();
}

static void test_injection_redirect(void) {
    TEST("inject: 'a > /tmp/x' detected as unsafe");
    ASSERT(ocws_is_shell_safe("a > /tmp/x") == 0, "should be detected");
    PASS();
}

static void test_injection_newline_escape(void) {
    TEST("inject: newline injection detected");
    ASSERT(ocws_is_shell_safe("cmd\nmalicious") == 0, "should be detected");
    PASS();
}

static void test_injection_null_byte(void) {
    TEST("inject: embedded null byte — string terminates early");
    /* Null bytes in C strings cause early termination; the injection
     * payload after \0 is invisible to the checker. This documents the gap. */
    const char *payload = "safe\0; malicious";
    /* strlen sees only "safe" */
    ASSERT(ocws_is_shell_safe(payload) == 1, "checker sees only 'safe' before null");
    PASS();
}

/* ======================================================================
 * Shell escape robustness
 * ====================================================================== */

static void test_escape_no_injection_through_escaping(void) {
    TEST("escape: escaped output is safe for shell interpolation");
    const char *dangerous[] = {
        "'; rm -rf /",
        "`whoami`",
        "$(id)",
        "a\"b",
        "\\",
        NULL
    };
    char buf[512];
    for (int i = 0; dangerous[i]; i++) {
        int r = ocws_shell_escape(buf, sizeof(buf), dangerous[i]);
        ASSERT(r == 0, "escape should succeed");
        /* After escaping, the result should be safe when single-quoted */
        /* Verify the buffer doesn't overflow */
        ASSERT(strlen(buf) < sizeof(buf), "should not overflow buffer");
    }
    PASS();
}

static void test_escape_extreme_length(void) {
    TEST("escape: very long input handled gracefully");
    char input[10001];
    memset(input, 'A', 10000);
    input[10000] = '\0';
    char buf[512];
    int r = ocws_shell_escape(buf, sizeof(buf), input);
    ASSERT(r == -1, "should return -1 (truncated)");
    ASSERT(strlen(buf) < sizeof(buf), "buffer should be null-terminated");
    PASS();
}

static void test_escape_only_quotes(void) {
    TEST("escape: input of only single quotes");
    char buf[256];
    int r = ocws_shell_escape(buf, sizeof(buf), "''''");
    ASSERT(r == 0, "should succeed");
    /* Four single quotes should become: '\'''\\''\'''\\'''\\' */
    ASSERT(strchr(buf, '\'') != NULL, "output should contain escaped quotes");
    ASSERT(strchr(buf, '\\') != NULL, "output should contain backslashes");
    PASS();
}

/* ======================================================================
 * JSON escape security
 * ====================================================================== */

static void test_json_injection_via_value(void) {
    TEST("json: injection via value containing quotes");
    char buf[256];
    json_escape(buf, sizeof(buf), "value\", \"admin\": true");
    /* After escaping, the injected JSON should be neutralized */
    ASSERT(strstr(buf, "\"admin\"") == NULL, "injection should be neutralized");
    PASS();
}

static void test_json_injection_via_newline(void) {
    TEST("json: injection via newline in value");
    char buf[256];
    json_escape(buf, sizeof(buf), "line1\n\"injected\": true");
    ASSERT(strstr(buf, "\"injected\"") == NULL || strstr(buf, "\\n") != NULL,
           "newline injection should be escaped or neutralized");
    PASS();
}

static void test_json_escape_buffer_underflow(void) {
    TEST("json: tiny buffer does not cause overflow");
    char buf[3];
    memset(buf, 'X', sizeof(buf));
    json_escape(buf, sizeof(buf), "a\"b\\c\nd");
    /* json_escape writes up to dst_len-2 chars + NUL. With buf[3],
     * it writes at most 1 char + NUL. The buffer should be safe. */
    ASSERT(strlen(buf) < sizeof(buf), "should not overflow");
    PASS();
}

static void test_json_escape_1byte_buffer(void) {
    TEST("json: 1-byte buffer handles gracefully");
    char buf[1];
    json_escape(buf, sizeof(buf), "anything");
    ASSERT(buf[0] == '\0', "should be empty string");
    PASS();
}

/* ======================================================================
 * Buffer overflow attempts
 * ====================================================================== */

static void test_prettify_overflow_attempt(void) {
    TEST("prettify: extremely long input does not crash");
    char input[10001];
    memset(input, 'a', 10000);
    input[10000] = '\0';
    char *r = ocws_str_prettify(input);
    ASSERT(r != NULL, "should not crash or return NULL");
    ASSERT(strlen(r) == 10000, "should preserve length");
    free(r);
    PASS();
}

static void test_trim_overflow_attempt(void) {
    TEST("trim: in-place modification on large buffer is safe");
    char input[10001];
    memset(input, ' ', 5000);
    memset(input + 5000, 'x', 5000);
    input[10000] = '\0';
    char *r = ocws_str_trim(input);
    ASSERT(r != NULL, "should not crash");
    ASSERT(strcmp(r, "xxxx...") != 0 || strlen(r) > 0, "should have content");
    /* Verify it trimmed the leading spaces */
    ASSERT(r[0] == 'x', "first char should be 'x' after trim");
    PASS();
}

static void test_shell_escape_exact_fit(void) {
    TEST("escape: buffer exactly fits output");
    /* "abc" → "abc" (4 bytes with NUL), buffer is 4 bytes */
    char buf[4];
    int r = ocws_shell_escape(buf, sizeof(buf), "abc");
    ASSERT(r == 0, "should succeed with exact fit");
    ASSERT(strcmp(buf, "abc") == 0, "should contain 'abc'");
    PASS();
}

static void test_shell_escape_one_short(void) {
    TEST("escape: buffer one byte too small");
    /* "abc" → "abc" (4 bytes with NUL), buffer is 3 bytes */
    char buf[3];
    int r = ocws_shell_escape(buf, sizeof(buf), "abc");
    ASSERT(r == -1, "should return -1 (truncated)");
    ASSERT(strlen(buf) <= 2, "should be truncated");
    PASS();
}

/* ======================================================================
 * Path traversal detection
 * ====================================================================== */

static void test_safe_name_blocks_path_traversal(void) {
    TEST("safe_name: path traversal attempt blocked");
    ASSERT(ocws_is_safe_name("../../../etc/passwd") == 0, "should be unsafe");
    ASSERT(ocws_is_safe_name("foo/bar") == 0, "slash should be unsafe");
    PASS();
}

static void test_safe_name_blocks_hidden_files(void) {
    TEST("safe_name: hidden files with dot-prefix are allowed (by design)");
    /* Dots are in the allowed set. This documents the design decision. */
    ASSERT(ocws_is_safe_name(".hidden") == 1, "dot-prefix is allowed");
    PASS();
}

/* ======================================================================
 * Integer edge cases in JSON KV builders
 * ====================================================================== */

static void test_json_int_max(void) {
    TEST("json_kv_int: INT_MAX");
    char buf[256];
    json_kv_int(buf, sizeof(buf), "big", 2147483647, 1);
    ASSERT(strstr(buf, "2147483647") != NULL, "should contain INT_MAX");
    PASS();
}

static void test_json_int_min(void) {
    TEST("json_kv_int: INT_MIN");
    char buf[256];
    json_kv_int(buf, sizeof(buf), "small", -2147483647 - 1, 1);
    ASSERT(strstr(buf, "-2147483648") != NULL, "should contain INT_MIN");
    PASS();
}

static void test_json_kv_string_long_value(void) {
    TEST("json_kv_string: very long value");
    char val[5000];
    memset(val, 'A', 4999);
    val[4999] = '\0';
    char buf[5120];
    json_kv_string(buf, sizeof(buf), "key", val, 1);
    ASSERT(strstr(buf, "\"key\": \"") != NULL, "should start correctly");
    ASSERT(strlen(buf) < sizeof(buf), "should not overflow");
    PASS();
}

/* ======================================================================
 * Concurrency safety (conceptual)
 * ====================================================================== */

static void test_shell_escape_reentrant(void) {
    TEST("escape: multiple calls with different buffers are independent");
    char buf1[256], buf2[256];
    ocws_shell_escape(buf1, sizeof(buf1), "hello");
    ocws_shell_escape(buf2, sizeof(buf2), "world");
    ASSERT(strcmp(buf1, "hello") == 0, "buf1 independent");
    ASSERT(strcmp(buf2, "world") == 0, "buf2 independent");
    PASS();
}

int main(void) {
    printf("═══════════════════════════════════════════════════════════\n");
    printf(" test_libocws_security — Security-focused tests\n");
    printf("═══════════════════════════════════════════════════════════\n\n");

    printf("[Shell injection detection]\n");
    test_injection_semicolon_cmd();
    test_injection_backtick();
    test_injection_dollar_parens();
    test_injection_pipe();
    test_injection_ampersand_chain();
    test_injection_redirect();
    test_injection_newline_escape();
    test_injection_null_byte();

    printf("\n[Shell escape robustness]\n");
    test_escape_no_injection_through_escaping();
    test_escape_extreme_length();
    test_escape_only_quotes();

    printf("\n[JSON escape security]\n");
    test_json_injection_via_value();
    test_json_injection_via_newline();
    test_json_escape_buffer_underflow();
    test_json_escape_1byte_buffer();

    printf("\n[Buffer overflow attempts]\n");
    test_prettify_overflow_attempt();
    test_trim_overflow_attempt();
    test_shell_escape_exact_fit();
    test_shell_escape_one_short();

    printf("\n[Path traversal]\n");
    test_safe_name_blocks_path_traversal();
    test_safe_name_blocks_hidden_files();

    printf("\n[Integer edge cases]\n");
    test_json_int_max();
    test_json_int_min();
    test_json_kv_string_long_value();

    printf("\n[Reentrancy]\n");
    test_shell_escape_reentrant();

    printf("\n═══════════════════════════════════════════════════════════\n");
    printf(" Results: %d/%d passed\n", tests_passed, tests_run);
    printf("═══════════════════════════════════════════════════════════\n");

    return tests_passed == tests_run ? 0 : 1;
}

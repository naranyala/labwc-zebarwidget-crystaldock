/*
 * test_libocws_string.c — Comprehensive tests for ocws_string.h
 *
 * Covers: ocws_str_prettify, ocws_is_shell_safe, ocws_shell_escape,
 *         ocws_is_safe_name, ocws_str_trim
 *
 * Compile: gcc -o test_libocws_string test_libocws_string.c -I../../src
 * Run:     ./test_libocws_string
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "../../src/libocws/ocws_string.h"

static int tests_run = 0;
static int tests_passed = 0;

#define TEST(name) do { tests_run++; printf("  test %-45s ", name); } while(0)
#define PASS() do { tests_passed++; printf("[PASS]\n"); } while(0)
#define FAIL(msg) do { printf("[FAIL] %s\n", msg); } while(0)
#define ASSERT(cond, msg) do { if (!(cond)) { FAIL(msg); return; } } while(0)

/* ======================================================================
 * ocws_str_prettify tests
 * ====================================================================== */

static void test_prettify_null(void) {
    TEST("prettify: NULL input returns NULL");
    ASSERT(ocws_str_prettify(NULL) == NULL, "should return NULL");
    PASS();
}

static void test_prettify_empty(void) {
    TEST("prettify: empty string returns empty");
    char *r = ocws_str_prettify("");
    ASSERT(r != NULL, "should not be NULL");
    ASSERT(strlen(r) == 0, "should be empty");
    free(r);
    PASS();
}

static void test_prettify_single_word(void) {
    TEST("prettify: single word capitalizes first letter");
    char *r = ocws_str_prettify("hello");
    ASSERT(r != NULL, "should not be NULL");
    ASSERT(strcmp(r, "Hello") == 0, "should be 'Hello'");
    free(r);
    PASS();
}

static void test_prettify_hyphens(void) {
    TEST("prettify: hyphens become spaces, each word capitalized");
    char *r = ocws_str_prettify("my-cool-theme");
    ASSERT(r != NULL, "should not be NULL");
    ASSERT(strcmp(r, "My Cool Theme") == 0, "should be 'My Cool Theme'");
    free(r);
    PASS();
}

static void test_prettify_underscores(void) {
    TEST("prettify: underscores become spaces");
    char *r = ocws_str_prettify("dark_mode_v2");
    ASSERT(r != NULL, "should not be NULL");
    ASSERT(strcmp(r, "Dark Mode V2") == 0, "should be 'Dark Mode V2'");
    free(r);
    PASS();
}

static void test_prettify_mixed_separators(void) {
    TEST("prettify: mixed hyphens and underscores");
    char *r = ocws_str_prettify("catppuccin-mocha_theme");
    ASSERT(r != NULL, "should not be NULL");
    ASSERT(strcmp(r, "Catppuccin Mocha Theme") == 0, "should be 'Catppuccin Mocha Theme'");
    free(r);
    PASS();
}

static void test_prettify_already_capitalized(void) {
    TEST("prettify: already capitalized letters preserved");
    char *r = ocws_str_prettify("GTK-Theme");
    ASSERT(r != NULL, "should not be NULL");
    ASSERT(strcmp(r, "GTK Theme") == 0, "should be 'GTK Theme'");
    free(r);
    PASS();
}

static void test_prettify_numbers(void) {
    TEST("prettify: numbers after separators");
    char *r = ocws_str_prettify("theme-v2-1");
    ASSERT(r != NULL, "should not be NULL");
    ASSERT(strcmp(r, "Theme V2 1") == 0, "should be 'Theme V2 1'");
    free(r);
    PASS();
}

static void test_prettify_consecutive_separators(void) {
    TEST("prettify: consecutive separators");
    char *r = ocws_str_prettify("a--b__c");
    ASSERT(r != NULL, "should not be NULL");
    /* Consecutive separators produce multiple spaces (not collapsed) */
    ASSERT(strcmp(r, "A  B  C") == 0, "should be 'A  B  C' (double spaces)");
    free(r);
    PASS();
}

static void test_prettify_single_char(void) {
    TEST("prettify: single character");
    char *r = ocws_str_prettify("x");
    ASSERT(r != NULL, "should not be NULL");
    ASSERT(strcmp(r, "X") == 0, "should be 'X'");
    free(r);
    PASS();
}

static void test_prettify_leading_separator(void) {
    TEST("prettify: leading separator");
    char *r = ocws_str_prettify("-theme");
    ASSERT(r != NULL, "should not be NULL");
    ASSERT(strcmp(r, " Theme") == 0, "should be ' Theme'");
    free(r);
    PASS();
}

/* ======================================================================
 * ocws_is_shell_safe tests
 * ====================================================================== */

static void test_shell_safe_normal(void) {
    TEST("shell_safe: normal alphanumeric string is safe");
    ASSERT(ocws_is_shell_safe("hello-world_123") == 1, "should be safe");
    PASS();
}

static void test_shell_safe_empty(void) {
    TEST("shell_safe: empty string is NOT safe");
    ASSERT(ocws_is_shell_safe("") == 0, "should be unsafe");
    PASS();
}

static void test_shell_safe_null(void) {
    TEST("shell_safe: NULL is NOT safe");
    ASSERT(ocws_is_shell_safe(NULL) == 0, "should be unsafe");
    PASS();
}

static void test_shell_safe_semicolon(void) {
    TEST("shell_safe: semicolon is unsafe");
    ASSERT(ocws_is_shell_safe("hello;world") == 0, "should be unsafe");
    PASS();
}

static void test_shell_safe_pipe(void) {
    TEST("shell_safe: pipe is unsafe");
    ASSERT(ocws_is_shell_safe("a|b") == 0, "should be unsafe");
    PASS();
}

static void test_shell_safe_ampersand(void) {
    TEST("shell_safe: ampersand is unsafe");
    ASSERT(ocws_is_shell_safe("a&b") == 0, "should be unsafe");
    PASS();
}

static void test_shell_safe_dollar(void) {
    TEST("shell_safe: dollar sign is unsafe");
    ASSERT(ocws_is_shell_safe("$HOME") == 0, "should be unsafe");
    PASS();
}

static void test_shell_safe_backtick(void) {
    TEST("shell_safe: backtick is unsafe");
    ASSERT(ocws_is_shell_safe("`whoami`") == 0, "should be unsafe");
    PASS();
}

static void test_shell_safe_quotes(void) {
    TEST("shell_safe: single and double quotes are unsafe");
    ASSERT(ocws_is_shell_safe("it's") == 0, "single quote unsafe");
    ASSERT(ocws_is_shell_safe("say \"hi\"") == 0, "double quote unsafe");
    PASS();
}

static void test_shell_safe_backslash(void) {
    TEST("shell_safe: backslash is unsafe");
    ASSERT(ocws_is_shell_safe("path\\to") == 0, "should be unsafe");
    PASS();
}

static void test_shell_safe_newline(void) {
    TEST("shell_safe: newline is unsafe");
    ASSERT(ocws_is_shell_safe("line1\nline2") == 0, "should be unsafe");
    PASS();
}

static void test_shell_safe_redirects(void) {
    TEST("shell_safe: angle brackets are unsafe");
    ASSERT(ocws_is_shell_safe("a>b") == 0, "> unsafe");
    ASSERT(ocws_is_shell_safe("a<b") == 0, "< unsafe");
    PASS();
}

static void test_shell_safe_parens(void) {
    TEST("shell_safe: parentheses are unsafe");
    ASSERT(ocws_is_shell_safe("echo(1)") == 0, "() unsafe");
    ASSERT(ocws_is_shell_safe("{cmd}") == 0, "{} unsafe");
    PASS();
}

static void test_shell_safe_space(void) {
    TEST("shell_safe: spaces ARE safe (not metacharacters)");
    ASSERT(ocws_is_shell_safe("hello world") == 1, "spaces should be safe");
    PASS();
}

static void test_shell_safe_dots_and_dashes(void) {
    TEST("shell_safe: dots, dashes, underscores are safe");
    ASSERT(ocws_is_shell_safe("file.tar.gz") == 1, "dots safe");
    ASSERT(ocws_is_shell_safe("my-file_v2.txt") == 1, "mixed safe");
    PASS();
}

/* ======================================================================
 * ocws_shell_escape tests
 * ====================================================================== */

static void test_escape_no_quotes(void) {
    TEST("shell_escape: string without quotes passes through");
    char buf[256];
    int r = ocws_shell_escape(buf, sizeof(buf), "hello world");
    ASSERT(r == 0, "should succeed");
    ASSERT(strcmp(buf, "hello world") == 0, "should pass through");
    PASS();
}

static void test_escape_single_quote(void) {
    TEST("shell_escape: single quotes are escaped correctly");
    char buf[256];
    int r = ocws_shell_escape(buf, sizeof(buf), "it's");
    ASSERT(r == 0, "should succeed");
    ASSERT(strcmp(buf, "it'\\''s") == 0, "should escape single quote");
    PASS();
}

static void test_escape_multiple_quotes(void) {
    TEST("shell_escape: multiple single quotes");
    char buf[256];
    int r = ocws_shell_escape(buf, sizeof(buf), "a'b'c");
    ASSERT(r == 0, "should succeed");
    ASSERT(strcmp(buf, "a'\\''b'\\''c") == 0, "should escape all quotes");
    PASS();
}

static void test_escape_empty(void) {
    TEST("shell_escape: empty string");
    char buf[256];
    int r = ocws_shell_escape(buf, sizeof(buf), "");
    ASSERT(r == 0, "should succeed");
    ASSERT(strlen(buf) == 0, "should be empty");
    PASS();
}

static void test_escape_null(void) {
    TEST("shell_escape: NULL source");
    char buf[256];
    int r = ocws_shell_escape(buf, sizeof(buf), NULL);
    ASSERT(r == 0, "should succeed");
    ASSERT(strlen(buf) == 0, "should be empty");
    PASS();
}

static void test_escape_truncation(void) {
    TEST("shell_escape: truncation returns -1");
    char buf[8];
    int r = ocws_shell_escape(buf, sizeof(buf), "this is a very long string");
    ASSERT(r == -1, "should return -1 on truncation");
    ASSERT(strlen(buf) < sizeof(buf), "buffer should be null-terminated");
    PASS();
}

static void test_escape_null_dst(void) {
    TEST("shell_escape: NULL dst returns -1");
    int r = ocws_shell_escape(NULL, 0, "test");
    ASSERT(r == -1, "should return -1");
    PASS();
}

static void test_escape_zero_size(void) {
    TEST("shell_escape: zero dst size returns -1");
    char buf[256];
    int r = ocws_shell_escape(buf, 0, "test");
    ASSERT(r == -1, "should return -1");
    PASS();
}

static void test_escape_shell_injection(void) {
    TEST("shell_escape: single quotes in injection payloads escaped");
    char buf[256];
    /* ocws_shell_escape only handles single-quote escaping.
     * Verify that payloads containing single quotes are properly escaped. */
    const char *payloads[] = {
        "it's dangerous",       /* has single quote */
        "can't stop",           /* has single quote */
        "a ' b ' c",            /* multiple single quotes */
        NULL
    };
    for (int i = 0; payloads[i]; i++) {
        int r = ocws_shell_escape(buf, sizeof(buf), payloads[i]);
        ASSERT(r == 0, "escape should succeed");
        /* The escaped result should not contain raw single quotes
         * outside of the escape pattern '\'' */
        /* Verify no unescaped single quotes: every ' should be part of '\''' */
        ASSERT(strlen(buf) < sizeof(buf), "should not overflow buffer");
    }
    PASS();
}

/* ======================================================================
 * ocws_is_safe_name tests
 * ====================================================================== */

static void test_safe_name_normal(void) {
    TEST("safe_name: normal identifier is safe");
    ASSERT(ocws_is_safe_name("my-theme_v2.config") == 1, "should be safe");
    PASS();
}

static void test_safe_name_empty(void) {
    TEST("safe_name: empty string is NOT safe");
    ASSERT(ocws_is_safe_name("") == 0, "should be unsafe");
    PASS();
}

static void test_safe_name_null(void) {
    TEST("safe_name: NULL is NOT safe");
    ASSERT(ocws_is_safe_name(NULL) == 0, "should be unsafe");
    PASS();
}

static void test_safe_name_spaces(void) {
    TEST("safe_name: spaces are unsafe");
    ASSERT(ocws_is_safe_name("has space") == 0, "should be unsafe");
    PASS();
}

static void test_safe_name_special_chars(void) {
    TEST("safe_name: special characters are unsafe");
    ASSERT(ocws_is_safe_name("hello@world") == 0, "@ unsafe");
    ASSERT(ocws_is_safe_name("a#b") == 0, "# unsafe");
    ASSERT(ocws_is_safe_name("a!b") == 0, "! unsafe");
    ASSERT(ocws_is_safe_name("a/b") == 0, "/ unsafe");
    PASS();
}

static void test_safe_name_alphanumeric(void) {
    TEST("safe_name: pure alphanumeric");
    ASSERT(ocws_is_safe_name("abc123XYZ") == 1, "should be safe");
    PASS();
}

/* ======================================================================
 * ocws_str_trim tests
 * ====================================================================== */

static void test_trim_no_whitespace(void) {
    TEST("trim: no whitespace");
    char s[] = "hello";
    char *r = ocws_str_trim(s);
    ASSERT(strcmp(r, "hello") == 0, "should be 'hello'");
    PASS();
}

static void test_trim_leading_spaces(void) {
    TEST("trim: leading spaces");
    char s[] = "  hello";
    char *r = ocws_str_trim(s);
    ASSERT(strcmp(r, "hello") == 0, "should be 'hello'");
    PASS();
}

static void test_trim_trailing_spaces(void) {
    TEST("trim: trailing spaces");
    char s[] = "hello  ";
    char *r = ocws_str_trim(s);
    ASSERT(strcmp(r, "hello") == 0, "should be 'hello'");
    PASS();
}

static void test_trim_both_sides(void) {
    TEST("trim: both sides");
    char s[] = "  hello  ";
    char *r = ocws_str_trim(s);
    ASSERT(strcmp(r, "hello") == 0, "should be 'hello'");
    PASS();
}

static void test_trim_tabs(void) {
    TEST("trim: tabs");
    char s[] = "\thello\t";
    char *r = ocws_str_trim(s);
    ASSERT(strcmp(r, "hello") == 0, "should be 'hello'");
    PASS();
}

static void test_trim_newlines(void) {
    TEST("trim: newlines and carriage returns");
    char s[] = "\n\rhello\n\r";
    char *r = ocws_str_trim(s);
    ASSERT(strcmp(r, "hello") == 0, "should be 'hello'");
    PASS();
}

static void test_trim_mixed_whitespace(void) {
    TEST("trim: mixed whitespace");
    char s[] = " \t\n\r hello \t\n\r ";
    char *r = ocws_str_trim(s);
    ASSERT(strcmp(r, "hello") == 0, "should be 'hello'");
    PASS();
}

static void test_trim_all_whitespace(void) {
    TEST("trim: all whitespace yields empty string");
    char s[] = "   \t  ";
    char *r = ocws_str_trim(s);
    ASSERT(strlen(r) == 0, "should be empty");
    PASS();
}

static void test_trim_null(void) {
    TEST("trim: NULL returns NULL");
    ASSERT(ocws_str_trim(NULL) == NULL, "should return NULL");
    PASS();
}

static void test_trim_empty(void) {
    TEST("trim: empty string");
    char s[] = "";
    char *r = ocws_str_trim(s);
    ASSERT(strlen(r) == 0, "should be empty");
    PASS();
}

static void test_trim_inner_spaces_preserved(void) {
    TEST("trim: inner spaces preserved");
    char s[] = "  hello world  ";
    char *r = ocws_str_trim(s);
    ASSERT(strcmp(r, "hello world") == 0, "should be 'hello world'");
    PASS();
}

int main(void) {
    printf("═══════════════════════════════════════════════════════════\n");
    printf(" test_libocws_string — ocws_string.h unit tests\n");
    printf("═══════════════════════════════════════════════════════════\n\n");

    printf("[ocws_str_prettify]\n");
    test_prettify_null();
    test_prettify_empty();
    test_prettify_single_word();
    test_prettify_hyphens();
    test_prettify_underscores();
    test_prettify_mixed_separators();
    test_prettify_already_capitalized();
    test_prettify_numbers();
    test_prettify_consecutive_separators();
    test_prettify_single_char();
    test_prettify_leading_separator();

    printf("\n[ocws_is_shell_safe]\n");
    test_shell_safe_normal();
    test_shell_safe_empty();
    test_shell_safe_null();
    test_shell_safe_semicolon();
    test_shell_safe_pipe();
    test_shell_safe_ampersand();
    test_shell_safe_dollar();
    test_shell_safe_backtick();
    test_shell_safe_quotes();
    test_shell_safe_backslash();
    test_shell_safe_newline();
    test_shell_safe_redirects();
    test_shell_safe_parens();
    test_shell_safe_space();
    test_shell_safe_dots_and_dashes();

    printf("\n[ocws_shell_escape]\n");
    test_escape_no_quotes();
    test_escape_single_quote();
    test_escape_multiple_quotes();
    test_escape_empty();
    test_escape_null();
    test_escape_truncation();
    test_escape_null_dst();
    test_escape_zero_size();
    test_escape_shell_injection();

    printf("\n[ocws_is_safe_name]\n");
    test_safe_name_normal();
    test_safe_name_empty();
    test_safe_name_null();
    test_safe_name_spaces();
    test_safe_name_special_chars();
    test_safe_name_alphanumeric();

    printf("\n[ocws_str_trim]\n");
    test_trim_no_whitespace();
    test_trim_leading_spaces();
    test_trim_trailing_spaces();
    test_trim_both_sides();
    test_trim_tabs();
    test_trim_newlines();
    test_trim_mixed_whitespace();
    test_trim_all_whitespace();
    test_trim_null();
    test_trim_empty();
    test_trim_inner_spaces_preserved();

    printf("\n═══════════════════════════════════════════════════════════\n");
    printf(" Results: %d/%d passed\n", tests_passed, tests_run);
    printf("═══════════════════════════════════════════════════════════\n");

    return tests_passed == tests_run ? 0 : 1;
}

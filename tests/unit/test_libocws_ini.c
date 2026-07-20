/*
 * test_libocws_ini.c — Tests for ini.h (INI parser)
 *
 * Covers: ini_load, ini_get, ini_get_int, edge cases (comments, empty,
 *         whitespace, overflow, missing sections, duplicate keys)
 *
 * Compile: gcc -o test_libocws_ini test_libocws_ini.c -I../../src
 * Run:     ./test_libocws_ini
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <assert.h>
#include "../../src/libocws/ini.h"

static int tests_run = 0;
static int tests_passed = 0;

#define TEST(name) do { tests_run++; printf("  test %-45s ", name); } while(0)
#define PASS() do { tests_passed++; printf("[PASS]\n"); } while(0)
#define FAIL(msg) do { printf("[FAIL] %s\n", msg); } while(0)
#define ASSERT(cond, msg) do { if (!(cond)) { FAIL(msg); return; } } while(0)

static const char *tmpdir = "/tmp/ocws_ini_test";

static void write_file(const char *path, const char *content) {
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "mkdir -p %s && cat > %s", tmpdir, path);
    FILE *f = popen(cmd, "w");
    if (f) { fputs(content, f); pclose(f); }
}

/* ======================================================================
 * Basic loading
 * ====================================================================== */

static void test_load_nonexistent(void) {
    TEST("load: nonexistent file returns -1");
    IniFile ini;
    int r = ini_load(&ini, "/nonexistent/path/that/does/not/exist.ini");
    ASSERT(r == -1, "should return -1");
    PASS();
}

static void test_load_simple(void) {
    TEST("load: simple key=value");
    write_file("/tmp/ocws_ini_test/simple.ini",
        "[section1]\nkey1=value1\nkey2=value2\n");
    IniFile ini;
    int r = ini_load(&ini, "/tmp/ocws_ini_test/simple.ini");
    ASSERT(r == 0, "should succeed");
    ASSERT(ini.section_count == 1, "should have 1 section");
    ASSERT(strcmp(ini.sections[0].name, "section1") == 0, "section name correct");
    ASSERT(ini.sections[0].key_count == 2, "should have 2 keys");
    ASSERT(strcmp(ini.sections[0].keys[0].key, "key1") == 0, "key1 name");
    ASSERT(strcmp(ini.sections[0].keys[0].value, "value1") == 0, "key1 value");
    PASS();
}

static void test_load_multiple_sections(void) {
    TEST("load: multiple sections");
    write_file("/tmp/ocws_ini_test/multi.ini",
        "[general]\nname=test\n\n[appearance]\ntheme=dark\nfont=mono\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/multi.ini");
    ASSERT(ini.section_count == 2, "should have 2 sections");
    ASSERT(strcmp(ini.sections[0].name, "general") == 0, "first section");
    ASSERT(strcmp(ini.sections[1].name, "appearance") == 0, "second section");
    ASSERT(ini.sections[1].key_count == 2, "appearance has 2 keys");
    PASS();
}

static void test_load_comments(void) {
    TEST("load: comment lines are skipped");
    write_file("/tmp/ocws_ini_test/comments.ini",
        "; this is a comment\n[section]\n# another comment\nkey=val\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/comments.ini");
    ASSERT(ini.section_count == 1, "1 section");
    ASSERT(ini.sections[0].key_count == 1, "1 key (comments skipped)");
    ASSERT(strcmp(ini.sections[0].keys[0].key, "key") == 0, "key name");
    ASSERT(strcmp(ini.sections[0].keys[0].value, "val") == 0, "key value");
    PASS();
}

static void test_load_empty_lines(void) {
    TEST("load: empty lines are ignored");
    write_file("/tmp/ocws_ini_test/empty.ini",
        "\n\n[section]\n\n\nkey=val\n\n\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/empty.ini");
    ASSERT(ini.section_count == 1, "1 section");
    ASSERT(ini.sections[0].key_count == 1, "1 key");
    PASS();
}

static void test_load_whitespace_trimmed(void) {
    TEST("load: whitespace is trimmed from keys and values");
    write_file("/tmp/ocws_ini_test/whitespace.ini",
        "[ section ]\n  key  =  value  \n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/whitespace.ini");
    ASSERT(ini.section_count == 1, "1 section");
    ASSERT(strcmp(ini.sections[0].name, "section") == 0, "section name trimmed");
    ASSERT(strcmp(ini.sections[0].keys[0].key, "key") == 0, "key trimmed");
    ASSERT(strcmp(ini.sections[0].keys[0].value, "value") == 0, "value trimmed");
    PASS();
}

static void test_load_value_with_equals(void) {
    TEST("load: value containing = characters");
    write_file("/tmp/ocws_ini_test/equals.ini",
        "[test]\nformula=a=b=c\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/equals.ini");
    ASSERT(strcmp(ini.sections[0].keys[0].value, "a=b=c") == 0, "value should be 'a=b=c'");
    PASS();
}

static void test_load_value_empty(void) {
    TEST("load: empty value");
    write_file("/tmp/ocws_ini_test/emptyval.ini",
        "[test]\nkey=\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/emptyval.ini");
    ASSERT(strcmp(ini.sections[0].keys[0].value, "") == 0, "value should be empty");
    PASS();
}

static void test_load_no_section(void) {
    TEST("load: keys before any section are ignored");
    write_file("/tmp/ocws_ini_test/nosection.ini",
        "orphan_key=orphan_value\n[section]\nkey=val\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/nosection.ini");
    ASSERT(ini.section_count == 1, "1 section");
    ASSERT(ini.sections[0].key_count == 1, "only the section key, orphan dropped");
    PASS();
}

static void test_load_line_without_equals(void) {
    TEST("load: lines without = are ignored");
    write_file("/tmp/ocws_ini_test/noequals.ini",
        "[test]\nvalid_key=valid_value\njust_a_line\nanother=ok\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/noequals.ini");
    ASSERT(ini.sections[0].key_count == 2, "only valid key=value pairs kept");
    PASS();
}

/* ======================================================================
 * ini_get tests
 * ====================================================================== */

static void test_get_existing(void) {
    TEST("get: existing key");
    write_file("/tmp/ocws_ini_test/get.ini",
        "[app]\nname=myapp\nversion=1.0\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/get.ini");
    const char *v = ini_get(&ini, "app", "name");
    ASSERT(v != NULL, "should find key");
    ASSERT(strcmp(v, "myapp") == 0, "should be 'myapp'");
    PASS();
}

static void test_get_nonexistent_key(void) {
    TEST("get: nonexistent key returns NULL");
    write_file("/tmp/ocws_ini_test/get.ini",
        "[app]\nname=myapp\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/get.ini");
    const char *v = ini_get(&ini, "app", "nonexistent");
    ASSERT(v == NULL, "should return NULL");
    PASS();
}

static void test_get_nonexistent_section(void) {
    TEST("get: nonexistent section returns NULL");
    write_file("/tmp/ocws_ini_test/get.ini",
        "[app]\nname=myapp\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/get.ini");
    const char *v = ini_get(&ini, "nope", "name");
    ASSERT(v == NULL, "should return NULL");
    PASS();
}

/* ======================================================================
 * ini_get_int tests
 * ====================================================================== */

static void test_get_int_existing(void) {
    TEST("get_int: existing integer value");
    write_file("/tmp/ocws_ini_test/int.ini",
        "[settings]\nwidth=1920\nheight=1080\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/int.ini");
    ASSERT(ini_get_int(&ini, "settings", "width", 0) == 1920, "should be 1920");
    ASSERT(ini_get_int(&ini, "settings", "height", 0) == 1080, "should be 1080");
    PASS();
}

static void test_get_int_missing_returns_default(void) {
    TEST("get_int: missing key returns default");
    write_file("/tmp/ocws_ini_test/int.ini",
        "[settings]\nwidth=1920\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/int.ini");
    ASSERT(ini_get_int(&ini, "settings", "missing", 42) == 42, "should return default 42");
    PASS();
}

static void test_get_int_negative(void) {
    TEST("get_int: negative value");
    write_file("/tmp/ocws_ini_test/int.ini",
        "[settings]\noffset=-50\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/int.ini");
    ASSERT(ini_get_int(&ini, "settings", "offset", 0) == -50, "should be -50");
    PASS();
}

static void test_get_int_non_numeric(void) {
    TEST("get_int: non-numeric value returns 0 (atoi behavior)");
    write_file("/tmp/ocws_ini_test/int.ini",
        "[settings]\nname=hello\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/int.ini");
    ASSERT(ini_get_int(&ini, "settings", "name", 99) == 0, "atoi of 'hello' is 0");
    PASS();
}

/* ======================================================================
 * Edge cases
 * ====================================================================== */

static void test_load_empty_file(void) {
    TEST("load: empty file");
    write_file("/tmp/ocws_ini_test/empty.ini", "");
    IniFile ini;
    int r = ini_load(&ini, "/tmp/ocws_ini_test/empty.ini");
    ASSERT(r == 0, "should succeed");
    ASSERT(ini.section_count == 0, "no sections");
    PASS();
}

static void test_load_section_without_keys(void) {
    TEST("load: section with no keys");
    write_file("/tmp/ocws_ini_test/emptysec.ini",
        "[empty]\n[populated]\nkey=val\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/emptysec.ini");
    ASSERT(ini.section_count == 2, "2 sections");
    ASSERT(ini.sections[0].key_count == 0, "empty section has 0 keys");
    ASSERT(ini.sections[1].key_count == 1, "populated section has 1 key");
    PASS();
}

static void test_load_duplicate_keys(void) {
    TEST("load: duplicate keys — last writer wins");
    write_file("/tmp/ocws_ini_test/dup.ini",
        "[test]\nkey=first\nkey=second\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/dup.ini");
    const char *v = ini_get(&ini, "test", "key");
    ASSERT(v != NULL, "should find key");
    ASSERT(strcmp(v, "second") == 0, "last writer should win");
    PASS();
}

static void test_load_many_sections(void) {
    TEST("load: approaches max sections (32)");
    char buf[4096] = "";
    for (int i = 0; i < 32; i++) {
        char line[128];
        snprintf(line, sizeof(line), "[section%d]\nkey%d=val%d\n", i, i, i);
        strcat(buf, line);
    }
    write_file("/tmp/ocws_ini_test/maxsec.ini", buf);
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/maxsec.ini");
    ASSERT(ini.section_count == 32, "should have 32 sections");
    PASS();
}

static void test_load_overflow_sections(void) {
    TEST("load: >32 sections silently drops extras");
    char buf[8192] = "";
    for (int i = 0; i < 40; i++) {
        char line[128];
        snprintf(line, sizeof(line), "[section%d]\nkey=val\n", i);
        strcat(buf, line);
    }
    write_file("/tmp/ocws_ini_test/overflow.ini", buf);
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/overflow.ini");
    ASSERT(ini.section_count == 32, "capped at INI_MAX_SECTIONS");
    PASS();
}

static void test_load_long_value(void) {
    TEST("load: value exceeding INI_VAL_LEN (256) is truncated");
    char longval[300];
    memset(longval, 'A', 299);
    longval[299] = '\0';
    char content[512];
    snprintf(content, sizeof(content), "[test]\nkey=%s\n", longval);
    write_file("/tmp/ocws_ini_test/longval.ini", content);
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/longval.ini");
    const char *v = ini_get(&ini, "test", "key");
    ASSERT(v != NULL, "should find key");
    ASSERT(strlen(v) <= 255, "value should be truncated to 255 chars");
    PASS();
}

static void test_load_special_characters_in_value(void) {
    TEST("load: special characters in value");
    write_file("/tmp/ocws_ini_test/special.ini",
        "[test]\npath=/home/user/.config/app\nurl=https://example.com?q=1&r=2\n");
    IniFile ini;
    ini_load(&ini, "/tmp/ocws_ini_test/special.ini");
    ASSERT(strcmp(ini_get(&ini, "test", "path"), "/home/user/.config/app") == 0, "path ok");
    ASSERT(strcmp(ini_get(&ini, "test", "url"), "https://example.com?q=1&r=2") == 0, "url ok");
    PASS();
}

int main(void) {
    printf("═══════════════════════════════════════════════════════════\n");
    printf(" test_libocws_ini — ini.h unit tests\n");
    printf("═══════════════════════════════════════════════════════════\n\n");

    /* Setup */
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "rm -rf %s && mkdir -p %s", tmpdir, tmpdir);
    system(cmd);

    printf("[ini_load]\n");
    test_load_nonexistent();
    test_load_simple();
    test_load_multiple_sections();
    test_load_comments();
    test_load_empty_lines();
    test_load_whitespace_trimmed();
    test_load_value_with_equals();
    test_load_value_empty();
    test_load_no_section();
    test_load_line_without_equals();

    printf("\n[ini_get]\n");
    test_get_existing();
    test_get_nonexistent_key();
    test_get_nonexistent_section();

    printf("\n[ini_get_int]\n");
    test_get_int_existing();
    test_get_int_missing_returns_default();
    test_get_int_negative();
    test_get_int_non_numeric();

    printf("\n[Edge cases]\n");
    test_load_empty_file();
    test_load_section_without_keys();
    test_load_duplicate_keys();
    test_load_many_sections();
    test_load_overflow_sections();
    test_load_long_value();
    test_load_special_characters_in_value();

    /* Cleanup */
    snprintf(cmd, sizeof(cmd), "rm -rf %s", tmpdir);
    system(cmd);

    printf("\n═══════════════════════════════════════════════════════════\n");
    printf(" Results: %d/%d passed\n", tests_passed, tests_run);
    printf("═══════════════════════════════════════════════════════════\n");

    return tests_passed == tests_run ? 0 : 1;
}

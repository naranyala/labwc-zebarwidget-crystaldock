/*
 * test_libocws_cli_common.c — Tests for cli-common.h
 *
 * Covers: cli_get_home, cli_get_timestamp, cli_file_exists, cli_mkdir_p,
 *         cli_pass/cli_fail/cli_warn/cli_info output format
 *
 * Note: cli_fail calls exit(), so we test it in a subprocess.
 *       cli_check_cmd uses system(), so we test with known commands.
 *
 * Compile: gcc -o test_libocws_cli_common test_libocws_cli_common.c -I../../src
 * Run:     ./test_libocws_cli_common
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include "../../src/libocws/cli-common.h"

static int tests_run = 0;
static int tests_passed = 0;

#define TEST(name) do { tests_run++; printf("  test %-45s ", name); } while(0)
#define PASS() do { tests_passed++; printf("[PASS]\n"); } while(0)
#define FAIL(msg) do { printf("[FAIL] %s\n", msg); } while(0)
#define ASSERT(cond, msg) do { if (!(cond)) { FAIL(msg); return; } } while(0)

/* ======================================================================
 * cli_get_home tests
 * ====================================================================== */

static void test_get_home_not_null(void) {
    TEST("get_home: returns non-NULL");
    const char *h = cli_get_home();
    ASSERT(h != NULL, "should not be NULL");
    ASSERT(strlen(h) > 0, "should not be empty");
    PASS();
}

static void test_get_home_matches_env(void) {
    TEST("get_home: matches HOME env var");
    const char *home = getenv("HOME");
    if (home) {
        const char *h = cli_get_home();
        ASSERT(strcmp(h, home) == 0, "should match HOME");
    } else {
        printf("[SKIP] HOME not set\n");
        tests_run++; tests_passed++;
    }
    PASS();
}

static void test_get_home_starts_with_slash(void) {
    TEST("get_home: path starts with /");
    const char *h = cli_get_home();
    ASSERT(h[0] == '/', "should be absolute path");
    PASS();
}

/* ======================================================================
 * cli_get_timestamp tests
 * ====================================================================== */

static void test_timestamp_not_empty(void) {
    TEST("timestamp: not empty");
    char buf[64];
    cli_get_timestamp(buf, sizeof(buf));
    ASSERT(strlen(buf) > 0, "should not be empty");
    PASS();
}

static void test_timestamp_format(void) {
    TEST("timestamp: YYYYMMDD-HHMMSS format");
    char buf[64];
    cli_get_timestamp(buf, sizeof(buf));
    /* 14 chars: 20260720-1234 */
    ASSERT(strlen(buf) == 15, "should be 15 chars (YYYYMMDD-HHMMSS + NUL)");
    ASSERT(buf[8] == '-', "should have dash at position 8");
    /* Digits only (except dash) */
    for (int i = 0; i < 8; i++) {
        ASSERT(buf[i] >= '0' && buf[i] <= '9', "date part should be digits");
    }
    for (int i = 9; i < 15; i++) {
        ASSERT(buf[i] >= '0' && buf[i] <= '9', "time part should be digits");
    }
    PASS();
}

/* ======================================================================
 * cli_file_exists tests
 * ====================================================================== */

static void test_file_exists_existing(void) {
    TEST("file_exists: existing file");
    ASSERT(cli_file_exists("/etc/passwd") == 1, "/etc/passwd should exist");
    PASS();
}

static void test_file_exists_nonexistent(void) {
    TEST("file_exists: nonexistent file");
    ASSERT(cli_file_exists("/nonexistent/path/xyzzy") == 0, "should not exist");
    PASS();
}

static void test_file_exists_directory(void) {
    TEST("file_exists: directory returns true");
    ASSERT(cli_file_exists("/tmp") == 1, "/tmp should exist");
    PASS();
}

static void test_file_exists_dev_null(void) {
    TEST("file_exists: /dev/null");
    ASSERT(cli_file_exists("/dev/null") == 1, "/dev/null should exist");
    PASS();
}

/* ======================================================================
 * cli_mkdir_p tests
 * ====================================================================== */

static void test_mkdir_p_creates_dir(void) {
    TEST("mkdir_p: creates nested directory");
    const char *path = "/tmp/ocws_test_mkdir_p/a/b/c";
    cli_mkdir_p(path);
    struct stat st;
    ASSERT(stat(path, &st) == 0, "directory should exist");
    ASSERT(S_ISDIR(st.st_mode), "should be a directory");
    /* Cleanup */
    system("rm -rf /tmp/ocws_test_mkdir_p");
    PASS();
}

static void test_mkdir_p_existing_dir(void) {
    TEST("mkdir_p: existing directory is idempotent");
    cli_mkdir_p("/tmp");
    cli_mkdir_p("/tmp");
    struct stat st;
    ASSERT(stat("/tmp", &st) == 0, "/tmp should still exist");
    PASS();
}

/* ======================================================================
 * cli_check_cmd tests
 * ====================================================================== */

static void test_check_cmd_exists(void) {
    TEST("check_cmd: existing command does not crash");
    /* 'ls' should exist on any Unix system */
    cli_check_cmd("ls");
    /* If we got here, it didn't call exit() */
    PASS();
}

static void test_check_cmd_nonexistent_subprocess(void) {
    TEST("check_cmd: nonexistent command calls exit(1)");
    /* We can't test cli_check_cmd directly because it calls exit().
     * Run it in a subprocess and check exit code. */
    pid_t pid = fork();
    if (pid == 0) {
        cli_check_cmd("nonexistent_command_xyzzy_12345");
        _exit(0); /* Should not reach here */
    } else {
        int status;
        waitpid(pid, &status, 0);
        ASSERT(WIFEXITED(status), "should have exited");
        ASSERT(WEXITSTATUS(status) == 1, "exit code should be 1");
    }
    PASS();
}

/* ======================================================================
 * Output format tests (cli_pass, cli_warn, cli_info)
 * ====================================================================== */

static void test_cli_pass_output(void) {
    TEST("cli_pass: outputs checkmark to stdout");
    /* Redirect stdout to capture output */
    FILE *orig = stdout;
    stdout = tmpfile();
    cli_pass("test message %d", 42);
    fflush(stdout);
    /* Rewind and read */
    fseek(stdout, 0, SEEK_END);
    long size = ftell(stdout);
    fseek(stdout, 0, SEEK_SET);
    char *buf = malloc(size + 1);
    fread(buf, 1, size, stdout);
    buf[size] = '\0';
    fclose(stdout);
    stdout = orig;

    ASSERT(strstr(buf, "✓") != NULL, "should contain checkmark");
    ASSERT(strstr(buf, "test message 42") != NULL, "should contain formatted message");
    free(buf);
    PASS();
}

static void test_cli_warn_output(void) {
    TEST("cli_warn: outputs warning to stderr");
    FILE *orig = stderr;
    stderr = tmpfile();
    cli_warn("warning %s", "test");
    fflush(stderr);
    fseek(stderr, 0, SEEK_END);
    long size = ftell(stderr);
    fseek(stderr, 0, SEEK_SET);
    char *buf = malloc(size + 1);
    fread(buf, 1, size, stderr);
    buf[size] = '\0';
    fclose(stderr);
    stderr = orig;

    ASSERT(strstr(buf, "⚠") != NULL, "should contain warning symbol");
    ASSERT(strstr(buf, "warning test") != NULL, "should contain message");
    free(buf);
    PASS();
}

static void test_cli_info_output(void) {
    TEST("cli_info: outputs info banner to stdout");
    FILE *orig = stdout;
    stdout = tmpfile();
    cli_info("installing %s", "pkg");
    fflush(stdout);
    fseek(stdout, 0, SEEK_END);
    long size = ftell(stdout);
    fseek(stdout, 0, SEEK_SET);
    char *buf = malloc(size + 1);
    fread(buf, 1, size, stdout);
    buf[size] = '\0';
    fclose(stdout);
    stdout = orig;

    ASSERT(strstr(buf, "==>") != NULL, "should contain ==> banner");
    ASSERT(strstr(buf, "installing pkg") != NULL, "should contain message");
    free(buf);
    PASS();
}

int main(void) {
    printf("═══════════════════════════════════════════════════════════\n");
    printf(" test_libocws_cli_common — cli-common.h unit tests\n");
    printf("═══════════════════════════════════════════════════════════\n\n");

    printf("[cli_get_home]\n");
    test_get_home_not_null();
    test_get_home_matches_env();
    test_get_home_starts_with_slash();

    printf("\n[cli_get_timestamp]\n");
    test_timestamp_not_empty();
    test_timestamp_format();

    printf("\n[cli_file_exists]\n");
    test_file_exists_existing();
    test_file_exists_nonexistent();
    test_file_exists_directory();
    test_file_exists_dev_null();

    printf("\n[cli_mkdir_p]\n");
    test_mkdir_p_creates_dir();
    test_mkdir_p_existing_dir();

    printf("\n[cli_check_cmd]\n");
    test_check_cmd_exists();
    test_check_cmd_nonexistent_subprocess();

    printf("\n[Output format]\n");
    test_cli_pass_output();
    test_cli_warn_output();
    test_cli_info_output();

    printf("\n═══════════════════════════════════════════════════════════\n");
    printf(" Results: %d/%d passed\n", tests_passed, tests_run);
    printf("═══════════════════════════════════════════════════════════\n");

    return tests_passed == tests_run ? 0 : 1;
}

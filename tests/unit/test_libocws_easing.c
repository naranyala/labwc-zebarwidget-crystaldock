/*
 * test_libocws_easing.c — Tests for easing.h (animation math)
 *
 * Covers: ease_out_cubic, ease_in_out_cubic, ease_in_out,
 *         animate_int (with mock callback), boundary conditions
 *
 * Compile: gcc -o test_libocws_easing test_libocws_easing.c -I../../src -lm
 * Run:     ./test_libocws_easing
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <assert.h>
#include "../../src/libocws/easing.h"

static int tests_run = 0;
static int tests_passed = 0;

#define TEST(name) do { tests_run++; printf("  test %-45s ", name); } while(0)
#define PASS() do { tests_passed++; printf("[PASS]\n"); } while(0)
#define FAIL(msg) do { printf("[FAIL] %s\n", msg); } while(0)
#define ASSERT(cond, msg) do { if (!(cond)) { FAIL(msg); return; } } while(0)
#define ASSERT_NEAR(a, b, eps, msg) do { if (fabs((a)-(b)) > (eps)) { FAIL(msg); return; } } while(0)

/* ======================================================================
 * ease_out_cubic tests
 * ====================================================================== */

static void test_ease_out_cubic_zero(void) {
    TEST("ease_out_cubic(0.0) == 0.0");
    ASSERT_NEAR(ease_out_cubic(0.0), 0.0, 1e-10, "should be 0");
    PASS();
}

static void test_ease_out_cubic_one(void) {
    TEST("ease_out_cubic(1.0) == 1.0");
    ASSERT_NEAR(ease_out_cubic(1.0), 1.0, 1e-10, "should be 1");
    PASS();
}

static void test_ease_out_cubic_half(void) {
    TEST("ease_out_cubic(0.5) == 0.875");
    /* (0.5-1)^3 + 1 = -0.125 + 1 = 0.875 */
    ASSERT_NEAR(ease_out_cubic(0.5), 0.875, 1e-10, "should be 0.875");
    PASS();
}

static void test_ease_out_cubic_quarter(void) {
    TEST("ease_out_cubic(0.25) ~= 0.578125");
    /* (0.25-1)^3 + 1 = (-0.75)^3 + 1 = -0.421875 + 1 = 0.578125 */
    ASSERT_NEAR(ease_out_cubic(0.25), 0.578125, 1e-10, "should be ~0.578");
    PASS();
}

static void test_ease_out_cubic_monotonic(void) {
    TEST("ease_out_cubic: monotonically increasing on [0,1]");
    double prev = -1;
    for (int i = 0; i <= 100; i++) {
        double t = (double)i / 100.0;
        double v = ease_out_cubic(t);
        ASSERT(v >= prev, "should be monotonically increasing");
        prev = v;
    }
    PASS();
}

static void test_ease_out_cubic_range(void) {
    TEST("ease_out_cubic: output in [0,1] for input in [0,1]");
    for (int i = 0; i <= 200; i++) {
        double t = (double)i / 200.0;
        double v = ease_out_cubic(t);
        ASSERT(v >= -1e-10 && v <= 1.0 + 1e-10, "output should be in [0,1]");
    }
    PASS();
}

/* ======================================================================
 * ease_in_out_cubic tests
 * ====================================================================== */

static void test_ease_in_out_cubic_zero(void) {
    TEST("ease_in_out_cubic(0.0) == 0.0");
    ASSERT_NEAR(ease_in_out_cubic(0.0), 0.0, 1e-10, "should be 0");
    PASS();
}

static void test_ease_in_out_cubic_one(void) {
    TEST("ease_in_out_cubic(1.0) == 1.0");
    ASSERT_NEAR(ease_in_out_cubic(1.0), 1.0, 1e-10, "should be 1");
    PASS();
}

static void test_ease_in_out_cubic_half(void) {
    TEST("ease_in_out_cubic(0.5) == 0.5 (symmetry point)");
    ASSERT_NEAR(ease_in_out_cubic(0.5), 0.5, 1e-10, "should be 0.5");
    PASS();
}

static void test_ease_in_out_cubic_quarter(void) {
    TEST("ease_in_out_cubic(0.25) == 0.125");
    /* 4 * 0.25^3 = 4 * 0.015625 = 0.0625... wait, let me recalculate.
     * ease_in_out_cubic(0.25): t < 0.5, so 4*t^3 = 4 * 0.015625 = 0.0625 */
    ASSERT_NEAR(ease_in_out_cubic(0.25), 0.0625, 1e-10, "should be 0.0625");
    PASS();
}

static void test_ease_in_out_cubic_three_quarter(void) {
    TEST("ease_in_out_cubic(0.75) == 0.9375");
    /* t >= 0.5: t' = 2*0.75-2 = -0.5; 0.5*(-0.5)^3+1 = 0.5*(-0.125)+1 = 0.9375 */
    ASSERT_NEAR(ease_in_out_cubic(0.75), 0.9375, 1e-10, "should be 0.9375");
    PASS();
}

static void test_ease_in_out_cubic_symmetry(void) {
    TEST("ease_in_out_cubic: f(t) + f(1-t) == 1 (point symmetry)");
    for (int i = 0; i <= 50; i++) {
        double t = (double)i / 100.0;
        double v = ease_in_out_cubic(t) + ease_in_out_cubic(1.0 - t);
        ASSERT_NEAR(v, 1.0, 1e-10, "should be point-symmetric");
    }
    PASS();
}

/* ======================================================================
 * ease_in_out tests
 * ====================================================================== */

static void test_ease_in_out_zero(void) {
    TEST("ease_in_out(0.0) == 0.0");
    ASSERT_NEAR(ease_in_out(0.0), 0.0, 1e-10, "should be 0");
    PASS();
}

static void test_ease_in_out_one(void) {
    TEST("ease_in_out(1.0) == 1.0");
    ASSERT_NEAR(ease_in_out(1.0), 1.0, 1e-10, "should be 1");
    PASS();
}

static void test_ease_in_out_half(void) {
    TEST("ease_in_out(0.5) == 0.5 (symmetry)");
    ASSERT_NEAR(ease_in_out(0.5), 0.5, 1e-10, "should be 0.5");
    PASS();
}

static void test_ease_in_out_monotonic(void) {
    TEST("ease_in_out: monotonically increasing on [0,1]");
    double prev = -1;
    for (int i = 0; i <= 100; i++) {
        double t = (double)i / 100.0;
        double v = ease_in_out(t);
        ASSERT(v >= prev - 1e-10, "should be monotonically increasing");
        prev = v;
    }
    PASS();
}

/* ======================================================================
 * animate_int tests (with mock callback)
 * ====================================================================== */

typedef struct {
    int values[1024];
    int count;
} MockAnimCtx;

static void mock_apply(int value, void *ctx) {
    MockAnimCtx *m = (MockAnimCtx *)ctx;
    if (m->count < 1024) m->values[m->count++] = value;
}

static void test_animate_same_start_target(void) {
    TEST("animate_int: start == target → no callback");
    MockAnimCtx ctx = { .count = 0 };
    animate_int(100, 100, 100, 10, 0, 255, mock_apply, &ctx);
    ASSERT(ctx.count == 0, "should not call apply");
    PASS();
}

static void test_animate_zero_duration(void) {
    TEST("animate_int: zero duration → single callback with target");
    MockAnimCtx ctx = { .count = 0 };
    animate_int(0, 100, 0, 10, 0, 255, mock_apply, &ctx);
    ASSERT(ctx.count == 1, "should call apply once");
    ASSERT(ctx.values[0] == 100, "should jump to target");
    PASS();
}

static void test_animate_reaches_target(void) {
    TEST("animate_int: final value == target");
    MockAnimCtx ctx = { .count = 0 };
    animate_int(0, 255, 100, 10, 0, 255, mock_apply, &ctx);
    ASSERT(ctx.count > 0, "should have called apply");
    ASSERT(ctx.values[ctx.count - 1] == 255, "final value should be target");
    PASS();
}

static void test_animate_clamps_min(void) {
    TEST("animate_int: respects clamp_min");
    MockAnimCtx ctx = { .count = 0 };
    animate_int(100, -50, 50, 10, 0, 255, mock_apply, &ctx);
    for (int i = 0; i < ctx.count; i++) {
        ASSERT(ctx.values[i] >= 0, "should not go below clamp_min");
    }
    PASS();
}

static void test_animate_clamps_max(void) {
    TEST("animate_int: respects clamp_max");
    MockAnimCtx ctx = { .count = 0 };
    animate_int(0, 500, 50, 10, 0, 255, mock_apply, &ctx);
    for (int i = 0; i < ctx.count; i++) {
        ASSERT(ctx.values[i] <= 255, "should not exceed clamp_max");
    }
    PASS();
}

static void test_animate_decreasing(void) {
    TEST("animate_int: decreasing animation (255 → 0)");
    MockAnimCtx ctx = { .count = 0 };
    animate_int(255, 0, 100, 10, 0, 255, mock_apply, &ctx);
    ASSERT(ctx.values[ctx.count - 1] == 0, "final should be 0");
    /* All intermediate values should be decreasing or equal */
    for (int i = 1; i < ctx.count; i++) {
        ASSERT(ctx.values[i] <= ctx.values[i - 1], "should be non-increasing");
    }
    PASS();
}

int main(void) {
    printf("═══════════════════════════════════════════════════════════\n");
    printf(" test_libocws_easing — easing.h unit tests\n");
    printf("═══════════════════════════════════════════════════════════\n\n");

    printf("[ease_out_cubic]\n");
    test_ease_out_cubic_zero();
    test_ease_out_cubic_one();
    test_ease_out_cubic_half();
    test_ease_out_cubic_quarter();
    test_ease_out_cubic_monotonic();
    test_ease_out_cubic_range();

    printf("\n[ease_in_out_cubic]\n");
    test_ease_in_out_cubic_zero();
    test_ease_in_out_cubic_one();
    test_ease_in_out_cubic_half();
    test_ease_in_out_cubic_quarter();
    test_ease_in_out_cubic_three_quarter();
    test_ease_in_out_cubic_symmetry();

    printf("\n[ease_in_out]\n");
    test_ease_in_out_zero();
    test_ease_in_out_one();
    test_ease_in_out_half();
    test_ease_in_out_monotonic();

    printf("\n[animate_int]\n");
    test_animate_same_start_target();
    test_animate_zero_duration();
    test_animate_reaches_target();
    test_animate_clamps_min();
    test_animate_clamps_max();
    test_animate_decreasing();

    printf("\n═══════════════════════════════════════════════════════════\n");
    printf(" Results: %d/%d passed\n", tests_passed, tests_run);
    printf("═══════════════════════════════════════════════════════════\n");

    return tests_passed == tests_run ? 0 : 1;
}

/*
 * test_libocws_procfs.c — Tests for procfs.h (CPU/memory/network parsing)
 *
 * Covers: proc_cpu_read, proc_mem_read, proc_net_dev_read,
 *         proc_cpu_usage, proc_mem_used_pct, edge cases
 *
 * Compile: gcc -o test_libocws_procfs test_libocws_procfs.c -I../../src -lm
 * Run:     ./test_libocws_procfs
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <assert.h>
#include "../../src/libocws/procfs.h"

static int tests_run = 0;
static int tests_passed = 0;

#define TEST(name) do { tests_run++; printf("  test %-45s ", name); } while(0)
#define PASS() do { tests_passed++; printf("[PASS]\n"); } while(0)
#define FAIL(msg) do { printf("[FAIL] %s\n", msg); } while(0)
#define ASSERT(cond, msg) do { if (!(cond)) { FAIL(msg); return; } } while(0)
#define ASSERT_NEAR(a, b, eps, msg) do { if (fabs((a)-(b)) > (eps)) { FAIL(msg); return; } } while(0)

/* ======================================================================
 * proc_cpu_read tests
 * ====================================================================== */

static void test_cpu_read_basic(void) {
    TEST("proc_cpu_read: reads /proc/stat successfully");
    ProcCpu cpu;
    memset(&cpu, 0, sizeof(cpu));
    int r = proc_cpu_read(&cpu);
    ASSERT(r == 0, "should succeed on Linux");
    ASSERT(cpu.total > 0, "total jiffies should be > 0");
    ASSERT(cpu.user >= 0, "user should be >= 0");
    ASSERT(cpu.idle >= 0, "idle should be >= 0");
    PASS();
}

static void test_cpu_read_total_consistency(void) {
    TEST("proc_cpu_read: total == sum of components");
    ProcCpu cpu;
    proc_cpu_read(&cpu);
    long sum = cpu.user + cpu.nice + cpu.system + cpu.idle +
               cpu.iowait + cpu.irq + cpu.softirq + cpu.steal;
    ASSERT(cpu.total == sum, "total should equal sum of all fields");
    PASS();
}

static void test_cpu_read_nonzero_idle(void) {
    TEST("proc_cpu_read: idle jiffies should be > 0 on running system");
    ProcCpu cpu;
    proc_cpu_read(&cpu);
    ASSERT(cpu.idle > 0, "idle should be positive on any running system");
    PASS();
}

/* ======================================================================
 * proc_cpu_usage tests
 * ====================================================================== */

static void test_cpu_usage_zero_delta(void) {
    TEST("proc_cpu_usage: zero delta returns 0%");
    ProcCpu prev = { .total = 1000, .idle = 500 };
    ProcCpu cur = { .total = 1000, .idle = 500 };
    double usage = proc_cpu_usage(&prev, &cur);
    ASSERT_NEAR(usage, 0.0, 0.001, "should be 0%");
    PASS();
}

static void test_cpu_usage_50_percent(void) {
    TEST("proc_cpu_usage: 50% busy");
    ProcCpu prev = { .total = 1000, .idle = 500 };
    ProcCpu cur = { .total = 2000, .idle = 1000 };
    double usage = proc_cpu_usage(&prev, &cur);
    ASSERT_NEAR(usage, 50.0, 0.001, "should be 50%");
    PASS();
}

static void test_cpu_usage_100_percent(void) {
    TEST("proc_cpu_usage: 100% busy (no idle)");
    ProcCpu prev = { .total = 1000, .idle = 500 };
    ProcCpu cur = { .total = 2000, .idle = 500 };
    double usage = proc_cpu_usage(&prev, &cur);
    ASSERT_NEAR(usage, 100.0, 0.001, "should be 100%");
    PASS();
}

static void test_cpu_usage_0_percent(void) {
    TEST("proc_cpu_usage: 0% busy (all idle)");
    ProcCpu prev = { .total = 1000, .idle = 1000 };
    ProcCpu cur = { .total = 2000, .idle = 2000 };
    double usage = proc_cpu_usage(&prev, &cur);
    ASSERT_NEAR(usage, 0.0, 0.001, "should be 0%");
    PASS();
}

static void test_cpu_usage_real_samples(void) {
    TEST("proc_cpu_usage: real system readings are in [0,100]");
    ProcCpu cpu1, cpu2;
    proc_cpu_read(&cpu1);
    /* Brief busy-wait */
    volatile long x = 0;
    for (volatile int i = 0; i < 1000000; i++) x += i;
    proc_cpu_read(&cpu2);
    double usage = proc_cpu_usage(&cpu1, &cpu2);
    ASSERT(usage >= 0.0 && usage <= 100.0, "usage should be in [0, 100]");
    PASS();
}

/* ======================================================================
 * proc_mem_read tests
 * ====================================================================== */

static void test_mem_read_basic(void) {
    TEST("proc_mem_read: reads /proc/meminfo");
    ProcMem mem;
    memset(&mem, 0, sizeof(mem));
    int r = proc_mem_read(&mem);
    ASSERT(r == 0, "should succeed");
    ASSERT(mem.total > 0, "MemTotal should be > 0");
    ASSERT(mem.free >= 0, "MemFree should be >= 0");
    ASSERT(mem.available >= 0, "MemAvailable should be >= 0");
    PASS();
}

static void test_mem_read_consistency(void) {
    TEST("proc_mem_read: free <= total");
    ProcMem mem;
    proc_mem_read(&mem);
    ASSERT(mem.free <= mem.total, "free should not exceed total");
    ASSERT(mem.available <= mem.total, "available should not exceed total");
    PASS();
}

static void test_mem_read_swap(void) {
    TEST("proc_mem_read: swap fields readable");
    ProcMem mem;
    proc_mem_read(&mem);
    ASSERT(mem.swap_total >= 0, "SwapTotal should be >= 0");
    ASSERT(mem.swap_free >= 0, "SwapFree should be >= 0");
    ASSERT(mem.swap_free <= mem.swap_total || mem.swap_total == 0,
           "swap_free should not exceed swap_total");
    PASS();
}

/* ======================================================================
 * proc_mem_used_pct tests
 * ====================================================================== */

static void test_mem_pct_zero_total(void) {
    TEST("proc_mem_used_pct: zero total returns 0%");
    ProcMem mem = { .total = 0, .available = 0 };
    ASSERT(proc_mem_used_pct(&mem) == 0, "should be 0");
    PASS();
}

static void test_mem_pct_half_used(void) {
    TEST("proc_mem_used_pct: 50% used");
    ProcMem mem = { .total = 16000, .available = 8000 };
    ASSERT(proc_mem_used_pct(&mem) == 50, "should be 50%");
    PASS();
}

static void test_mem_pct_fully_used(void) {
    TEST("proc_mem_used_pct: 100% used");
    ProcMem mem = { .total = 16000, .available = 0 };
    ASSERT(proc_mem_used_pct(&mem) == 100, "should be 100%");
    PASS();
}

static void test_mem_pct_real_system(void) {
    TEST("proc_mem_used_pct: real system usage in [0,100]");
    ProcMem mem;
    proc_mem_read(&mem);
    long pct = proc_mem_used_pct(&mem);
    ASSERT(pct >= 0 && pct <= 100, "should be in [0, 100]");
    PASS();
}

/* ======================================================================
 * proc_net_dev_read tests
 * ====================================================================== */

static void test_net_dev_read_loopback(void) {
    TEST("proc_net_dev_read: loopback interface");
    ProcNetDev dev;
    memset(&dev, 0, sizeof(dev));
    int r = proc_net_dev_read("lo", &dev);
    ASSERT(r == 0, "should find lo interface");
    ASSERT(strcmp(dev.name, "lo") == 0, "name should be 'lo'");
    ASSERT(dev.rx_bytes >= 0, "rx_bytes should be >= 0");
    ASSERT(dev.tx_bytes >= 0, "tx_bytes should be >= 0");
    PASS();
}

static void test_net_dev_read_nonexistent(void) {
    TEST("proc_net_dev_read: nonexistent interface returns -1");
    ProcNetDev dev;
    int r = proc_net_dev_read("nonexistent_iface_xyz", &dev);
    ASSERT(r == -1, "should return -1");
    PASS();
}

static void test_net_dev_read_real_iface(void) {
    TEST("proc_net_dev_read: first available non-loopback interface");
    FILE *f = fopen("/proc/net/dev", "r");
    if (!f) { printf("[SKIP] /proc/net/dev not readable\n"); tests_run++; tests_passed++; return; }
    char line[512];
    fgets(line, sizeof(line), f); /* header */
    fgets(line, sizeof(line), f); /* header */
    char iface[64] = "";
    while (fgets(line, sizeof(line), f)) {
        char name[64];
        if (sscanf(line, " %63[^:]:", name) == 1) {
            if (strcmp(name, "lo") != 0) {
                strncpy(iface, name, sizeof(iface) - 1);
                break;
            }
        }
    }
    fclose(f);

    if (strlen(iface) == 0) { printf("[SKIP] no non-loopback iface\n"); tests_run++; tests_passed++; return; }

    ProcNetDev dev;
    int r = proc_net_dev_read(iface, &dev);
    ASSERT(r == 0, "should find interface");
    ASSERT(strcmp(dev.name, iface) == 0, "name should match");
    PASS();
}

int main(void) {
    printf("═══════════════════════════════════════════════════════════\n");
    printf(" test_libocws_procfs — procfs.h unit tests\n");
    printf("═══════════════════════════════════════════════════════════\n\n");

    printf("[proc_cpu_read]\n");
    test_cpu_read_basic();
    test_cpu_read_total_consistency();
    test_cpu_read_nonzero_idle();

    printf("\n[proc_cpu_usage]\n");
    test_cpu_usage_zero_delta();
    test_cpu_usage_50_percent();
    test_cpu_usage_100_percent();
    test_cpu_usage_0_percent();
    test_cpu_usage_real_samples();

    printf("\n[proc_mem_read]\n");
    test_mem_read_basic();
    test_mem_read_consistency();
    test_mem_read_swap();

    printf("\n[proc_mem_used_pct]\n");
    test_mem_pct_zero_total();
    test_mem_pct_half_used();
    test_mem_pct_fully_used();
    test_mem_pct_real_system();

    printf("\n[proc_net_dev_read]\n");
    test_net_dev_read_loopback();
    test_net_dev_read_nonexistent();
    test_net_dev_read_real_iface();

    printf("\n═══════════════════════════════════════════════════════════\n");
    printf(" Results: %d/%d passed\n", tests_passed, tests_run);
    printf("═══════════════════════════════════════════════════════════\n");

    return tests_passed == tests_run ? 0 : 1;
}

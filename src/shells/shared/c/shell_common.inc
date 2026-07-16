// shell_common.inc — Shared, backend-agnostic C implementation.
// Included directly by each shell's dock_c_impl.c so the definition is
// single-sourced without requiring a new build target (build.zig files are
// managed by an external process and must not be churned).
//
// Requires the following libc/POSIX headers to already be included by the
// translation unit that #includes this file:
//   <stdlib.h> <unistd.h> <fcntl.h> <sys/types.h>

// Anonymous shared memory helper.
int dock_create_shm_fd(size_t size) {
    char name[] = "/tmp/wl_shm-XXXXXX";
    int fd = mkstemp(name);
    if (fd < 0) return -1;
    unlink(name);
    if (ftruncate(fd, (off_t)size) < 0) { close(fd); return -1; }
    return fd;
}

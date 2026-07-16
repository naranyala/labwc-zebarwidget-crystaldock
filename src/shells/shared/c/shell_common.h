// shell_common.h — Shared, backend-agnostic C declarations for both zigshells.
// Backend-neutral: depends only on libc / POSIX, never on Cairo or Blend2D.
#pragma once
#include <stddef.h>

// Create an anonymous, unlinked shared-memory fd sized to `size` bytes.
// Returns a valid fd on success, or -1 on failure.
int dock_create_shm_fd(size_t size);

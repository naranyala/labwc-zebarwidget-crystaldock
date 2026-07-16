// dock_c_impl.c — Includes all real C headers for linking (Blend2D version)
// Compiles separately from Zig; Zig only sees dock_c.h declarations.

// Blend2D implementation — defines all inline functions
#define BLEND2D_IMPLEMENTATION
#include "blend2d/blend2d.h"

#include <wayland-client.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/timerfd.h>
#include <sys/poll.h>
#include <time.h>

#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#include "wlr-foreign-toplevel-management-unstable-v1-client-protocol.h"

// Shared, backend-agnostic helpers (dock_create_shm_fd, etc.)
#include "../../shared/c/shell_common.inc"


#include "blend2d_render.h"
#include <blend2d/blend2d.h>

void test_round_rect() {
    BLRoundRect r = {0,0,10,10,2,2};
    BLContextCore ctx;
    bl_context_fill_round_rect_d(&ctx, &r);
}


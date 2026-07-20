// modal.zig — Modal dialog module (minimal)
const std = @import("std");
const c = @import("c.zig").c;

pub const Rect = struct { x: i32, y: i32, w: i32, h: i32, r: i32 = 0 };
pub const ModalState = struct {
    open: bool = false,
    card_x: i32 = 0,
    card_y: i32 = 0,
    card_w: i32 = 0,
    card_h: i32 = 0,
    close_x: i32 = 0,
    close_y: i32 = 0,
    close_r: i32 = 0,
    close_hover: bool = false,
};

pub fn layoutCard(out_w: i32, out_h: i32, card_w: i32, card_h: i32) Rect {
    return .{
        .x = @divTrunc(out_w - card_w, 2),
        .y = @divTrunc(out_h - card_h, 2),
        .w = card_w,
        .h = card_h,
    };
}

pub fn layoutClose(card: Rect, padding: i32) Rect {
    return .{
        .x = card.x + card.w - padding - 20,
        .y = card.y + padding,
        .w = 20,
        .h = 20,
        .r = 10,
    };
}

// True if (x, y) is inside the close (×) button hit area.
// The button is a 20x20 box at (close_x, close_y) (see layoutClose/renderModal).
pub fn hitClose(s: ModalState, x: i32, y: i32) bool {
    const sz: i32 = 20;
    return x >= s.close_x and x <= s.close_x + sz and y >= s.close_y and y <= s.close_y + sz;
}

// True if (x, y) is inside the card body (swallow clicks on the backdrop).
pub fn hitCard(s: ModalState, x: i32, y: i32) bool {
    return x >= s.card_x and x <= s.card_x + s.card_w and y >= s.card_y and y <= s.card_y + s.card_h;
}

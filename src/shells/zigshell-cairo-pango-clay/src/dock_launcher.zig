// dock_launcher.zig — Full-app grid dock launcher
//
// Shows ALL GUI apps from the system app catalog in a scrollable grid,
// rendered in a floating TOP-layer surface above the dock.
// Triggered from a dock icon (home toggle, returns -5 from iconAt).

const std = @import("std");
const c = @import("c.zig").c;
const panel_mod = @import("panel.zig");
const apps_mod = @import("apps");
const icon = @import("icon.zig");
const theme = @import("theme.zig");
const main = @import("main_shell.zig");
const clay_cairo = @import("clay_cairo.zig");
const cc = clay_cairo.clay;

pub var launcher_open = false;
pub var launcher_hover_idx: i32 = -1;
pub var launcher_scroll: i32 = 0;

pub const CARD_W: i32 = 520;
pub const CARD_PAD: i32 = 14;
pub const ICON_SIZE: i32 = 48;
pub const ROW_H: i32 = 68;
pub const COLS: i32 = 4;
pub const HEADER_H: i32 = 40;

const MAX_ENTRIES = 256;

const LauncherEntry = struct {
    name: [64]u8 = std.mem.zeroes([64]u8),
    exec: [256]u8 = std.mem.zeroes([256]u8),
    icon_name: [128]u8 = std.mem.zeroes([128]u8),
};

var entries: [MAX_ENTRIES]LauncherEntry = std.mem.zeroes([MAX_ENTRIES]LauncherEntry);
var entry_count: i32 = 0;
var entries_scanned: bool = false;

pub fn ensureEntries() void {
    if (entries_scanned) return;
    entries_scanned = true;
    entry_count = 0;

    const app_list = apps_mod.list();
    for (app_list) |app| {
        if (entry_count >= MAX_ENTRIES) break;
        const app_name = app.name[0..app.name_len];
        const app_exec = app.exec[0..app.exec_len];
        const app_icon = app.icon[0..app.icon_len];
        if (app_name.len == 0 or app_exec.len == 0) continue;

        var e = &entries[@intCast(entry_count)];
        const nlen = @min(app_name.len, e.name.len - 1);
        @memcpy(e.name[0..nlen], app_name[0..nlen]);
        e.name[nlen] = 0;
        const elen = @min(app_exec.len, e.exec.len - 1);
        @memcpy(e.exec[0..elen], app_exec[0..elen]);
        e.exec[elen] = 0;
        const ilen = @min(app_icon.len, e.icon_name.len - 1);
        @memcpy(e.icon_name[0..ilen], app_icon[0..ilen]);
        e.icon_name[ilen] = 0;
        entry_count += 1;
    }
}

pub fn cardHeight(panel_width: i32) i32 {
    _ = panel_width;
    ensureEntries();
    const total_rows = @divTrunc(entry_count + COLS - 1, COLS);
    const max_visible = 6;
    const visible_rows = @min(total_rows, max_visible);
    return HEADER_H + visible_rows * ROW_H + CARD_PAD * 2;
}

// ---- Clay sizing helpers (mirror clay_panel.zig) ----
fn sizingFixed(px: f32) cc.Clay_SizingAxis {
    return .{ .size = .{ .minMax = .{ .min = px, .max = px } }, .type = cc.CLAY__SIZING_TYPE_FIXED };
}

// theme accent_color is f64[3]; Clay_Color channels are f32.
fn ac(i: usize) f32 {
    return @as(f32, @floatCast(theme.current.accent_color[i] * 255.0));
}
fn tc(i: usize) f32 {
    return @as(f32, @floatCast(theme.current.text_color[i] * 255.0));
}
fn sizingGrow() cc.Clay_SizingAxis {
    return .{ .size = .{ .minMax = .{ .min = 0, .max = 0 } }, .type = cc.CLAY__SIZING_TYPE_GROW };
}
fn sizingFit() cc.Clay_SizingAxis {
    return .{ .size = .{ .minMax = .{ .min = 0, .max = 0 } }, .type = cc.CLAY__SIZING_TYPE_FIT };
}

// ---- Clay declarative layout for the launcher ----
// Declares the card, header, and a clipped (scrolling) grid of app cells
// between Clay_BeginLayout() and Clay_EndLayout(). Icons are passed to the
// renderer via IMAGE commands (imageData = cached cairo surface pointer).
fn layoutLauncher(surf_w: i32, surf_h: i32) void {
    ensureEntries();
    if (entry_count == 0) return;

    const w_f: f32 = @floatFromInt(surf_w);
    const h_f: f32 = @floatFromInt(surf_h);
    const card_w: f32 = @min(@as(f32, @floatFromInt(CARD_W)), w_f - 20.0);

    // Root: dimmed backdrop, centered card.
    cc.Clay__OpenElement();
    _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
        .layout = .{
            .sizing = .{ .width = sizingFixed(w_f), .height = sizingFixed(h_f) },
            .childAlignment = .{ .x = cc.CLAY_ALIGN_X_CENTER, .y = cc.CLAY_ALIGN_Y_CENTER },
            .layoutDirection = cc.CLAY_TOP_TO_BOTTOM,
        },
        .backgroundColor = .{ .r = 0, .g = 0, .b = 0, .a = 64 },
    }));

    // Card container.
    cc.Clay__OpenElement();
    _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
        .layout = .{
            .sizing = .{ .width = sizingFixed(card_w), .height = sizingFixed(h_f) },
            .padding = .{ .left = CARD_PAD, .right = CARD_PAD, .top = CARD_PAD, .bottom = CARD_PAD },
            .childGap = 8,
            .childAlignment = .{ .x = cc.CLAY_ALIGN_X_LEFT, .y = cc.CLAY_ALIGN_Y_TOP },
            .layoutDirection = cc.CLAY_TOP_TO_BOTTOM,
        },
        .backgroundColor = .{ .r = 15, .g = 15, .b = 23, .a = 247 },
        .cornerRadius = .{ .topLeft = 14, .topRight = 14, .bottomLeft = 14, .bottomRight = 14 },
        .border = .{ .width = .{ .left = 1, .right = 1, .top = 1, .bottom = 1 }, .color = .{ .r = ac(0), .g = ac(1), .b = ac(2), .a = 64 } },
    }));

    // Header title.
    cc.Clay__OpenTextElement(
        .{ .length = @intCast("OCWS Homepage".len), .chars = "OCWS Homepage".ptr, .isStaticallyAllocated = true },
        std.mem.zeroInit(cc.Clay_TextElementConfig, .{
            .fontSize = 15,
            .textColor = .{ .r = 242, .g = 242, .b = 250, .a = 255 },
            .wrapMode = cc.CLAY_TEXT_WRAP_NONE,
        }),
    );
    cc.Clay__CloseElement(); // end header text

    // Clipped, scrolling grid region.
    const grid_top: f32 = @as(f32, @floatFromInt(launcher_scroll * ROW_H));
    cc.Clay__OpenElement();
    _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
        .layout = .{
            .sizing = .{ .width = sizingGrow(), .height = sizingGrow() },
            .padding = .{ .left = 2, .right = 2, .top = 2, .bottom = 2 },
            .childGap = 0,
            .layoutDirection = cc.CLAY_TOP_TO_BOTTOM,
        },
        .clip = .{ .horizontal = false, .vertical = true, .childOffset = .{ .x = 0, .y = grid_top } },
    }));

    const total_rows = @divTrunc(entry_count + COLS - 1, COLS);
    var r: i32 = 0;
    while (r < total_rows) : (r += 1) {
        // One row of COLS cells.
        cc.Clay__OpenElement();
        _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
            .layout = .{
                .sizing = .{ .width = sizingGrow(), .height = sizingFixed(@floatFromInt(ROW_H)) },
                .childGap = 4,
                .layoutDirection = cc.CLAY_LEFT_TO_RIGHT,
            },
        }));

        var col: i32 = 0;
        while (col < COLS) : (col += 1) {
            const abs_idx = r * COLS + col;
            if (abs_idx >= entry_count) {
                // Empty trailing cell — still open/close to keep the row balanced.
                cc.Clay__OpenElement();
                _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
                    .layout = .{ .sizing = .{ .width = sizingGrow(), .height = sizingFixed(@floatFromInt(ROW_H)) } },
                }));
                cc.Clay__CloseElement();
                col += 1;
                continue;
            }

            const e = &entries[@intCast(abs_idx)];
            const is_hover = abs_idx == launcher_hover_idx;
            const cell_bg: cc.Clay_Color = if (is_hover)
                .{ .r = ac(0), .g = ac(1), .b = ac(2), .a = 38 }
            else
                .{ .r = 0, .g = 0, .b = 0, .a = 0 };

            cc.Clay__OpenElement();
            _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
                .layout = .{
                    .sizing = .{ .width = sizingGrow(), .height = sizingFixed(@floatFromInt(ROW_H)) },
                    .padding = .{ .left = 4, .right = 4, .top = 4, .bottom = 4 },
                    .childGap = 6,
                    .childAlignment = .{ .x = cc.CLAY_ALIGN_X_LEFT, .y = cc.CLAY_ALIGN_Y_CENTER },
                    .layoutDirection = cc.CLAY_LEFT_TO_RIGHT,
                },
                .backgroundColor = cell_bg,
                .cornerRadius = .{ .topLeft = 8, .topRight = 8, .bottomLeft = 8, .bottomRight = 8 },
            }));

            // App icon via IMAGE command (populating .image.imageData makes
            // Clay emit a CLAY_RENDER_COMMAND_TYPE_IMAGE for this element).
            const icon_surf = icon.load(@ptrCast(&e.icon_name), ICON_SIZE);
            cc.Clay__OpenElement();
            _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
                .layout = .{ .sizing = .{ .width = sizingFixed(@floatFromInt(ICON_SIZE)), .height = sizingFixed(@floatFromInt(ICON_SIZE)) } },
                .image = .{ .imageData = icon_surf },
            }));
            cc.Clay__CloseElement(); // end image element

            // App name text.
            const name_ptr: [*:0]const u8 = @ptrCast(&e.name);
            cc.Clay__OpenTextElement(
                .{ .length = @intCast(std.mem.sliceTo(&e.name, 0).len), .chars = name_ptr, .isStaticallyAllocated = false },
                std.mem.zeroInit(cc.Clay_TextElementConfig, .{
                    .fontSize = 9,
                    .textColor = .{ .r = tc(0), .g = tc(1), .b = tc(2), .a = 255 },
                    .wrapMode = cc.CLAY_TEXT_WRAP_NONE,
                }),
            );
            cc.Clay__CloseElement(); // end text element

            cc.Clay__CloseElement(); // end cell
            col += 1;
        }
        cc.Clay__CloseElement(); // end row
    }
    cc.Clay__CloseElement(); // end grid (clipped)

    cc.Clay__CloseElement(); // end card
    cc.Clay__CloseElement(); // end root
}

pub fn draw(cr: *c.cairo_t, surf_w: i32, surf_h: i32) void {
    ensureEntries();
    if (entry_count == 0) return;

    const w_f: f32 = @floatFromInt(surf_w);
    const h_f: f32 = @floatFromInt(surf_h);

    // Run a Clay layout pass and render the result into the launcher cairo
    // context. Clay owns all geometry; the manual row/col math is gone.
    cc.Clay_SetLayoutDimensions(.{ .width = w_f, .height = h_f });
    cc.Clay_BeginLayout();
    layoutLauncher(surf_w, surf_h);
    const commands = cc.Clay_EndLayout(0.016);
    clay_cairo.render(commands, cr);
}

// Single source of truth for launcher hit-testing. Returns the absolute entry
// index under (x,y) on the launcher surface, or -1 if outside the grid.
pub fn launcherHitTest(x: i32, y: i32, surf_w: i32, surf_h: i32) i32 {
    if (entry_count == 0) return -1;

    const card_w = @min(CARD_W, surf_w - 20);
    const card_h = surf_h;
    const cx = @divTrunc(surf_w - card_w, 2);
    const cy: i32 = 0;

    // Outside the card → no hit (caller may close).
    if (x < cx or x > cx + card_w or y < cy or y > cy + card_h) return -1;

    const cell_w = @divTrunc(card_w - CARD_PAD * 2, COLS);
    const col = @divTrunc(x - cx - CARD_PAD, cell_w);
    const row = @divTrunc(y - cy - HEADER_H, ROW_H);
    if (col < 0 or col >= COLS or row < 0) return -1;

    const abs_idx = launcher_scroll * COLS + row * COLS + col;
    if (abs_idx < 0 or abs_idx >= entry_count) return -1;
    return abs_idx;
}

pub fn handleClick(x: i32, y: i32, surf_w: i32, surf_h: i32) bool {
    ensureEntries();
    if (entry_count == 0) return false;

    const hit = launcherHitTest(x, y, surf_w, surf_h);
    if (hit < 0) {
        // Click was outside the card (or on padding) → close the launcher.
        launcher_open = false;
        return true;
    }

    const e = &entries[@intCast(hit)];
    var cmd: [280]u8 = std.mem.zeroes([280]u8);
    _ = std.fmt.bufPrintZ(&cmd, "{s} &", .{std.mem.sliceTo(&e.exec, 0)}) catch return false;
    _ = panel_mod.spawnCmd(@ptrCast(&cmd));
    launcher_open = false;
    return true;
}

pub fn handleScroll(delta: i32) void {
    ensureEntries();
    const total_rows = @divTrunc(entry_count + COLS - 1, COLS);
    const max_visible = 6;
    if (delta > 0) {
        launcher_scroll = @max(0, launcher_scroll - 1);
    } else if (delta < 0) {
        launcher_scroll = @min(@max(0, total_rows - max_visible), launcher_scroll + 1);
    }
}

pub fn toggle() void {
    launcher_open = !launcher_open;
    if (launcher_open) {
        ensureEntries();
        launcher_hover_idx = -1;
        launcher_scroll = 0;
    }
}

// shared/damage.zig — Damage-region tracking helpers (shared by both shells)
//
// Tracks the minimal bounding rectangle that changed since the last commit so
// the compositor only re-reads the affected SHM pixels. Geometry logic is
// unit-tested; the shells currently repaint whole surfaces, so the region is
// set to the full surface rect on each repaint (behavior-preserving), but the
// union/intersect math is ready for future partial repaints.

const std = @import("std");

pub const Region = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    active: bool,

    pub fn init() Region {
        return .{ .x = 0, .y = 0, .w = 0, .h = 0, .active = false };
    }

    pub fn reset(self: *Region) void {
        self.active = false;
        self.x = 0;
        self.y = 0;
        self.w = 0;
        self.h = 0;
    }

    pub fn add(self: *Region, x: i32, y: i32, w: i32, h: i32) void {
        if (w <= 0 or h <= 0) return;
        if (!self.active) {
            self.x = x;
            self.y = y;
            self.w = w;
            self.h = h;
            self.active = true;
            return;
        }
        const x0 = @min(self.x, x);
        const y0 = @min(self.y, y);
        const x1 = @max(self.x + self.w, x + w);
        const y1 = @max(self.y + self.h, y + h);
        self.x = x0;
        self.y = y0;
        self.w = x1 - x0;
        self.h = y1 - y0;
    }

    pub fn contains(self: Region, x: i32, y: i32) bool {
        return self.active and
            x >= self.x and x < self.x + self.w and
            y >= self.y and y < self.y + self.h;
    }
};

test "damage region union" {
    var r = Region.init();
    try std.testing.expect(!r.active);
    r.add(10, 5, 20, 10);
    try std.testing.expect(r.active);
    try std.testing.expectEqual(@as(i32, 10), r.x);
    try std.testing.expectEqual(@as(i32, 5), r.y);
    try std.testing.expectEqual(@as(i32, 20), r.w);
    try std.testing.expectEqual(@as(i32, 10), r.h);

    // Expand to include a disjoint rect to the lower-right.
    r.add(40, 20, 10, 10);
    try std.testing.expectEqual(@as(i32, 10), r.x);
    try std.testing.expectEqual(@as(i32, 5), r.y);
    try std.testing.expectEqual(@as(i32, 40), r.w); // 10..50
    try std.testing.expectEqual(@as(i32, 25), r.h); // 5..30

    // A contained rect must not change the bounds.
    const before = r;
    r.add(15, 10, 5, 5);
    try std.testing.expectEqual(before.x, r.x);
    try std.testing.expectEqual(before.w, r.w);
}

test "damage region contains/reset" {
    var r = Region.init();
    r.add(10, 10, 10, 10);
    try std.testing.expect(r.contains(15, 15));
    try std.testing.expect(!r.contains(5, 5));

    r.reset();
    try std.testing.expect(!r.active);
    try std.testing.expect(!r.contains(15, 15));
}

test "damage region add negative/zero dimensions" {
    var r = Region.init();
    r.add(10, 10, 0, 10);
    try std.testing.expect(!r.active);
    r.add(10, 10, 10, 0);
    try std.testing.expect(!r.active);
    r.add(10, 10, -5, 10);
    try std.testing.expect(!r.active);
    r.add(10, 10, 10, -5);
    try std.testing.expect(!r.active);
    
    // Now make it active and try adding invalid dimensions again
    r.add(10, 10, 10, 10);
    const before = r;
    r.add(0, 0, -5, 5);
    try std.testing.expectEqual(before.x, r.x);
    try std.testing.expectEqual(before.y, r.y);
    try std.testing.expectEqual(before.w, r.w);
    try std.testing.expectEqual(before.h, r.h);
}

test "damage region expand top-left" {
    var r = Region.init();
    r.add(10, 10, 10, 10); // 10..20, 10..20
    r.add(5, 5, 5, 5); // 5..10, 5..10
    
    try std.testing.expectEqual(@as(i32, 5), r.x);
    try std.testing.expectEqual(@as(i32, 5), r.y);
    try std.testing.expectEqual(@as(i32, 15), r.w); // 5..20
    try std.testing.expectEqual(@as(i32, 15), r.h); // 5..20
}

test "damage region contains boundary cases" {
    var r = Region.init();
    // Contains is false when inactive
    try std.testing.expect(!r.contains(0, 0));
    
    r.add(10, 10, 10, 10); // x:10..19, y:10..19
    // Top-left is inside
    try std.testing.expect(r.contains(10, 10));
    // Inside
    try std.testing.expect(r.contains(15, 15));
    // Bottom-right is outside
    try std.testing.expect(!r.contains(20, 20));
    // Edges are outside
    try std.testing.expect(!r.contains(10, 20));
    try std.testing.expect(!r.contains(20, 10));
    // Just outside top-left
    try std.testing.expect(!r.contains(9, 10));
    try std.testing.expect(!r.contains(10, 9));
}

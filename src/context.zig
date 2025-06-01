const xev = @import("xev");
const std = @import("std");

loop: *xev.Loop,
thread_id: i32,
const Self = @This();

pub fn init(allocator: std.mem.Allocator, loop: *xev.Loop, therad_id: i32) !*Self {
    const ctx = try allocator.create(Self);
    ctx.* = .{
        .loop = loop,
        .thread_id = therad_id,
    };

    return ctx;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.destroy(self);
}

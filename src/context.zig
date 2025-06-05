const xev = @import("xev");
const std = @import("std");
const ActorEngine = @import("actor_engine.zig");

loop: *xev.Loop,
thread_id: i32,
engine: *ActorEngine,
const Self = @This();

pub fn init(allocator: std.mem.Allocator, loop: *xev.Loop, actor_engine: *ActorEngine, therad_id: i32) !*Self {
    const ctx = try allocator.create(Self);
    ctx.* = .{
        .loop = loop,
        .thread_id = therad_id,
        .engine = actor_engine,
    };

    return ctx;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.destroy(self);
}

pub fn send(self: *Self, comptime T: type, msg_ptr: *anyopaque) !void {
    return self.engine.send(T, msg_ptr);
}

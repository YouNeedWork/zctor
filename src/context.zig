const xev = @import("xev");
const std = @import("std");
const ActorEngine = @import("actor_engine.zig");

loop: *xev.Loop,
thread_id: u64,
engine: *ActorEngine,

const Self = @This();

pub fn init(allocator: std.mem.Allocator, loop: *xev.Loop, actor_engine: *ActorEngine, thread_id: u64) !*Self {
    const ctx = try allocator.create(Self);
    ctx.* = .{
        .loop = loop,
        .thread_id = thread_id,
        .engine = actor_engine,
    };

    return ctx;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.destroy(self);
}

pub fn send(self: *Self, comptime T: type, msg_ptr: *anyopaque) !void {
    const s: *T = @ptrCast(@alignCast(msg_ptr));
    return self.engine.actor_threads[self.thread_id].send(T, s);
}

pub fn call(self: *Self, comptime T: type, msg_ptr: *anyopaque) !?*anyopaque {
    const s: *T = @ptrCast(@alignCast(msg_ptr));
    return self.engine.actor_threads[self.thread_id].call(T, s);
}

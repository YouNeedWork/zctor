const std = @import("std");
const context = @import("context.zig");
const xev = @import("xev");
const ActorThread = @import("actor_thread.zig");
const Self = @This();

thread: std.Thread.Thread,

pub fn init() Self {
    return Self{};
}

pub fn build(_: *Self) ActorThread {}

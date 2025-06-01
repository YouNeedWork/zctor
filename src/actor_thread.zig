const std = @import("std");
const context = @import("context.zig");
const xev = @import("xev");
const ActorInterface = @import("actor_interface.zig");
const Actor = @import("actor.zig");

loop: xev.Loop,
ctx: *context,
actors: std.StringArrayHashMap(ActorInterface),

const Self = @This();

pub fn init(allocator: std.mem.Allocator, thread_id: i32) !*Self {
    const self = try allocator.create(Self);
    self.loop = try xev.Loop.init(.{});
    self.ctx = try context.init(allocator, &self.loop, thread_id);
    self.actors = std.StringArrayHashMap(ActorInterface).init(allocator);

    return self;
}

pub fn registerActor(self: *Self, actor: anytype) !void {
    const name = comptime @typeName(@TypeOf(actor.*));
    try self.actors.put(name, ActorInterface.init(actor));
}

pub fn sender(self: *Self, comptime T: type, msg: *T) !void {
    const name = comptime @typeName(Actor.Actor(T));
    if (self.actors.get(name)) |act| {
        act.handleRawMessage(msg);
    } else {
        return error.ActorNotFound;
    }
}

pub fn boradcase(self: *Self, T: type, msg_ptr: *anyopaque) void {
    _ = T;

    for (self.actors.items) |act| {
        act.sender(msg_ptr);
    }
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    var iter = self.actors.iterator();
    while (iter.next()) |entry| {
        entry.value_ptr.deinit(allocator);
    }

    self.actors.deinit();

    self.ctx.deinit(allocator);
    self.loop.deinit();
    allocator.destroy(self);
}

pub fn run(self: *Self) !void {
    var iter = self.actors.iterator();
    while (iter.next()) |entry| {
        entry.value_ptr.run();
    }
}

pub fn start_loop(self: *Self) !void {
    try self.loop.run(.until_done);
}

const std = @import("std");
const context = @import("context.zig");
const xev = @import("xev");
const ActorInterface = @import("actor_interface.zig");
const ActorEngine = @import("actor_engine.zig");
const Actor = @import("actor.zig");

loop: xev.Loop,
ctx: ?*context,
actors: std.StringArrayHashMap(ActorInterface),

const Self = @This();

pub fn init(allocator: std.mem.Allocator) !*Self {
    const self = try allocator.create(Self);

    self.loop = try xev.Loop.init(.{});
    self.ctx = null;
    self.actors = std.StringArrayHashMap(ActorInterface).init(allocator);

    return self;
}

pub fn init_ctx(self: *Self, actor_engine: *ActorEngine, thread_id: u64) !void {
    self.ctx = try context.init(actor_engine.allocator, &self.loop, actor_engine, thread_id);
}

pub fn registerActor(self: *Self, actor: anytype) !void {
    const name = comptime @typeName(@TypeOf(actor.*));
    try self.actors.put(name, ActorInterface.init(actor));
}

pub fn send(self: *Self, comptime T: type, msg_ptr: *T) !void {
    const name = comptime @typeName(Actor.Actor(T));

    if (self.actors.get(name)) |act| {
        act.handleRawMessage(msg_ptr);
    } else {
        return error.ActorNotFound;
    }
}

pub fn publish(self: *Self, comptime T: type, msg_ptr: *anyopaque) void {
    _ = Self;
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
    self.ctx.?.deinit(allocator);

    self.loop.deinit();
    allocator.destroy(self);
}

pub fn run(self: *Self) !void {
    var iter = self.actors.iterator();
    while (iter.next()) |entry| {
        entry.value_ptr.add_ctx(self.ctx.?);
        entry.value_ptr.run();
    }
}

pub fn start_loop(self: *Self) !void {
    try self.loop.run(.until_done);
}

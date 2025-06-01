const std = @import("std");
const xev = @import("xev");
const builtin = @import("builtin");
const context = @import("context.zig");
const Actor = @import("actor.zig");
const ActorThread = @import("actor_thread.zig");
const ActorInterface = @import("actor_interface.zig");
const ActorEngine = @import("actor_engine.zig");

pub const FirstMessage = union(enum) {
    Hello: []const u8,
    Goodbye: void,
    Ping: u32,

    pub fn handle(self: *Actor.Actor(FirstMessage), msg: @This()) ?void {
        _ = self;

        switch (msg) {
            .Hello => |name| std.debug.print("Got Hello: {s}\n", .{name}),
            .Goodbye => std.debug.print("Got Goodbye\n", .{}),
            .Ping => |num| std.debug.print("Got Ping: {}\n", .{num}),
        }
        return null;
    }
};

//try actor_thread.registerActor(try Actor(FirstMessage).init(self.allocator, actor_thread.ctx, FirstMessage.handle));
//try actor_thread.run();
//var p: i32 = 10000;
//try actor_thread.sender(i32, &p);
//try actor_thread.sender(i32, &p);
//var s: FirstMessage = .{ .Ping = 0 };
//try actor_thread.sender(FirstMessage, &s);
//try actor_thread.start_loop();

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const allocator, const is_debug = gpa: {
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    var engine = try ActorEngine.init(allocator);
    defer engine.deinit();
    try engine.spawn(FirstMessage, FirstMessage.handle);
    var first_message = FirstMessage{ .Ping = 10 };
    try engine.send(&first_message);
    engine.start();
}

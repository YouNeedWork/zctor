const std = @import("std");
const xev = @import("xev");
const builtin = @import("builtin");
const context = @import("context.zig");
const Actor = @import("actor.zig");
const ActorThread = @import("actor_thread.zig");
const ActorInterface = @import("actor_interface.zig");
const ActorEngine = @import("actor_engine.zig");
const SimpleMessage = @import("simple_message.zig").SimpleMessage;

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
    try engine.spawn(SimpleMessage, SimpleMessage.handle);

    var hello_msg = SimpleMessage.hello_req("World");
    try engine.send(SimpleMessage, &hello_msg);

    var status_msg = SimpleMessage.ping_req(1);
    try engine.send(SimpleMessage, &status_msg);

    var status_msg1 = SimpleMessage.ping_req(2);
    try engine.send(SimpleMessage, &status_msg1);

    var status_msg2 = SimpleMessage.ping_req(3);
    try engine.send(SimpleMessage, &status_msg2);

    var reset_msg = SimpleMessage.reset_req();
    try engine.send(SimpleMessage, &reset_msg);

    engine.start();
}

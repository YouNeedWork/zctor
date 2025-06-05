const std = @import("std");
const xev = @import("xev");
const builtin = @import("builtin");
const context = @import("context.zig");
const Actor = @import("actor.zig");
const ActorThread = @import("actor_thread.zig");
const ActorInterface = @import("actor_interface.zig");
const ActorEngine = @import("actor_engine.zig");
const FirstMessage = @import("simple_message.zig").FirstMessage;

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

    var hello_msg = FirstMessage.hello_req("World");
    try engine.send(FirstMessage, &hello_msg);

    var status_msg = FirstMessage.ping_req(1);
    try engine.send(FirstMessage, &status_msg);

    var status_msg1 = FirstMessage.ping_req(2);
    try engine.send(FirstMessage, &status_msg1);

    var status_msg2 = FirstMessage.ping_req(3);
    try engine.send(FirstMessage, &status_msg2);

    var reset_msg = FirstMessage.reset_req();
    try engine.send(FirstMessage, &reset_msg);

    engine.start();
}

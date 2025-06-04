const std = @import("std");
const xev = @import("xev");
const builtin = @import("builtin");
const context = @import("context.zig");
const Actor = @import("actor.zig");
const ActorThread = @import("actor_thread.zig");
const ActorInterface = @import("actor_interface.zig");
const ActorEngine = @import("actor_engine.zig");

pub const FirstMessage = struct {
    // Message types
    const MessageType = enum {
        Hello,
        Goodbye,
        Ping,
        GetCount,
        Reset,
    };

    const MessageData = union(MessageType) {
        Hello: []const u8,
        Goodbye: void,
        Ping: u32,
        GetCount: void,
        Reset: void,
    };
    message_type: MessageType,
    data: MessageData,

    // State stored directly in the struct
    const State = struct {
        count: u32 = 0,
        total_pings: u32 = 0,
        total_hellos: u32 = 0,
        total_goodbyes: u32 = 0,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) !*State {
            const s = try allocator.create(State);

            s.* = State{
                .count = 0,
                .total_pings = 0,
                .total_hellos = 0,
                .total_goodbyes = 0,
                .allocator = allocator,
            };

            return s;
        }
    };

    const Self = @This();

    // Initialize with default state
    pub fn init(allocator: std.mem.Allocator) FirstMessage {
        _ = allocator;

        return FirstMessage{
            .message_type = .GetCount, // Default message
            .data = .{ .GetCount = {} },
        };
    }

    // Convenience constructors that preserve state
    pub fn hello(self: FirstMessage, name: []const u8) FirstMessage {
        var new_msg = self;
        new_msg.message_type = .Hello;
        new_msg.data = .{ .Hello = name };
        return new_msg;
    }

    pub fn goodbye(self: FirstMessage) FirstMessage {
        var new_msg = self;
        new_msg.message_type = .Goodbye;
        new_msg.data = .{ .Goodbye = {} };
        return new_msg;
    }

    pub fn ping(self: FirstMessage, value: u32) FirstMessage {
        var new_msg = self;
        new_msg.message_type = .Ping;
        new_msg.data = .{ .Ping = value };
        return new_msg;
    }

    pub fn getCount(self: FirstMessage) FirstMessage {
        var new_msg = self;
        new_msg.message_type = .GetCount;
        new_msg.data = .{ .GetCount = {} };
        return new_msg;
    }

    pub fn reset(self: FirstMessage) FirstMessage {
        var new_msg = self;
        new_msg.message_type = .Reset;
        new_msg.data = .{ .Reset = {} };
        return new_msg;
    }

    // Handler function that modifies state directly
    pub fn handle(self: *Actor.Actor(Self), msg: FirstMessage) ?void {
        // Get or initialize state
        var state = self.getState(State) orelse blk: {
            const new_state = State.init(self.allocator) catch |err| {
                std.debug.print("Failed to initialize state: {}\n", .{err});
                return null;
            };

            self.setState(new_state);
            break :blk self.getState(State).?;
        };

        switch (msg.message_type) {
            .Hello => {
                state.count += 1;
                state.total_hellos += 1;
                const name = msg.data.Hello;
                std.debug.print("Got Hello: {s} (count: {}, total_hellos: {})\n", .{ name, state.count, state.total_hellos });
            },
            .Goodbye => {
                state.count += 1;
                state.total_goodbyes += 1;
                std.debug.print("Got Goodbye (count: {}, total_goodbyes: {})\n", .{ state.count, state.total_goodbyes });
            },
            .Ping => {
                state.count += 1;
                state.total_pings += 1;
                const num = msg.data.Ping;
                std.debug.print("Got Ping: {} (count: {}, total_pings: {})\n", .{ num, state.count, state.total_pings });
            },
            .GetCount => {
                std.debug.print("Current count: {}, hellos: {}, pings: {}, goodbyes: {}\n", .{ state.count, state.total_hellos, state.total_pings, state.total_goodbyes });
            },
            .Reset => {
                state.count = 0;
                state.total_pings = 0;
                state.total_hellos = 0;
                state.total_goodbyes = 0;
                std.debug.print("State reset\n", .{});
            },
        }
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

    // Initialize with base state
    var base_msg = FirstMessage.init(allocator);

    var hello_msg = base_msg.hello("World");
    try engine.send(FirstMessage, &hello_msg);

    var status_msg = base_msg.ping(1);
    try engine.send(FirstMessage, &status_msg);

    var status_msg1 = base_msg.ping(2);
    try engine.send(FirstMessage, &status_msg1);

    var status_msg2 = base_msg.ping(3);
    try engine.send(FirstMessage, &status_msg2);

    var reset_msg = base_msg.reset();
    try engine.send(FirstMessage, &reset_msg);

    engine.start();
}

const std = @import("std");
const xev = @import("xev");
const builtin = @import("builtin");
const context = @import("context.zig");
const Actor = @import("actor.zig").Actor;
const ActorThread = @import("actor_thread.zig");
const ActorInterface = @import("actor_interface.zig");
const ActorEngine = @import("actor_engine.zig");

pub const SimpleMessage = union(enum) {
    Hello: []const u8,
    Goodbye: void,
    Ping: u32,
    GetCount: void,
    Reset: void,

    const Self = @This();
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

    // Initialize with default state
    // Initialize with default state
    pub fn init(allocator: std.mem.Allocator) SimpleMessage {
        _ = allocator;
        return SimpleMessage.GetCount;
    }

    // Convenience constructors
    pub fn hello_req(name: []const u8) SimpleMessage {
        return SimpleMessage{ .Hello = name };
    }

    pub fn goodbye_req() SimpleMessage {
        return SimpleMessage.Goodbye;
    }

    pub fn ping_req(value: u32) SimpleMessage {
        return SimpleMessage{ .Ping = value };
    }

    pub fn getCount_req() SimpleMessage {
        return SimpleMessage.GetCount;
    }

    pub fn reset_req() SimpleMessage {
        return SimpleMessage.Reset;
    }

    pub fn handle(self: *Actor(Self), msg: SimpleMessage) ?void {
        // Get or initialize state
        var state = self.getState(State) orelse blk: {
            const new_state = State.init(self.allocator) catch |err| {
                std.debug.print("Failed to initialize state: {}\n", .{err});
                return null;
            };

            self.setState(new_state);
            break :blk self.getState(State).?;
        };
        switch (msg) {
            .Hello => |name| {
                state.count += 1;
                state.total_hellos += 1;
                std.debug.print("Got Hello: {s} (count: {}, total_hellos: {})\n", .{ name, state.count, state.total_hellos });
            },
            .Goodbye => {
                state.count += 1;
                state.total_goodbyes += 1;
                std.debug.print("Got Goodbye (count: {}, total_goodbyes: {})\n", .{ state.count, state.total_goodbyes });
            },
            .Ping => |num| {
                state.count += 1;
                state.total_pings += 1;
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

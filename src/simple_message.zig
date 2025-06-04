const std = @import("std");
const Actor = @import("actor.zig");

pub const SimpleMessage = struct {
    // State fields
    count: u32 = 0,
    total_operations: u32 = 0,
    value: i32 = 0,
    allocator: std.mem.Allocator,

    // Command fields
    action: Action,
    parameter: i32 = 0,
    text: ?[]const u8 = null,

    const Action = enum {
        Increment,
        Decrement,
        SetValue,
        AddValue,
        PrintStatus,
        Reset,
        SayHello,
    };

    pub fn init(allocator: std.mem.Allocator) SimpleMessage {
        return SimpleMessage{
            .allocator = allocator,
            .action = .PrintStatus,
        };
    }

    // Convenience constructors
    pub fn increment(self: SimpleMessage) SimpleMessage {
        var new_msg = self;
        new_msg.action = .Increment;
        return new_msg;
    }

    pub fn decrement(self: SimpleMessage) SimpleMessage {
        var new_msg = self;
        new_msg.action = .Decrement;
        return new_msg;
    }

    pub fn setValue(self: SimpleMessage, val: i32) SimpleMessage {
        var new_msg = self;
        new_msg.action = .SetValue;
        new_msg.parameter = val;
        return new_msg;
    }

    pub fn addValue(self: SimpleMessage, val: i32) SimpleMessage {
        var new_msg = self;
        new_msg.action = .AddValue;
        new_msg.parameter = val;
        return new_msg;
    }

    pub fn sayHello(self: SimpleMessage, name: []const u8) SimpleMessage {
        var new_msg = self;
        new_msg.action = .SayHello;
        new_msg.text = name;
        return new_msg;
    }

    pub fn printStatus(self: SimpleMessage) SimpleMessage {
        var new_msg = self;
        new_msg.action = .PrintStatus;
        return new_msg;
    }

    pub fn reset(self: SimpleMessage) SimpleMessage {
        var new_msg = self;
        new_msg.action = .Reset;
        return new_msg;
    }

    // Handler that directly modifies the state
    pub fn handle(self: *Actor.Actor(SimpleMessage), msg: SimpleMessage) ?void {
        _ = self; // autofix
        var updated_msg = msg;
        updated_msg.total_operations += 1;

        switch (msg.action) {
            .Increment => {
                updated_msg.count += 1;
                updated_msg.value += 1;
                std.debug.print("Incremented: count={}, value={}, total_ops={}\n", .{ updated_msg.count, updated_msg.value, updated_msg.total_operations });
            },
            .Decrement => {
                updated_msg.count += 1;
                updated_msg.value -= 1;
                std.debug.print("Decremented: count={}, value={}, total_ops={}\n", .{ updated_msg.count, updated_msg.value, updated_msg.total_operations });
            },
            .SetValue => {
                updated_msg.count += 1;
                updated_msg.value = msg.parameter;
                std.debug.print("Set value to {}: count={}, total_ops={}\n", .{ updated_msg.value, updated_msg.count, updated_msg.total_operations });
            },
            .AddValue => {
                updated_msg.count += 1;
                updated_msg.value += msg.parameter;
                std.debug.print("Added {}: count={}, value={}, total_ops={}\n", .{ msg.parameter, updated_msg.count, updated_msg.value, updated_msg.total_operations });
            },
            .SayHello => {
                updated_msg.count += 1;
                const name = msg.text orelse "Anonymous";
                std.debug.print("Hello {s}! count={}, total_ops={}\n", .{ name, updated_msg.count, updated_msg.total_operations });
            },
            .PrintStatus => {
                std.debug.print("Status: count={}, value={}, total_ops={}\n", .{ updated_msg.count, updated_msg.value, updated_msg.total_operations });
            },
            .Reset => {
                updated_msg.count = 0;
                updated_msg.value = 0;
                updated_msg.total_operations = 0;
                std.debug.print("State reset\n", .{});
            },
        }

        return updated_msg;
    }
};

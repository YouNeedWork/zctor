const std = @import("std");
const zctor = @import("zctor");
const Actor = zctor.Actor;
const ActorEngine = zctor.ActorEngine;
const ActorThread = zctor.ActorThread;

// Calculator actor for mathematical operations
const CalculatorMessage = union(enum) {
    Add: struct { a: i32, b: i32 },
    Multiply: struct { a: i32, b: i32 },

    const Self = @This();

    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        const thread_id = actor.getContext().thread_id;
        switch (msg) {
            .Add => |op| {
                std.debug.print("[Thread {}] Calculator: {} + {} = ", .{ thread_id, op.a, op.b });
                const result_ptr = actor.getAllocator().create(i32) catch return null;
                result_ptr.* = op.a + op.b;
                std.debug.print("{}\n", .{result_ptr.*});
                return result_ptr;
            },
            .Multiply => |op| {
                std.debug.print("[Thread {}] Calculator: {} * {} = ", .{ thread_id, op.a, op.b });
                const result_ptr = actor.getAllocator().create(i32) catch return null;
                result_ptr.* = op.a * op.b;
                std.debug.print("{}\n", .{result_ptr.*});
                return result_ptr;
            },
        }
    }
};

// Logger actor for logging messages
const LoggerMessage = union(enum) {
    Info: []const u8,
    Error: []const u8,

    const Self = @This();

    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        const thread_id = actor.getContext().thread_id;
        switch (msg) {
            .Info => |text| {
                std.debug.print("[Thread {}] INFO: {s}\n", .{ thread_id, text });
            },
            .Error => |text| {
                std.debug.print("[Thread {}] ERROR: {s}\n", .{ thread_id, text });
            },
        }
        return null; // Logger doesn't return values
    }
};

// Counter actor for counting operations
const CounterMessage = union(enum) {
    Increment: void,
    GetCount: void,

    const Self = @This();

    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        const thread_id = actor.getContext().thread_id;

        // Get or initialize counter state
        const counter = actor.getState(i32) orelse blk: {
            const new_counter = actor.getAllocator().create(i32) catch return null;
            new_counter.* = 0;
            actor.setState(new_counter);
            break :blk new_counter;
        };

        switch (msg) {
            .Increment => {
                counter.* += 1;
                std.debug.print("[Thread {}] Counter incremented to: {}\n", .{ thread_id, counter.* });
            },
            .GetCount => {
                std.debug.print("[Thread {}] Current count: {}\n", .{ thread_id, counter.* });
                const result_ptr = actor.getAllocator().create(i32) catch return null;
                result_ptr.* = counter.*;
                return result_ptr;
            },
        }
        return null;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try ActorEngine.init(allocator);
    defer engine.deinit();

    std.debug.print("Creating multi-threaded actor system...\n", .{});
    std.debug.print("Available CPU cores: {}\n", .{std.Thread.getCpuCount() catch unreachable});

    // Create thread 1 with Calculator actor
    const thread1 = try ActorThread.init(allocator);
    try thread1.registerActor(try Actor(CalculatorMessage).init(allocator, CalculatorMessage.handle));
    try engine.spawn(thread1);

    // Create thread 2 with Logger actor
    const thread2 = try ActorThread.init(allocator);
    try thread2.registerActor(try Actor(LoggerMessage).init(allocator, LoggerMessage.handle));
    try engine.spawn(thread2);

    // Create thread 3 with Counter actor
    const thread3 = try ActorThread.init(allocator);
    try thread3.registerActor(try Actor(CounterMessage).init(allocator, CounterMessage.handle));
    try engine.spawn(thread3);

    std.debug.print("\nActor registry:\n", .{});
    const registry = engine.getActorRegistry();
    var iter = registry.iterator();
    while (iter.next()) |entry| {
        std.debug.print("  {s} -> Thread {}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    // Give threads time to start
    std.time.sleep(100 * std.time.ns_per_ms);

    std.debug.print("\n=== Testing multi-threaded operations ===\n", .{});

    // Test Calculator operations
    var add_msg = CalculatorMessage{ .Add = .{ .a = 10, .b = 5 } };
    var mul_msg = CalculatorMessage{ .Multiply = .{ .a = 7, .b = 3 } };

    // Test Logger operations
    var info_msg = LoggerMessage{ .Info = "System started successfully" };
    var error_msg = LoggerMessage{ .Error = "This is a test error" };

    // Test Counter operations
    var inc_msg = CounterMessage{ .Increment = {} };
    var get_msg = CounterMessage{ .GetCount = {} };

    // Send messages to different threads
    try engine.send(LoggerMessage, &info_msg);

    // Perform calculations
    const add_result = try engine.call(CalculatorMessage, &add_msg);
    if (add_result) |ptr| {
        const result_ptr = @as(*i32, @ptrCast(@alignCast(ptr)));
        std.debug.print("Main: Addition result received: {}\n", .{result_ptr.*});
        allocator.destroy(result_ptr);
    }

    const mul_result = try engine.call(CalculatorMessage, &mul_msg);
    if (mul_result) |ptr| {
        const result_ptr = @as(*i32, @ptrCast(@alignCast(ptr)));
        std.debug.print("Main: Multiplication result received: {}\n", .{result_ptr.*});
        allocator.destroy(result_ptr);
    }

    // Test counter
    try engine.send(CounterMessage, &inc_msg);
    try engine.send(CounterMessage, &inc_msg);
    try engine.send(CounterMessage, &inc_msg);

    const count_result = try engine.call(CounterMessage, &get_msg);
    if (count_result) |ptr| {
        const result_ptr = @as(*i32, @ptrCast(@alignCast(ptr)));
        std.debug.print("Main: Counter result received: {}\n", .{result_ptr.*});
        allocator.destroy(result_ptr);
    }

    try engine.send(LoggerMessage, &error_msg);

    std.debug.print("\n=== All operations completed ===\n", .{});

    // Start the engine to process remaining messages
    engine.start();
}

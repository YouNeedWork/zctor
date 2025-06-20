const std = @import("std");
const zctor = @import("zctor");
const Actor = zctor.Actor;
const ActorEngine = zctor.ActorEngine;
const ActorThread = zctor.ActorThread;

// Define a message type with operations that return values
const CalculatorMessage = union(enum) {
    Add: struct { a: i32, b: i32 },
    Multiply: struct { a: i32, b: i32 },

    const Self = @This();

    // Handler returns a value for call operations
    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        switch (msg) {
            .Add => |op| {
                // Allocate result on heap so it survives the function call
                const result_ptr = actor.getAllocator().create(i32) catch return null;
                result_ptr.* = op.a + op.b;
                return result_ptr;
            },
            .Multiply => |op| {
                const result_ptr = actor.getAllocator().create(i32) catch return null;
                result_ptr.* = op.a * op.b;
                return result_ptr;
            },
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try ActorEngine.init(allocator);
    defer engine.deinit();

    const actor_thread = try ActorThread.init(allocator);
    try actor_thread.registerActor(try Actor(CalculatorMessage).init(allocator, CalculatorMessage.handle));

    // Spawn calculator actor
    try engine.spawn(actor_thread);

    // Create an addition message: 5 + 3
    var add_message = CalculatorMessage{ .Add = .{ .a = 5, .b = 3 } };

    // Call the actor and wait for the response
    const response_ptr = engine.call(CalculatorMessage, &add_message);
    if (response_ptr) |ptr| {
        // Cast the response back to the expected type (i32)
        const result_ptr = @as(*i32, @ptrCast(@alignCast(ptr)));
        const result = result_ptr.*;
        std.debug.print("Addition result: {} + {} = {}\n", .{ 5, 3, result });

        // Clean up the allocated result
        allocator.destroy(result_ptr);
    } else {
        std.debug.print("Error: No response received from calculator actor\n", .{});
    }

    // Start the engine to process messages
    engine.start();
}

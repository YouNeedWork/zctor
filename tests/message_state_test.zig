const std = @import("std");
const testing = std.testing;
const SimpleMessage = @import("../src/simple_message.zig").SimpleMessage;

test "Message state persistence" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize message with state
    var msg = SimpleMessage.init(allocator);

    // Simulate state changes
    msg = msg.increment();
    try testing.expectEqual(@as(u32, 0), msg.count); // count updated in handler

    msg = msg.setValue(42);
    msg = msg.addValue(8);

    // State should be preserved in the message structure
    try testing.expectEqual(@as(i32, 42), msg.parameter); // Last parameter set
}

test "Message convenience constructors" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var base_msg = SimpleMessage.init(allocator);
    base_msg.count = 5; // Set some initial state

    const inc_msg = base_msg.increment();
    const set_msg = base_msg.setValue(100);
    const hello_msg = base_msg.sayHello("Test");

    // All should preserve the base state
    try testing.expectEqual(@as(u32, 5), inc_msg.count);
    try testing.expectEqual(@as(u32, 5), set_msg.count);
    try testing.expectEqual(@as(u32, 5), hello_msg.count);

    // But have different actions/parameters
    try testing.expectEqual(SimpleMessage.Action.Increment, inc_msg.action);
    try testing.expectEqual(SimpleMessage.Action.SetValue, set_msg.action);
    try testing.expectEqual(@as(i32, 100), set_msg.parameter);
    try testing.expectEqual(SimpleMessage.Action.SayHello, hello_msg.action);
    try testing.expectEqualStrings("Test", hello_msg.text.?);
}

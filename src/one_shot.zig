const std = @import("std");
const testing = std.testing;

/// A one-shot channel that can send exactly one value from sender to receiver
/// Uses atomic operations and spinning for synchronization
pub fn OneShotChannel(comptime T: type) type {
    return struct {
        const Self = @This();

        // Channel states
        const State = enum(u32) {
            Empty = 0, // No value sent yet
            Sending = 1, // Currently being written to
            Ready = 2, // Value is ready to be read
            Consumed = 3, // Value has been consumed
        };

        // Atomic state and data storage
        state: std.atomic.Value(u32),
        data: T,

        /// Initialize an empty one-shot channel
        pub fn init() Self {
            return Self{
                .state = std.atomic.Value(u32).init(@intFromEnum(State.Empty)),
                .data = undefined, // Will be set when sending
            };
        }

        /// Send a value through the channel
        /// Returns true if successful, false if already used
        pub fn send(self: *Self, value: T) bool {
            // Try to transition from Empty to Sending
            const expected = @intFromEnum(State.Empty);
            const desired = @intFromEnum(State.Sending);

            if (self.state.cmpxchgWeak(expected, desired, .acquire, .monotonic)) |_| {
                // Channel was already used
                return false;
            }

            // We successfully claimed the channel for sending
            // Store the data
            self.data = value;

            // Mark as ready
            self.state.store(@intFromEnum(State.Ready), .release);
            return true;
        }

        /// Receive a value from the channel (blocking with spinning)
        /// Returns the value if successful, null if channel was already consumed
        pub fn receive(self: *Self) ?T {
            while (true) {
                const current_state = self.state.load(.acquire);

                switch (@as(State, @enumFromInt(current_state))) {
                    .Empty, .Sending => {
                        // Still waiting for sender, spin
                        std.atomic.spinLoopHint();
                        continue;
                    },
                    .Ready => {
                        // Try to transition to Consumed
                        const expected = @intFromEnum(State.Ready);
                        const desired = @intFromEnum(State.Consumed);

                        if (self.state.cmpxchgWeak(expected, desired, .acquire, .monotonic) == null) {
                            // Successfully consumed the value
                            return self.data;
                        }
                        // Someone else consumed it, continue spinning
                        continue;
                    },
                    .Consumed => {
                        // Channel was already consumed
                        return null;
                    },
                }
            }
        }

        /// Try to receive without blocking
        /// Returns the value if available, null otherwise
        pub fn tryReceive(self: *Self) ?T {
            const current_state = self.state.load(.acquire);

            if (current_state == @intFromEnum(State.Ready)) {
                const expected = @intFromEnum(State.Ready);
                const desired = @intFromEnum(State.Consumed);

                if (self.state.cmpxchgWeak(expected, desired, .acquire, .monotonic) == null) {
                    return self.data;
                }
            }

            return null;
        }

        /// Check if the channel is ready to be consumed
        pub fn isReady(self: *Self) bool {
            return self.state.load(.acquire) == @intFromEnum(State.Ready);
        }

        /// Check if the channel has been consumed
        pub fn isConsumed(self: *Self) bool {
            return self.state.load(.acquire) == @intFromEnum(State.Consumed);
        }

        /// Check if the channel is still empty
        pub fn isEmpty(self: *Self) bool {
            const current_state = self.state.load(.acquire);
            return current_state == @intFromEnum(State.Empty) or
                current_state == @intFromEnum(State.Sending);
        }
    };
}

/// Convenience wrapper that provides sender and receiver handles
pub fn oneShotChannel(comptime T: type) struct { sender: Sender(T), receiver: Receiver(T) } {
    const channel = std.heap.page_allocator.create(OneShotChannel(T)) catch unreachable;
    channel.* = OneShotChannel(T).init();

    return .{
        .sender = Sender(T){ .channel = channel },
        .receiver = Receiver(T){ .channel = channel },
    };
}

/// Sender handle for one-shot channel
pub fn Sender(comptime T: type) type {
    return struct {
        const Self = @This();
        channel: *OneShotChannel(T),

        pub fn send(self: Self, value: T) bool {
            return self.channel.send(value);
        }

        pub fn deinit(self: Self) void {
            std.heap.page_allocator.destroy(self.channel);
        }
    };
}

/// Receiver handle for one-shot channel
pub fn Receiver(comptime T: type) type {
    return struct {
        const Self = @This();
        channel: *OneShotChannel(T),

        pub fn receive(self: Self) ?T {
            return self.channel.receive();
        }

        pub fn tryReceive(self: Self) ?T {
            return self.channel.tryReceive();
        }

        pub fn isReady(self: Self) bool {
            return self.channel.isReady();
        }

        pub fn isConsumed(self: Self) bool {
            return self.channel.isConsumed();
        }

        pub fn isEmpty(self: Self) bool {
            return self.channel.isEmpty();
        }
    };
}

// Tests
test "OneShotChannel basic send and receive" {
    var channel = OneShotChannel(i32).init();

    // Should be empty initially
    try testing.expect(channel.isEmpty());
    try testing.expect(!channel.isReady());
    try testing.expect(!channel.isConsumed());

    // Send a value
    try testing.expect(channel.send(42));
    try testing.expect(channel.isReady());
    try testing.expect(!channel.isEmpty());

    // Can't send again
    try testing.expect(!channel.send(24));

    // Receive the value
    const received = channel.receive();
    try testing.expectEqual(@as(i32, 42), received.?);

    // Should be consumed now
    try testing.expect(channel.isConsumed());
    try testing.expect(!channel.isReady());

    // Can't receive again
    try testing.expectEqual(@as(?i32, null), channel.receive());
}

test "OneShotChannel try receive" {
    var channel = OneShotChannel([]const u8).init();

    // Try receive on empty channel
    try testing.expectEqual(@as(?[]const u8, null), channel.tryReceive());

    // Send a value
    try testing.expect(channel.send("Hello"));

    // Try receive should work
    const received = channel.tryReceive();
    try testing.expectEqualStrings("Hello", received.?);

    // Try receive on consumed channel
    try testing.expectEqual(@as(?[]const u8, null), channel.tryReceive());
}

test "OneShotChannel with sender/receiver handles" {
    const pair = oneShotChannel(u64);
    defer pair.sender.deinit();

    // Test through handles
    try testing.expect(pair.sender.send(12345));
    try testing.expect(!pair.sender.send(67890)); // Can't send twice

    try testing.expect(pair.receiver.isReady());
    const received = pair.receiver.receive();
    try testing.expectEqual(@as(u64, 12345), received.?);

    try testing.expect(pair.receiver.isConsumed());
}

test "OneShotChannel threaded communication" {
    const pair = oneShotChannel(i32);
    defer pair.sender.deinit();

    const TestContext = struct {
        sender: Sender(i32),
        result: std.atomic.Value(i32),

        fn senderThread(ctx: *@This()) void {
            // Wait a bit to ensure receiver is spinning
            std.time.sleep(10 * std.time.ns_per_ms);
            _ = ctx.sender.send(999);
        }

        fn receiverThread(ctx: *@This(), receiver: Receiver(i32)) void {
            if (receiver.receive()) |value| {
                ctx.result.store(value, .release);
            }
        }
    };

    var test_ctx = TestContext{
        .sender = pair.sender,
        .result = std.atomic.Value(i32).init(0),
    };

    // Start threads
    const sender_thread = try std.Thread.spawn(.{}, TestContext.senderThread, .{&test_ctx});
    const receiver_thread = try std.Thread.spawn(.{}, TestContext.receiverThread, .{ &test_ctx, pair.receiver });

    // Wait for completion
    sender_thread.join();
    receiver_thread.join();

    // Check result
    try testing.expectEqual(@as(i32, 999), test_ctx.result.load(.acquire));
}

test "OneShotChannel multiple readers race condition" {
    const pair = oneShotChannel(i32);
    defer pair.sender.deinit();

    const TestContext = struct {
        receiver: Receiver(i32),
        results: [2]std.atomic.Value(i32),

        fn readerThread(ctx: *@This(), index: usize) void {
            if (ctx.receiver.receive()) |value| {
                ctx.results[index].store(value, .release);
            } else {
                ctx.results[index].store(-1, .release); // Mark as failed
            }
        }
    };

    var test_ctx = TestContext{
        .receiver = pair.receiver,
        .results = [_]std.atomic.Value(i32){
            std.atomic.Value(i32).init(0),
            std.atomic.Value(i32).init(0),
        },
    };

    // Start two reader threads
    const reader1 = try std.Thread.spawn(.{}, TestContext.readerThread, .{ &test_ctx, 0 });
    const reader2 = try std.Thread.spawn(.{}, TestContext.readerThread, .{ &test_ctx, 1 });

    // Send value
    try testing.expect(pair.sender.send(777));

    // Wait for completion
    reader1.join();
    reader2.join();

    // Exactly one should succeed, one should fail
    const result1 = test_ctx.results[0].load(.acquire);
    const result2 = test_ctx.results[1].load(.acquire);

    const success_count = @as(u8, if (result1 == 777) 1 else 0) + @as(u8, if (result2 == 777) 1 else 0);
    const fail_count = @as(u8, if (result1 == -1) 1 else 0) + @as(u8, if (result2 == -1) 1 else 0);

    try testing.expectEqual(@as(u8, 1), success_count);
    try testing.expectEqual(@as(u8, 1), fail_count);
}

const std = @import("std");
const Context = @import("context.zig");
const xev = @import("xev");
const OneShot = @import("one_shot.zig").OneShot;

/// Generic Actor implementation that processes messages of type T
/// Supports both fire-and-forget (send) and request-response (call) patterns
pub fn Actor(comptime T: type) type {
    return struct {
        const Self = @This();

        // Define message types
        const MessageType = enum { send, call };

        const CallData = struct {
            msg: T,
            response_channel: *OneShot(*anyopaque),
        };

        const ActorMessage = union(MessageType) {
            send: T,
            call: CallData,
        };

        handler: *const fn (*Self, T) ?*anyopaque, // Handler can optionally return a value
        mailbox: std.fifo.LinearFifo(ActorMessage, .Dynamic),
        ctx: ?*Context,
        event: xev.Async,
        completion: xev.Completion,
        allocator: std.mem.Allocator,
        current_state: ?*anyopaque = null,

        /// Initialize a new actor with the given allocator and message handler
        /// The handler function should return a value for call operations, or null for send operations
        pub fn init(allocator: std.mem.Allocator, handler: *const fn (*Self, T) ?*anyopaque) !*Self {
            const self = try allocator.create(Self);

            comptime {
                if (@sizeOf(T) == 0)
                    @compileError("LinearFifo not support size=0 type");
            }

            self.* = Self{
                .handler = handler,
                .mailbox = std.fifo.LinearFifo(ActorMessage, .Dynamic).init(allocator),
                .ctx = null,
                .event = try xev.Async.init(),
                .completion = undefined,
                .allocator = allocator,
            };

            return self;
        }

        fn actorCallback(
            userdata: ?*Self,
            loop: *xev.Loop,
            completion: *xev.Completion,
            result: xev.Async.WaitError!void,
        ) xev.CallbackAction {
            _ = result catch {};
            _ = loop;
            _ = completion;

            const self = userdata.?;
            while (self.mailbox.readItem()) |actor_msg| {
                switch (actor_msg) {
                    .send => |msg| {
                        // Regular send - ignore return value
                        _ = self.handler(self, msg);
                    },
                    .call => |call_data| {
                        // Call - send response back through one-shot
                        const response = self.handler(self, call_data.msg);
                        if (response) |resp| {
                            if (!call_data.response_channel.send(resp)) {
                                std.debug.print("Warning: Failed to send response through channel\n", .{});
                            }
                        } else {
                            std.debug.print("Error: Handler returned null for call operation\n", .{});
                            @panic("Handler returned null for call operation");
                        }
                    },
                }
            }
            return .rearm;
        }

        pub fn run(self: *Self) void {
            self.setup_callback();
        }

        fn setup_callback(self: *Self) void {
            self.event.wait(self.ctx.?.loop, &self.completion, Self, self, Self.actorCallback);
        }

        /// Send a fire-and-forget message to the actor
        /// The message will be processed asynchronously without waiting for a response
        pub fn send(self: *Self, msg_ptr: *anyopaque) !void {
            const typed_msg = @as(*T, @ptrCast(@alignCast(msg_ptr)));
            return self.actor_send(typed_msg.*);
        }

        fn actor_send(self: *Self, msg: T) !void {
            const actor_msg = ActorMessage{ .send = msg };
            try self.mailbox.writeItem(actor_msg);
            try self.event.notify();
        }

        /// Send a request-response message to the actor and wait for the result
        /// Returns the response from the actor's handler function
        pub fn call(self: *Self, msg_ptr: *anyopaque) !*anyopaque {
            const typed_msg = @as(*T, @ptrCast(@alignCast(msg_ptr)));
            return self.actor_call(typed_msg.*);
        }

        fn actor_call(self: *Self, msg: T) !*anyopaque {
            // Create a one-shot channel for the response
            var response_channel = OneShot(*anyopaque).init();

            // Create call message using the named CallData type
            const call_data = CallData{
                .msg = msg,
                .response_channel = &response_channel,
            };

            const actor_msg = ActorMessage{ .call = call_data };

            // Send the message
            try self.mailbox.writeItem(actor_msg);
            try self.event.notify();

            // Wait for and return the response
            return response_channel.receive() orelse error.NoResponse;
        }

        pub fn add_ctx(self: *Self, ctx: *Context) void {
            self.ctx = ctx;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.mailbox.deinit();
            allocator.destroy(self);
        }

        pub fn getState(self: *Self, comptime S: anytype) ?*S {
            return @ptrCast(@alignCast(self.current_state));
        }

        pub fn setState(self: *Self, state: *anyopaque) void {
            self.current_state = state;
        }

        pub fn resetState(self: *Self) void {
            self.current_state = null;
        }

        pub fn getContext(self: *Self) *Context {
            return self.ctx.?;
        }

        pub fn getAllocator(self: *Self) std.mem.Allocator {
            return self.allocator;
        }
    };
}

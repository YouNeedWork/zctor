const std = @import("std");
const context = @import("context.zig");
const xev = @import("xev");

pub fn Actor(comptime T: type) type {
    return struct {
        const Self = @This();

        handler: *const fn (*Self, T) ?void, // Changed return type to ?T
        mailbox: std.fifo.LinearFifo(T, .Dynamic),
        ctx: *context,
        event: xev.Async,
        completion: xev.Completion,
        allocator: std.mem.Allocator,
        current_state: ?*anyopaque = null, // Store current state

        pub fn init(allocator: std.mem.Allocator, ctx: *context, handler: *const fn (*Self, T) ?void) !*Self {
            const self = try allocator.create(Self);
            self.* = Self{
                .handler = handler,
                .mailbox = std.fifo.LinearFifo(T, .Dynamic).init(allocator),
                .ctx = ctx,
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

            //const self: *Self = @ptrCast(@alignCast(userdata.?));
            const self = userdata.?; // Use the non-nullable version

            while (self.mailbox.readItem()) |msg| {
                // Handle the message and get updated state
                _ = self.handler(self, msg);
            }
            return .rearm;
        }

        pub fn run(self: *Self) void {
            self.setup_callback();
        }

        fn setup_callback(self: *Self) void {
            self.event.wait(self.ctx.loop, &self.completion, Self, self, Self.actorCallback);
        }

        pub fn handleRawMessage(self: *Self, msg_ptr: *anyopaque) !void {
            const typed_msg = @as(*T, @ptrCast(@alignCast(msg_ptr)));
            return self.sender(typed_msg.*);
        }

        pub fn sender(self: *Self, msg: T) !void {
            try self.mailbox.writeItem(msg);
            try self.event.notify();
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

        pub fn getContext(self: *Self) *context {
            return self.ctx;
        }

        pub fn getAllocator(self: *Self) std.mem.Allocator {
            return self.allocator;
        }
    };
}

const std = @import("std");
const context = @import("context.zig");
const xev = @import("xev");

pub fn Actor(comptime T: anytype) type {
    return struct {
        mailbox: std.fifo.LinearFifo(T, .{ .Static = 100 }),
        ctx: *context,
        event: xev.Async,
        completion: xev.Completion,
        handler: *const fn (*Actor(T), T) ?void,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, ctx: *context, f: fn (*Actor(T), T) ?void) !*Self {
            const self = try allocator.create(Self);

            self.* = .{
                .mailbox = std.fifo.LinearFifo(
                    T,
                    .{ .Static = 100 },
                ).init(),
                .ctx = ctx,
                .completion = undefined,
                .event = try xev.Async.init(),
                .handler = f,
            };

            return self;
        }

        fn actorCallback(
            ud: ?*Self,
            l: *xev.Loop,
            c: *xev.Completion,
            r: xev.Async.WaitError!void,
        ) xev.CallbackAction {
            _ = l;
            _ = c;
            _ = r catch unreachable;

            const self: *Self = ud.?;
            while (self.mailbox.readItem()) |msg| {
                self.handler(self, msg) orelse break;
            }

            return .rearm; // Rearm to receive more notifications
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
    };
}

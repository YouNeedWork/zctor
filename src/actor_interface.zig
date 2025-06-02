const std = @import("std");
const context = @import("context.zig");
const xev = @import("xev");

ptr: *anyopaque,
vtable: *const VTable,

const Self = @This();

pub const VTable = struct {
    run: *const fn (ptr: *anyopaque) void,
    deinit: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
    handleRawMessage: *const fn (ptr: *anyopaque, msg_ptr: *anyopaque) void,
    sender: *const fn (ptr: *anyopaque, msg_ptr: *anyopaque) anyerror!void,
};

pub fn run(self: Self) void {
    return self.vtable.run(self.ptr);
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    return self.vtable.deinit(self.ptr, allocator);
}

pub fn handleRawMessage(self: Self, msg: *anyopaque) void {
    return self.vtable.handleRawMessage(self.ptr, msg);
}

pub fn sender(self: Self, msg_ptr: *anyopaque) !void {
    return self.vtable.sender(self.ptr, msg_ptr);
}

pub fn init(actor: anytype) Self {
    const T = @TypeOf(actor);

    //TODO: check actor has the impl.

    // 为类型 T 创建静态 vtable
    const vtable = comptime blk: {
        //const alignment = @alignOf(T);

        const runFn = struct {
            fn function(ptr: *anyopaque) void {
                const self: T = @ptrCast(@alignCast(ptr));
                self.run();
            }
        }.function;

        const deinitFn = struct {
            fn function(ptr: *anyopaque, allocator: std.mem.Allocator) void {
                const self: T = @ptrCast(@alignCast(ptr));
                self.deinit(allocator);
            }
        }.function;

        const handleRawMessageFn = struct {
            fn function(ptr: *anyopaque, msg_ptr: *anyopaque) void {
                const self: T = @ptrCast(@alignCast(ptr));
                self.handleRawMessage(msg_ptr) catch {
                    std.debug.print("failed to process message", .{});
                };
            }
        }.function;

        const senderFn = struct {
            fn function(ptr: *anyopaque, msg_ptr: *anyopaque) anyerror!void {
                const self: T = @ptrCast(@alignCast(ptr));
                return self.handleRawMessage(msg_ptr);
            }
        }.function;

        break :blk &VTable{
            .run = runFn,
            .deinit = deinitFn,
            .handleRawMessage = handleRawMessageFn,
            .sender = senderFn,
        };
    };

    return .{
        .ptr = actor,
        .vtable = vtable,
    };
}

const std = @import("std");
const Context = @import("context.zig");
const xev = @import("xev");

ptr: *anyopaque,
vtable: *const VTable,

const Self = @This();

pub const VTable = struct {
    run: *const fn (ptr: *anyopaque) void,
    deinit: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
    handleRawMessage: *const fn (ptr: *anyopaque, msg_ptr: *anyopaque) void,
    add_ctx: *const fn (ptr: *anyopaque, ctx: *Context) void,
};

pub fn run(self: Self) void {
    return self.vtable.run(self.ptr);
}

pub fn add_ctx(self: Self, ctx: *Context) void {
    return self.vtable.add_ctx(self.ptr, ctx);
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    return self.vtable.deinit(self.ptr, allocator);
}

pub fn handleRawMessage(self: Self, msg: *anyopaque) void {
    return self.vtable.handleRawMessage(self.ptr, msg);
}

pub fn init(actor: anytype) Self {
    const T = @TypeOf(actor);

    //TODO: check actor has the impl.

    const vtable = comptime blk: {
        const add_ctxFn = struct {
            fn function(ptr: *anyopaque, ctx: *Context) void {
                const self: T = @ptrCast(@alignCast(ptr));
                self.add_ctx(ctx);
            }
        }.function;

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

        break :blk &VTable{
            .run = runFn,
            .deinit = deinitFn,
            .handleRawMessage = handleRawMessageFn,
            .add_ctx = add_ctxFn,
        };
    };

    return .{
        .ptr = actor,
        .vtable = vtable,
    };
}

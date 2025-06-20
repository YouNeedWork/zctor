const std = @import("std");
const Context = @import("context.zig");

ptr: *anyopaque,
vtable: *const VTable,

const Self = @This();

pub const VTable = struct {
    run: *const fn (ptr: *anyopaque) void,
    deinit: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
    send: *const fn (ptr: *anyopaque, msg_ptr: *anyopaque) void,
    call: *const fn (ptr: *anyopaque, msg_ptr: *anyopaque) ?*anyopaque,
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

pub fn call(self: Self, msg: *anyopaque) ?*anyopaque {
    return self.vtable.call(self.ptr, msg);
}

pub fn send(self: Self, msg: *anyopaque) void {
    return self.vtable.send(self.ptr, msg);
}

pub fn init(actor: anytype) Self {
    const T = @TypeOf(actor);

    // Note: Actor interface validation is done at runtime

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

        const sendFn = struct {
            fn function(ptr: *anyopaque, msg_ptr: *anyopaque) void {
                const self: T = @ptrCast(@alignCast(ptr));
                self.send(msg_ptr) catch |err| {
                    std.debug.print("Failed to process message: {}\n", .{err});
                };
            }
        }.function;

        const callFn = struct {
            fn function(ptr: *anyopaque, msg_ptr: *anyopaque) ?*anyopaque {
                const self: T = @ptrCast(@alignCast(ptr));
                const res = self.call(msg_ptr) catch |err| {
                    std.debug.print("failed to process message: {}\n", .{err});
                    return null;
                };
                return res;
            }
        }.function;

        break :blk &VTable{
            .run = runFn,
            .deinit = deinitFn,
            .send = sendFn,
            .call = callFn,
            .add_ctx = add_ctxFn,
        };
    };

    return .{
        .ptr = actor,
        .vtable = vtable,
    };
}

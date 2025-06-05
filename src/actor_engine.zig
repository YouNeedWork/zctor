const std = @import("std");
const context = @import("context.zig");
const xev = @import("xev");
const ActorInterface = @import("actor_interface.zig");
const Actor = @import("actor.zig");
const ActorThread = @import("actor_thread.zig");

allocator: std.mem.Allocator,
actor_threads: [128]*ActorThread,
wg: std.Thread.WaitGroup,
threads: [128]std.Thread, // 修复: 存储实际的线程对象
thread_count: usize, // 修复: 重命名为更清晰的名称
thread_idx: usize,

const Self = @This();

pub fn init(allocator: std.mem.Allocator) !*Self {
    const self = try allocator.create(Self);
    self.allocator = allocator;

    const cpu_count = try std.Thread.getCpuCount();
    self.thread_count = cpu_count;
    self.thread_idx = 0; // The global actor running on zero Thread idx

    self.wg.reset();
    return self;
}

pub fn deinit(self: *Self) void {
    // 等待所有线程完成
    for (0..self.thread_idx) |i| {
        self.threads[i].join();
    }

    // 清理 actor_threads
    for (0..self.thread_idx) |i| {
        self.actor_threads[i].deinit(self.allocator);
    }

    self.allocator.destroy(self);
}

pub fn start(self: *Self) void {
    std.debug.print("Actor Engine Started\n", .{});
    self.wg.wait();
}

pub fn stop(self: *Self) void {
    for (0..self.thread_idx) |i| {
        self.actor_threads[i].stop();
        self.wg.finish();
    }
}

pub fn spawn(self: *Self, comptime T: anytype, handle: fn (*Actor.Actor(T), T) ?void) !void {
    if (self.thread_idx >= self.thread_count) {
        return error.TooManyThreads;
    }

    const actor_thread = ActorThread.init(self.allocator, self, @intCast(self.thread_idx)) catch |err| {
        std.debug.print("failed to init actor thread {} with error: {} \n", .{ self.thread_idx, err });
        return err;
    };
    self.actor_threads[self.thread_idx] = actor_thread;
    // 注册 Actor 到线程
    try actor_thread.registerActor(try Actor.Actor(T).init(self.allocator, actor_thread.ctx, handle));
    try actor_thread.run();

    // 启动线程
    const current_idx = self.thread_idx;
    self.thread_idx += 1;

    const t = try std.Thread.spawn(.{}, thread_run, .{ self, current_idx });
    self.threads[current_idx] = t;
    self.wg.start();
}

// 实现 thread_run 方法
fn thread_run(self: *Self, thread_idx: usize) void {
    defer self.wg.finish();

    std.debug.print("Thread {} starting...\n", .{thread_idx});

    const actor_thread = self.actor_threads[thread_idx];

    // 启动事件循环
    actor_thread.start_loop() catch |err| {
        std.debug.print("Thread {} failed to start loop: {}\n", .{ thread_idx, err });
        return;
    };

    std.debug.print("Thread {} finished\n", .{thread_idx});
}

pub fn send(self: *Self, comptime T: anytype, msg_ptr: *anyopaque) !void {
    const typed_ptr: *T = @ptrCast(@alignCast(msg_ptr));
    try self.actor_threads[0].send(T, typed_ptr);
}

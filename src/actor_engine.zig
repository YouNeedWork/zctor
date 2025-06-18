const std = @import("std");
const context = @import("context.zig");
const xev = @import("xev");
const ActorInterface = @import("actor_interface.zig");
const Actor = @import("actor.zig");
const ActorThread = @import("actor_thread.zig");

allocator: std.mem.Allocator,
actor_threads: [128]*ActorThread,
wg: std.Thread.WaitGroup,
threads: [128]std.Thread,
thread_count: usize,
thread_idx: usize,

const Self = @This();

pub fn init(allocator: std.mem.Allocator) !*Self {
    const self = try allocator.create(Self);
    self.allocator = allocator;

    const cpu_count = try std.Thread.getCpuCount();
    self.thread_count = cpu_count;
    self.thread_idx = 0;

    self.wg.reset();
    return self;
}

pub fn deinit(self: *Self) void {
    for (0..self.thread_idx) |i| {
        self.threads[i].join();
    }

    for (0..self.thread_idx) |i| {
        self.actor_threads[i].deinit(self.allocator);
    }

    self.allocator.destroy(self);
}

pub fn start(self: *Self) void {
    self.wg.wait();
}

pub fn stop(self: *Self) void {
    for (0..self.thread_idx) |i| {
        self.actor_threads[i].stop();
        self.wg.finish();
    }
}

pub fn spawn(self: *Self, actor_thread: *ActorThread) !void {
    if (self.thread_idx >= self.thread_count) {
        return error.TooManyThreads;
    }

    try actor_thread.init_ctx(self, @bitCast(self.thread_idx));
    try actor_thread.run();

    self.actor_threads[self.thread_idx] = actor_thread;
    const current_idx = self.thread_idx;
    self.thread_idx += 1;

    const t = try std.Thread.spawn(.{}, thread_run, .{ self, current_idx });
    self.threads[current_idx] = t;
    self.wg.start();
}

fn thread_run(self: *Self, thread_idx: usize) void {
    defer self.wg.finish();
    const actor_thread = self.actor_threads[thread_idx];

    actor_thread.start_loop() catch |err| {
        std.debug.print("Thread {} failed to start loop: {}\n", .{ thread_idx, err });
        return;
    };
}

pub fn send(self: *Self, comptime T: anytype, msg_ptr: *anyopaque) !void {
    const typed_ptr: *T = @ptrCast(@alignCast(msg_ptr));
    try self.actor_threads[0].send(T, typed_ptr);
}

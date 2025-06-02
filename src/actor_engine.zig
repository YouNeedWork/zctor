const std = @import("std");
const context = @import("context.zig");
const xev = @import("xev");
const ActorInterface = @import("actor_interface.zig");
const Actor = @import("actor.zig");
const ActorThread = @import("actor_thread.zig");

allocator: std.mem.Allocator,
actor_threads: [128]*ActorThread,
wg: std.Thread.WaitGroup,
threads: usize,
thread_idx: usize,

const Self = @This();

pub fn init(allocator: std.mem.Allocator) !*Self {
    const self = try allocator.create(Self);
    self.allocator = allocator;

    const cpu_count = try std.Thread.getCpuCount();
    self.threads = cpu_count;
    self.thread_idx = 0; //The global actor running on zero Thread idx

    self.wg.reset();
    return self;
}

pub fn deinit(self: *Self) void {
    self.allocator.destroy(self);
}

pub fn start(self: *Self) void {
    //   for (0..thread_count) |i| {
    //       const t = try std.Thread.spawn(.{}, thread_run, .{ self, i });
    //      self.threads[i] = t;
    //       t.detach();
    //   }
    std.debug.print("Actor Engine Started\n", .{});
    self.wg.wait();
}

pub fn stop(self: *Self) void {
    for (0..self.threads) |i| {
        self.actor_threads[i].stop();
        self.wg.finish();
    }
}

pub fn spawn(self: *Self, comptime T: anytype, handle: fn (*Actor.Actor(T), T) ?void) !void {
    const actor_thread = ActorThread.init(self.allocator, @intCast(self.thread_idx)) catch |err| {
        std.debug.print("failed to init actor thread {} with error: {} \n", .{ self.thread_idx, err });
        return err;
    };

    self.actor_threads[self.thread_idx] = actor_thread;
    self.thread_idx += 1;

    //TODO: lack of finish() call when the thread exit()
    try actor_thread.registerActor(try Actor.Actor(T).init(self.allocator, actor_thread.ctx, handle));
    try actor_thread.run();

    self.wg.start();
}

pub fn spawn_each_thread(self: *Self, idx: usize) !void {
    const actor_thread = ActorThread.init(self.allocator, @intCast(idx)) catch {
        std.debug.print("failed to init actor thread {}\n", .{idx});
        return;
    };

    self.actor_threads[idx] = actor_thread;

    try actor_thread.registerActor(try Actor(i32).init(self.allocator, actor_thread.ctx, struct {
        pub fn handle(s: *Actor(i32), msg: i32) ?void {
            std.debug.print("Thread Id: {} Got i32: {}\n", .{ s.ctx.thread_id, msg });
        }
    }.handle));

    actor_thread.deinit(self.allocator);
    self.wg.finish();
}

pub fn send(self: *Self, comptime T: type, msg_ptr: *T) !void {
    // For now, route to the first actor thread (thread 0)
    // In a more sophisticated implementation, this could use load balancing
    if (self.thread_idx > 0) {
        try self.actor_threads[0].send(T, msg_ptr);
    } else {
        return error.NoActorsSpawned;
    }
}

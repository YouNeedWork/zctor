const std = @import("std");
const xev = @import("xev");
const builtin = @import("builtin");
const context = @import("context.zig");
const Actor = @import("actor.zig");
const ActorThread = @import("actor_thread.zig");
const ActorInterface = @import("actor_interface.zig");

pub const FirstMessage = union(enum) {
    Hello: []const u8,
    Goodbye: void,
    Ping: u32,

    pub fn handle(self: *Actor.Actor(FirstMessage), msg: @This()) ?void {
        _ = self;

        switch (msg) {
            .Hello => |name| std.debug.print("Got Hello: {s}\n", .{name}),
            .Goodbye => std.debug.print("Got Goodbye\n", .{}),
            .Ping => |num| std.debug.print("Got Ping: {}\n", .{num}),
        }
        return null;
    }
};

const ActorEngine = struct {
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

    pub fn start(self: *Self, thread_count: u32) void {
        self.threads = thread_count;

        // self.wg.startMany(cpu_count);
        //
        //for (0..cpu_count) |i| {
        //     const t = try std.Thread.spawn(.{}, thread_run, .{ self, i });
        //     t.detach();
        // }

        self.wg.wait();
    }

    pub fn stop(self: *Self) void {
        for (0..self.threads) |i| {
            self.actor_threads[i].stop();
            self.wg.finish();
        }
    }

    // 等待所有线程完成
    pub fn wait(self: *Self) void {
        self.wg.wait();
    }

    pub fn spawn(self: *Self) !void {
        const actor_thread = ActorThread.init(self.allocator, @intCast(self.thread_idx)) catch |err| {
            std.debug.print("failed to init actor thread {} with error: {} \n", .{ self.thread_idx, err });
            return err;
        };

        self.actor_threads[self.thread_idx] = actor_thread;
        self.thread_idx += 1;

        //TODO: lack of finish() call when the thread exit()
        try actor_thread.registerActor(try Actor.Actor(FirstMessage).init(self.allocator, actor_thread.ctx, FirstMessage.handle));
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

        try actor_thread.registerActor(try Actor(FirstMessage).init(self.allocator, actor_thread.ctx, FirstMessage.handle));
        try actor_thread.run();

        var p: i32 = 10000;

        try actor_thread.sender(i32, &p);
        try actor_thread.sender(i32, &p);
        var s: FirstMessage = .{ .Ping = 0 };

        try actor_thread.sender(FirstMessage, &s);

        try actor_thread.start_loop();

        actor_thread.deinit(self.allocator);
        self.wg.finish();
    }
};

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const allocator, const is_debug = gpa: {
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    var engine = try ActorEngine.init(allocator);
    defer engine.deinit();
    try engine.spawn();
    engine.start(12);
}

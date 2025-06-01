const std = @import("std");
const xev = @import("xev");
const builtin = @import("builtin");
const context = @import("context.zig");

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

        // 添加一个处理原始消息的方法
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

const ActorThread = struct {
    loop: xev.Loop,
    ctx: *context,
    actors: std.StringArrayHashMap(ActorInterface),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, thread_id: i32) !*Self {
        const self = try allocator.create(Self);
        self.loop = try xev.Loop.init(.{});
        self.ctx = try context.init(allocator, &self.loop, thread_id);
        self.actors = std.StringArrayHashMap(ActorInterface).init(allocator);

        return self;
    }

    pub fn registerActor(self: *Self, actor: anytype) !void {
        const name = comptime @typeName(@TypeOf(actor.*));
        try self.actors.put(name, ActorInterface.init(actor));
    }

    pub fn sender(self: *Self, comptime T: type, msg: *T) !void {
        const name = comptime @typeName(Actor(T));
        if (self.actors.get(name)) |actor| {
            actor.handleRawMessage(msg);
        } else {
            return error.ActorNotFound;
        }
    }

    pub fn boradcase(self: *Self, T: type, msg_ptr: *anyopaque) void {
        _ = T;

        for (self.actors.items) |actor| {
            actor.sender(msg_ptr);
        }
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        var iter = self.actors.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }

        self.actors.deinit();

        self.ctx.deinit(allocator);
        self.loop.deinit();
        allocator.destroy(self);
    }

    pub fn run(self: *Self) !void {
        var iter = self.actors.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.run();
        }
    }

    pub fn start_loop(self: *Self) !void {
        try self.loop.run(.until_done);
    }
};

pub const FirstMessage = union(enum) {
    Hello: []const u8,
    Goodbye: void,
    Ping: u32,

    pub fn handle(self: *Actor(FirstMessage), msg: @This()) ?void {
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
        try actor_thread.registerActor(try Actor(FirstMessage).init(self.allocator, actor_thread.ctx, FirstMessage.handle));
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

pub const ActorInterface = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const Self = @This();

    pub const VTable = struct {
        run: *const fn (ptr: *anyopaque) void,
        deinit: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
        handleRawMessage: *const fn (ptr: *anyopaque, msg_ptr: *anyopaque) void,
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

    // 从任何类型创建一个 ActorInterface
    pub fn init(actor: anytype) ActorInterface {
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

            break :blk &VTable{
                .run = runFn,
                .deinit = deinitFn,
                .handleRawMessage = handleRawMessageFn,
            };
        };

        return .{
            .ptr = actor,
            .vtable = vtable,
        };
    }
};

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const gpa, const is_debug = gpa: {
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    var engine = try ActorEngine.init(gpa);
    defer engine.deinit();

    try engine.spawn();

    engine.start(12);
}

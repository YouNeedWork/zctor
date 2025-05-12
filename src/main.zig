const std = @import("std");
const typ = std.builtin.Type;
const xev = @import("xev");

pub const Context = struct {
    loop: *xev.Loop,
    thread_id: i32,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, loop: *xev.Loop, therad_id: i32) !*Self {
        const ctx = try allocator.create(Self);
        ctx.* = .{
            .loop = loop,
            .thread_id = therad_id,
        };

        return ctx;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }
};

pub fn Actor(comptime T: anytype) type {
    return struct {
        mailbox: std.fifo.LinearFifo(T, .{ .Static = 100 }),
        ctx: *Context,
        event: xev.Async,
        completion: xev.Completion,
        handler: *const fn (*Actor(T), T) ?void,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, ctx: *Context, f: fn (*Actor(T), T) ?void) !*Self {
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

        // TOOD: this can do it by call().wait.? whici mean can wait result with LockFree?
        //pub fn call(self: *Self, msg: T) !*anyopaque {
        //    try self.mailbox.writeItem(msg);
        //    try self.event.notify();
        //}

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.mailbox.deinit();
            allocator.destroy(self);
        }
    };
}

const ActorThread = struct {
    loop: xev.Loop,
    ctx: *Context,
    actors: std.StringArrayHashMap(ActorInterface),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, thread_id: i32) !*Self {
        const self = try allocator.create(Self);
        self.loop = try xev.Loop.init(.{});
        self.ctx = try Context.init(allocator, &self.loop, thread_id);
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

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        self.allocator = allocator;
        self.wg.reset();
        self.threads = 0;

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    pub fn run(self: *Self) !void {
        const cpu_count = try std.Thread.getCpuCount();
        self.threads = cpu_count;
        self.wg.startMany(cpu_count);

        for (0..cpu_count) |i| {
            const t = try std.Thread.spawn(.{}, thread_run, .{ self, i });
            t.detach();
        }

        self.wg.wait();
    }

    fn thread_run(self: *Self, idx: usize) !void {
        // Init ActorThread}
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
    ptr: *anyopaque, // 指向实际 Actor 实例的指针
    vtable: *const VTable, // 指向虚拟函数表的指针

    const Self = @This();

    // 虚拟函数表定义
    pub const VTable = struct {
        run: *const fn (ptr: *anyopaque) void,
        deinit: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
        sender: *const fn (ptr: *anyopaque, msg: *anyopaque) void,
        handleRawMessage: *const fn (ptr: *anyopaque, msg_ptr: *anyopaque) void,
    };

    // 方便使用的包装方法
    pub fn run(self: Self) void {
        return self.vtable.run(self.ptr);
    }

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        return self.vtable.deinit(self.ptr, allocator);
    }

    pub fn sender(self: Self, msg: *anyopaque) void {
        return self.vtable.sender(self.ptr, msg);
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

            const senderFn = struct {
                fn function(ptr: *anyopaque, msg_ptr: *anyopaque) void {
                    const self: T = @ptrCast(@alignCast(ptr));
                    self.handleRawMessage(msg_ptr) catch {
                        std.debug.print("failed to process message", .{});
                    };
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
                .sender = senderFn,
                .handleRawMessage = handleRawMessageFn,
            };
        };

        return .{
            .ptr = actor,
            .vtable = vtable,
        };
    }
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try ActorEngine.init(allocator);
    try engine.run();
    engine.deinit();
}
